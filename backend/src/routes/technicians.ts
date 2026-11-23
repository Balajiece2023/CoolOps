import { Router, Request, Response } from 'express';
import { z } from 'zod';
import bcrypt from 'bcrypt';
import { prisma } from '../prisma';
import { authenticate, authorize } from '../middleware/auth';
import { validateBody } from '../middleware/validate';
import { Role } from '@prisma/client';

export const techniciansRouter = Router();

techniciansRouter.use(authenticate);

// 1. List all technicians (Admin, Staff, or Technician seeing availability directory)
techniciansRouter.get('/', async (_req: Request, res: Response) => {
  const technicians = await prisma.technician.findMany({
    include: {
      user: {
        select: {
          id: true,
          name: true,
          email: true,
          phone: true,
          isActive: true
        }
      },
      _count: {
        select: {
          serviceJobs: {
            where: {
              status: { in: ['EN_ROUTE', 'ARRIVED', 'IN_PROGRESS', 'OTP_PENDING'] }
            }
          }
        }
      }
    },
    orderBy: { createdAt: 'desc' }
  });

  return res.json({
    success: true,
    data: technicians
  });
});

const createTechnicianSchema = z.object({
  name: z.string().min(2),
  email: z.string().email(),
  password: z.string().min(6),
  phone: z.string().min(10),
  skills: z.array(z.string()).default(['SPLIT', 'WINDOW']),
  serviceAreas: z.array(z.string()).default(['Chennai Central', 'OMR']),
  maxDailyJobs: z.number().int().positive().default(4)
});

// 2. Add new technician (Admin only)
techniciansRouter.post('/', authorize(Role.ADMIN), validateBody(createTechnicianSchema), async (req: Request, res: Response) => {
  const { name, email, password, phone, skills, serviceAreas, maxDailyJobs } = req.body;

  try {
    const existing = await prisma.user.findUnique({ where: { email } });
    if (existing) {
      return res.status(400).json({ success: false, error: { code: 'USER_EXISTS', message: 'User with this email already exists' } });
    }

    const passwordHash = await bcrypt.hash(password, 10);

    const result = await prisma.$transaction(async (tx) => {
      const user = await tx.user.create({
        data: {
          email,
          passwordHash,
          name,
          phone,
          role: Role.TECHNICIAN,
          isActive: true
        }
      });

      const technician = await tx.technician.create({
        data: {
          userId: user.id,
          skills,
          serviceAreas,
          maxDailyJobs,
          isAvailable: true,
          isOnline: false
        },
        include: {
          user: {
            select: { id: true, name: true, email: true, phone: true, isActive: true }
          }
        }
      });

      return technician;
    });

    return res.status(201).json({
      success: true,
      message: 'Technician created successfully',
      data: result
    });
  } catch (err: any) {
    return res.status(400).json({ success: false, error: { code: 'TECH_CREATION_FAILED', message: err.message } });
  }
});

// 3. Delete / Deactivate technician (Admin only)
techniciansRouter.delete('/:id', authorize(Role.ADMIN), async (req: Request, res: Response) => {
  const { id } = req.params;

  try {
    const tech = await prisma.technician.findUnique({
      where: { id },
      include: {
        serviceJobs: {
          where: { status: { in: ['PENDING', 'EN_ROUTE', 'ARRIVED', 'IN_PROGRESS', 'OTP_PENDING'] } }
        }
      }
    });

    if (!tech) {
      return res.status(404).json({ success: false, error: { code: 'NOT_FOUND', message: 'Technician not found' } });
    }

    if (tech.serviceJobs.length > 0) {
      return res.status(400).json({
        success: false,
        error: {
          code: 'ACTIVE_JOBS_EXIST',
          message: `Cannot delete technician with ${tech.serviceJobs.length} active job(s). Please reassign them first.`
        }
      });
    }

    // Soft delete/deactivate to preserve historical audit & invoice references
    await prisma.$transaction(async (tx) => {
      await tx.technician.update({
        where: { id },
        data: { isAvailable: false, isOnline: false }
      });
      await tx.user.update({
        where: { id: tech.userId },
        data: { isActive: false }
      });
    });

    return res.json({
      success: true,
      message: 'Technician deactivated and removed from active roster successfully'
    });
  } catch (err: any) {
    return res.status(400).json({ success: false, error: { code: 'DELETE_FAILED', message: err.message } });
  }
});

const updateTechnicianSchema = z.object({
  name: z.string().min(2).optional(),
  phone: z.string().min(10).optional(),
  skills: z.array(z.string()).optional(),
  serviceAreas: z.array(z.string()).optional(),
  maxDailyJobs: z.number().int().positive().optional()
});

