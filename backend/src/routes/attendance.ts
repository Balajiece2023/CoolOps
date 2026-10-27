import { Router, Request, Response } from 'express';
import { z } from 'zod';
import { prisma } from '../prisma';
import { authenticate, authorize } from '../middleware/auth';
import { validateBody } from '../middleware/validate';
import { Role } from '@prisma/client';

export const attendanceRouter = Router();

attendanceRouter.use(authenticate);

const clockInSchema = z.object({
  latitude: z.number().optional(),
  longitude: z.number().optional(),
  notes: z.string().optional()
});

// 1. Clock In (Technician)
attendanceRouter.post('/clock-in', async (req: Request, res: Response) => {
  const user = req.user!;
  if (!user.technicianId) {
    return res.status(403).json({ success: false, error: { code: 'FORBIDDEN', message: 'User is not linked to a technician profile' } });
  }

  const { latitude, longitude, notes } = req.body;

  const today = new Date();
  today.setUTCHours(0, 0, 0, 0);

  try {
    const existing = await prisma.technicianAttendance.findUnique({
      where: {
        technicianId_date: {
          technicianId: user.technicianId,
          date: today
        }
      }
    });

    if (existing) {
      return res.status(400).json({
        success: false,
        error: { code: 'ALREADY_CLOCKED_IN', message: 'You have already clocked in for today.' }
      });
    }

    const attendance = await prisma.$transaction(async (tx) => {
      // Create attendance
      const record = await tx.technicianAttendance.create({
        data: {
          technicianId: user.technicianId!,
          date: today,
          clockInAt: new Date(),
          clockInLatitude: latitude,
          clockInLongitude: longitude,
          notes
        }
      });

      // Mark technician as online
      await tx.technician.update({
        where: { id: user.technicianId! },
        data: {
          isOnline: true,
          isAvailable: true,
          currentLatitude: latitude ?? undefined,
          currentLongitude: longitude ?? undefined,
          lastLocationAt: latitude && longitude ? new Date() : undefined
        }
      });

      return record;
    });

    return res.status(201).json({
      success: true,
      message: 'Clocked in successfully. Have a safe work day!',
      data: attendance
    });
  } catch (err: any) {
    return res.status(400).json({ success: false, error: { code: 'CLOCK_IN_FAILED', message: err.message } });
  }
});

const clockOutSchema = z.object({
  latitude: z.number().optional(),
  longitude: z.number().optional(),
  notes: z.string().optional()
});

// 2. Clock Out (Technician)
attendanceRouter.post('/clock-out', async (req: Request, res: Response) => {
  const user = req.user!;
  if (!user.technicianId) {
    return res.status(403).json({ success: false, error: { code: 'FORBIDDEN', message: 'User is not linked to a technician profile' } });
  }

  const { latitude, longitude, notes } = req.body;

  const today = new Date();
  today.setUTCHours(0, 0, 0, 0);

  try {
    const existing = await prisma.technicianAttendance.findUnique({
      where: {
        technicianId_date: {
          technicianId: user.technicianId,
          date: today
        }
      }
    });

    if (!existing) {
      return res.status(400).json({
        success: false,
        error: { code: 'NOT_CLOCKED_IN', message: 'No clock-in record found for today.' }
      });
    }

    if (existing.clockOutAt) {
      return res.status(400).json({
        success: false,
        error: { code: 'ALREADY_CLOCKED_OUT', message: 'You have already clocked out for today.' }
      });
    }

    const clockOutTime = new Date();
    const diffMs = clockOutTime.getTime() - new Date(existing.clockInAt).getTime();
    const totalMinutes = Math.max(1, Math.round(diffMs / (1000 * 60)));

    const attendance = await prisma.$transaction(async (tx) => {
      const record = await tx.technicianAttendance.update({
        where: { id: existing.id },
        data: {
          clockOutAt: clockOutTime,
          clockOutLatitude: latitude,
          clockOutLongitude: longitude,
          totalMinutes,
          notes: notes ? (existing.notes ? `${existing.notes}; ${notes}` : notes) : existing.notes
        }
      });

      // Mark technician as offline
      await tx.technician.update({
        where: { id: user.technicianId! },
        data: {
          isOnline: false,
          isAvailable: false
        }
      });

      return record;
    });

    return res.json({
      success: true,
      message: `Clocked out successfully. Total shift duration: ${Math.floor(totalMinutes / 60)}h ${totalMinutes % 60}m`,
      data: attendance
    });
  } catch (err: any) {
    return res.status(400).json({ success: false, error: { code: 'CLOCK_OUT_FAILED', message: err.message } });
  }
});

// 3. Get Current Day Attendance Status (for technician app dashboard)
attendanceRouter.get('/today', async (req: Request, res: Response) => {
  const user = req.user!;
  if (!user.technicianId) {
    return res.status(403).json({ success: false, error: { code: 'FORBIDDEN', message: 'User is not linked to a technician profile' } });
  }

  const today = new Date();
  today.setUTCHours(0, 0, 0, 0);

  const record = await prisma.technicianAttendance.findUnique({
    where: {
      technicianId_date: {
        technicianId: user.technicianId,
        date: today
      }
    }
  });

  return res.json({
    success: true,
    data: record
  });
});

// 4. Admin Timesheet & Attendance Report (Admin & Staff)
attendanceRouter.get('/report', authorize(Role.ADMIN, Role.BOOKING_STAFF), async (req: Request, res: Response) => {
  const { startDate, endDate, technicianId, format } = req.query;

  const whereClause: any = {};

  if (technicianId) {
    whereClause.technicianId = String(technicianId);
  }

  if (startDate || endDate) {
    whereClause.date = {};
    if (startDate) {
      const start = new Date(String(startDate));
      start.setUTCHours(0, 0, 0, 0);
      whereClause.date.gte = start;
    }
    if (endDate) {
      const end = new Date(String(endDate));
      end.setUTCHours(23, 59, 59, 999);
      whereClause.date.lte = end;
    }
  }

  const logs = await prisma.technicianAttendance.findMany({
    where: whereClause,
    include: {
      technician: {
        include: {
          user: {
            select: { name: true, email: true, phone: true }
          }
        }
      }
    },
    orderBy: [{ date: 'desc' }, { clockInAt: 'desc' }]
  });

  // If CSV export requested:
  if (format === 'csv') {
    res.setHeader('Content-Type', 'text/csv');
    res.setHeader('Content-Disposition', 'attachment; filename="technician_attendance_timesheet.csv"');

    const headers = ['Date', 'Technician Name', 'Phone', 'Clock In', 'Clock Out', 'Total Hours', 'Notes'];
    const rows = logs.map((l) => [
      l.date.toISOString().slice(0, 10),
      `"${l.technician.user.name}"`,
      l.technician.user.phone || '',
      l.clockInAt.toISOString(),
      l.clockOutAt ? l.clockOutAt.toISOString() : 'Still Active',
      l.totalMinutes ? (l.totalMinutes / 60).toFixed(2) : '0',
      `"${l.notes || ''}"`
    ]);

    const csvContent = [headers.join(','), ...rows.map((r) => r.join(','))].join('\n');
    return res.send(csvContent);
  }

  return res.json({
    success: true,
    data: logs
  });
});