// 3b. Update technician details (Admin only)
techniciansRouter.put('/:id', authorize(Role.ADMIN), validateBody(updateTechnicianSchema), async (req: Request, res: Response) => {
  const { id } = req.params;
  const { name, phone, skills, serviceAreas, maxDailyJobs } = req.body;

  try {
    const tech = await prisma.technician.findUnique({
      where: { id },
      include: { user: true }
    });

    if (!tech) {
      return res.status(404).json({ success: false, error: { code: 'NOT_FOUND', message: 'Technician not found' } });
    }

    const updated = await prisma.$transaction(async (tx) => {
      if (name || phone) {
        await tx.user.update({
          where: { id: tech.userId },
          data: {
            name: name ?? undefined,
            phone: phone ?? undefined
          }
        });
      }

      return await tx.technician.update({
        where: { id },
        data: {
          skills: skills ?? undefined,
          serviceAreas: serviceAreas ?? undefined,
          maxDailyJobs: maxDailyJobs ?? undefined
        },
        include: {
          user: {
            select: { id: true, name: true, email: true, phone: true, isActive: true }
          }
        }
      });
    });

    return res.json({
      success: true,
      message: 'Technician details updated successfully',
      data: updated
    });
  } catch (err: any) {
    return res.status(400).json({ success: false, error: { code: 'UPDATE_FAILED', message: err.message } });
  }
});

const availabilitySchema = z.object({
  isOnline: z.boolean(),
  latitude: z.number().optional(),
  longitude: z.number().optional()
});

// 4. Toggle Online / Offline Availability (Technician & Admin)
techniciansRouter.patch('/availability', async (req: Request, res: Response) => {
  const user = req.user!;
  const body = req.body;

  let techId = user.technicianId;
  if (user.role === Role.ADMIN && req.query.technicianId) {
    techId = String(req.query.technicianId);
  }

  if (!techId) {
    return res.status(403).json({ success: false, error: { code: 'FORBIDDEN', message: 'User is not linked to a technician profile' } });
  }

  try {
    const updated = await prisma.technician.update({
      where: { id: techId },
      data: {
        isOnline: body.isOnline,
        isAvailable: body.isOnline,
        currentLatitude: body.latitude ?? undefined,
        currentLongitude: body.longitude ?? undefined,
        lastLocationAt: body.latitude && body.longitude ? new Date() : undefined
      },
      include: {
        user: { select: { id: true, name: true, email: true, phone: true } }
      }
    });

    if (body.latitude && body.longitude) {
      await prisma.technicianLocationLog.create({
        data: {
          technicianId: techId,
          latitude: body.latitude,
          longitude: body.longitude
        }
      });
    }

    return res.json({
      success: true,
      message: `Technician status is now ${body.isOnline ? 'Online (Available)' : 'Offline'}`,
      data: updated
    });
  } catch (err: any) {
    return res.status(400).json({ success: false, error: { code: 'STATUS_UPDATE_FAILED', message: err.message } });
  }
});

// 4b. Admin Clock-Out for Technician (Admin & Booking Staff)
techniciansRouter.post('/:id/clock-out', authorize(Role.ADMIN, Role.BOOKING_STAFF), async (req: Request, res: Response) => {
  const { id } = req.params;
  const { clockOutAt, notes } = req.body;

  try {
    const tech = await prisma.technician.findUnique({
      where: { id },
      include: { user: { select: { name: true, phone: true } } }
    });

    if (!tech) {
      return res.status(404).json({ success: false, error: { code: 'NOT_FOUND', message: 'Technician not found' } });
    }

    const activeSessions = await prisma.technicianAttendance.findMany({
      where: { technicianId: id, clockOutAt: null },
      orderBy: { clockInAt: 'desc' }
    });

    let clockOutTime = new Date();
    if (clockOutAt) {
      const parsed = new Date(clockOutAt);
      if (!isNaN(parsed.getTime())) clockOutTime = parsed;
    }

    const adminName = req.user?.email || 'Admin';
    const reasonText = notes?.trim() || 'Technician forgot to clock out';

    if (activeSessions.length === 0) {
      await prisma.technician.update({
        where: { id },
        data: { isOnline: false, isAvailable: false }
      });
      return res.json({
        success: true,
        message: `${tech.user.name} had no active shift session. Status set to offline.`,
        data: null
      });
    }

    const latestActive = activeSessions[0];
    const diffMs = Math.max(0, clockOutTime.getTime() - new Date(latestActive.clockInAt).getTime());
    const totalMinutes = Math.max(1, Math.round(diffMs / (1000 * 60)));

    const updatedNotes = latestActive.notes
      ? `${latestActive.notes}; [Admin Clock-Out by ${adminName}]: ${reasonText}`
      : `[Admin Clock-Out by ${adminName}]: ${reasonText}`;

    const attendance = await prisma.$transaction(async (tx) => {
      const record = await tx.technicianAttendance.update({
        where: { id: latestActive.id },
        data: {
          clockOutAt: clockOutTime,
          totalMinutes,
          notes: updatedNotes
        }
      });

      for (let i = 1; i < activeSessions.length; i++) {
        const older = activeSessions[i];
        const olderDiff = Math.max(1, Math.round((clockOutTime.getTime() - new Date(older.clockInAt).getTime()) / (1000 * 60)));
        await tx.technicianAttendance.update({
          where: { id: older.id },
          data: {
            clockOutAt: clockOutTime,
            totalMinutes: Math.min(480, olderDiff),
            notes: older.notes ? `${older.notes}; (Auto-closed by Admin)` : '(Auto-closed by Admin)'
          }
        });
      }

      await tx.technician.update({
        where: { id },
        data: { isOnline: false, isAvailable: false }
      });

      return record;
    });

    const hours = Math.floor(totalMinutes / 60);
    const mins = totalMinutes % 60;

    return res.json({
      success: true,
      message: `Successfully clocked out ${tech.user.name}. Shift session closed (${hours}h ${mins}m).`,
      data: attendance
    });
  } catch (err: any) {
    return res.status(400).json({ success: false, error: { code: 'ADMIN_CLOCK_OUT_FAILED', message: err.message } });
  }
});

const locationPingSchema = z.object({
  latitude: z.number(),
  longitude: z.number()
});

// 5. Live GPS Location Ping (Technician App)
techniciansRouter.post('/location', validateBody(locationPingSchema), async (req: Request, res: Response) => {
  const user = req.user!;
  if (!user.technicianId) {
    return res.status(403).json({ success: false, error: { code: 'FORBIDDEN', message: 'Not a technician profile' } });
  }

  const { latitude, longitude } = req.body;

  await prisma.technician.update({
    where: { id: user.technicianId },
    data: {
      currentLatitude: latitude,
      currentLongitude: longitude,
      lastLocationAt: new Date(),
      isOnline: true
    }
  });

  await prisma.technicianLocationLog.create({
    data: {
      technicianId: user.technicianId,
      latitude,
      longitude
    }
  });

  return res.json({ success: true, message: 'Location recorded' });
});

// 6. Admin Live Map & Tracking Data (Admin & Staff)
techniciansRouter.get('/live-locations', authorize(Role.ADMIN, Role.BOOKING_STAFF), async (_req: Request, res: Response) => {
  const onlineTechnicians = await prisma.technician.findMany({
    where: {
      user: { isActive: true },
      isOnline: true
    },
    include: {
      user: { select: { id: true, name: true, phone: true } },
      serviceJobs: {
        where: { status: { in: ['EN_ROUTE', 'ARRIVED', 'IN_PROGRESS', 'OTP_PENDING'] } },
        include: {
          booking: {
            include: { customer: true, address: true, serviceType: true }
          }
        }
      }
    }
  });

  // Provide fallback coordinate (Chennai Center 13.0827, 80.2707) if technician hasn't sent GPS ping yet
  const enriched = onlineTechnicians.map((t) => ({
    ...t,
    currentLatitude: t.currentLatitude ?? 13.0827,
    currentLongitude: t.currentLongitude ?? 80.2707,
    isGpsEstimated: t.currentLatitude === null
  }));

  return res.json({
    success: true,
    data: enriched
  });
});

// 7. Individual Technician Detailed Performance & Timesheet Report (Admin & Staff)
techniciansRouter.get('/:id/report', authorize(Role.ADMIN, Role.BOOKING_STAFF), async (req: Request, res: Response) => {
  try {
    const { getTechnicianReportData } = await import('../services/technicianReportService');
    const report = await getTechnicianReportData(req.params.id);
    return res.json({ success: true, data: report });
  } catch (err: any) {
    return res.status(404).json({ success: false, error: { code: 'REPORT_NOT_FOUND', message: err.message } });
  }
});

// 8. Download Individual Technician Report PDF (Admin & Staff)
techniciansRouter.get('/:id/report/pdf', authorize(Role.ADMIN, Role.BOOKING_STAFF), async (req: Request, res: Response) => {
  try {
    const { generateTechnicianReportPdf } = await import('../services/technicianReportService');
    await generateTechnicianReportPdf(req.params.id, res);
  } catch (err: any) {
    return res.status(500).json({ success: false, error: { code: 'PDF_REPORT_FAILED', message: err.message } });
  }
});
