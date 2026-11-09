import { Router, Request, Response } from 'express';
import { z } from 'zod';
import { prisma } from '../prisma';
import { authenticate, authorize } from '../middleware/auth';
import { Role } from '@prisma/client';

export const attendanceRouter = Router();

attendanceRouter.use(authenticate);

// 1. Clock In (Technician) - Supports multiple shift sessions per day
attendanceRouter.post('/clock-in', async (req: Request, res: Response) => {
  const user = req.user!;
  if (!user.technicianId) {
    return res.status(403).json({ success: false, error: { code: 'FORBIDDEN', message: 'User is not linked to a technician profile' } });
  }

  const { latitude, longitude, notes } = req.body;

  const today = new Date();
  today.setUTCHours(0, 0, 0, 0);

  try {
    // Check if there is already an active unclosed session
    const existingActive = await prisma.technicianAttendance.findFirst({
      where: {
        technicianId: user.technicianId,
        clockOutAt: null
      },
      orderBy: { clockInAt: 'desc' }
    });

    if (existingActive) {
      const sessionAgeHours = (Date.now() - new Date(existingActive.clockInAt).getTime()) / (1000 * 60 * 60);
      const sessionDate = new Date(existingActive.date);
      sessionDate.setUTCHours(0, 0, 0, 0);

      // If from a previous day or older than 12 hours, auto-close it!
      if (sessionDate.getTime() < today.getTime() || sessionAgeHours > 12) {
        const cappedMinutes = Math.min(480, Math.max(1, Math.round(sessionAgeHours * 60)));
        await prisma.technicianAttendance.update({
          where: { id: existingActive.id },
          data: {
            clockOutAt: new Date(new Date(existingActive.clockInAt).getTime() + cappedMinutes * 60 * 1000),
            totalMinutes: cappedMinutes,
            notes: existingActive.notes ? `${existingActive.notes} (Auto-closed next day)` : 'Auto-closed next day'
          }
        });
      } else {
        // If active session from today is already running, return it idempotently with 200
        return res.status(200).json({
          success: true,
          message: 'Active shift session is already running.',
          data: existingActive
        });
      }
    }

    const attendance = await prisma.$transaction(async (tx) => {
      // Create new attendance session
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

      // Mark technician as online and activate GPS tracking
      await tx.technician.update({
        where: { id: user.technicianId! },
        data: {
          isOnline: true,
          isAvailable: true,
          currentLatitude: latitude ?? undefined,
          currentLongitude: longitude ?? undefined,
          lastLocationAt: latitude && longitude ? new Date() : new Date()
        }
      });

      if (latitude && longitude) {
        await tx.technicianLocationLog.create({
          data: {
            technicianId: user.technicianId!,
            latitude,
            longitude
          }
        });
      }

      return record;
    });

    return res.status(201).json({
      success: true,
      message: 'Clocked in successfully. GPS tracking is now active for your shift!',
      data: attendance
    });
  } catch (err: any) {
    return res.status(400).json({ success: false, error: { code: 'CLOCK_IN_FAILED', message: err.message } });
  }
});

// 2. Clock Out (Technician)
attendanceRouter.post('/clock-out', async (req: Request, res: Response) => {
  const user = req.user!;
  if (!user.technicianId) {
    return res.status(403).json({ success: false, error: { code: 'FORBIDDEN', message: 'User is not linked to a technician profile' } });
  }

  const { latitude, longitude, notes } = req.body;

  try {
    // Find latest active unclosed session
    const activeSession = await prisma.technicianAttendance.findFirst({
      where: {
        technicianId: user.technicianId,
        clockOutAt: null
      },
      orderBy: { clockInAt: 'desc' }
    });

    if (!activeSession) {
      return res.status(400).json({
        success: false,
        error: { code: 'NOT_CLOCKED_IN', message: 'No active clock-in session found to clock out from.' }
      });
    }

    const clockOutTime = new Date();
    const diffMs = clockOutTime.getTime() - new Date(activeSession.clockInAt).getTime();
    const totalMinutes = Math.max(1, Math.round(diffMs / (1000 * 60)));

    const attendance = await prisma.$transaction(async (tx) => {
      const record = await tx.technicianAttendance.update({
        where: { id: activeSession.id },
        data: {
          clockOutAt: clockOutTime,
          clockOutLatitude: latitude,
          clockOutLongitude: longitude,
          totalMinutes,
          notes: notes ? (activeSession.notes ? `${activeSession.notes}; ${notes}` : notes) : activeSession.notes
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
      message: `Clocked out successfully. Shift session duration: ${Math.floor(totalMinutes / 60)}h ${totalMinutes % 60}m`,
      data: attendance
    });
  } catch (err: any) {
    return res.status(400).json({ success: false, error: { code: 'CLOCK_OUT_FAILED', message: err.message } });
  }
});

// 3. Get Current Day Attendance Status & Consolidated Time
attendanceRouter.get('/today', async (req: Request, res: Response) => {
  const user = req.user!;
  if (!user.technicianId) {
    return res.status(403).json({ success: false, error: { code: 'FORBIDDEN', message: 'User is not linked to a technician profile' } });
  }

  const today = new Date();
  today.setUTCHours(0, 0, 0, 0);
  const tomorrow = new Date(today);
  tomorrow.setDate(today.getDate() + 1);

  // 1. Auto-close any dangling unclosed sessions from previous days
  const danglingSessions = await prisma.technicianAttendance.findMany({
    where: {
      technicianId: user.technicianId,
      clockOutAt: null,
      date: { lt: today }
    }
  });

  for (const ds of danglingSessions) {
    const sessionAgeHours = (Date.now() - new Date(ds.clockInAt).getTime()) / (1000 * 60 * 60);
    const cappedMinutes = Math.min(480, Math.max(1, Math.round(sessionAgeHours * 60)));
    await prisma.technicianAttendance.update({
      where: { id: ds.id },
      data: {
        clockOutAt: new Date(new Date(ds.clockInAt).getTime() + cappedMinutes * 60 * 1000),
        totalMinutes: cappedMinutes,
        notes: ds.notes ? `${ds.notes} (Auto-closed next day)` : 'Auto-closed next day'
      }
    });
  }

  // 2. Fetch today's sessions
  const sessions = await prisma.technicianAttendance.findMany({
    where: {
      technicianId: user.technicianId,
      date: { gte: today, lt: tomorrow }
    },
    orderBy: { clockInAt: 'desc' }
  });

  const activeSession = sessions.find((s) => s.clockOutAt === null) || null;

  let consolidatedMinutesToday = 0;
  for (const s of sessions) {
    if (s.totalMinutes) {
      consolidatedMinutesToday += s.totalMinutes;
    } else if (s.clockInAt && !s.clockOutAt) {
      const elapsed = Math.round((Date.now() - new Date(s.clockInAt).getTime()) / (1000 * 60));
      consolidatedMinutesToday += Math.max(0, elapsed);
    }
  }

  return res.json({
    success: true,
    data: {
      activeSession,
      sessions,
      consolidatedMinutesToday,
      consolidatedFormatted: `${Math.floor(consolidatedMinutesToday / 60)}h ${consolidatedMinutesToday % 60}m`,
      isOnline: activeSession !== null
    }
  });
});

// 4. Timesheet & Attendance Report with Consolidated Hours (Admin, Booking Staff & Technicians for their own timesheet)
attendanceRouter.get('/report', authorize(Role.ADMIN, Role.BOOKING_STAFF, Role.TECHNICIAN), async (req: Request, res: Response) => {
  const { startDate, endDate, format } = req.query;
  let technicianId = req.query.technicianId as string | undefined;

  // Technicians can only view their own attendance logs
  if (req.user!.role === Role.TECHNICIAN) {
    if (!req.user!.technicianId) {
      return res.status(403).json({ success: false, error: { code: 'FORBIDDEN', message: 'User is not linked to a technician profile' } });
    }
    technicianId = req.user!.technicianId;
  }

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

  // Calculate consolidated summary by technician & date
  const consolidatedMap: Record<string, {
    technicianId: string;
    technicianName: string;
    user: {
      name: string;
      phone: string;
      email: string;
    };
    phone: string;
    date: string;
    totalMinutes: number;
    sessionsCount: number;
    activeSession: any;
    sessions: any[];
  }> = {};

  for (const log of logs) {
    const dateKey = log.date.toISOString().slice(0, 10);
    const key = `${log.technicianId}_${dateKey}`;

    if (!consolidatedMap[key]) {
      consolidatedMap[key] = {
        technicianId: log.technicianId,
        technicianName: log.technician.user.name,
        user: {
          name: log.technician.user.name,
          phone: log.technician.user.phone || '',
          email: log.technician.user.email || ''
        },
        phone: log.technician.user.phone || '',
        date: dateKey,
        totalMinutes: 0,
        sessionsCount: 0,
        activeSession: null,
        sessions: []
      };
    }

    const isCurrentActive = log.clockInAt && !log.clockOutAt;
    let sessionMins = log.totalMinutes || 0;
    if (isCurrentActive) {
      sessionMins = Math.max(1, Math.round((Date.now() - new Date(log.clockInAt).getTime()) / (1000 * 60)));
      consolidatedMap[key].activeSession = {
        id: log.id,
        clockInAt: log.clockInAt,
        clockInLatitude: log.clockInLatitude,
        clockInLongitude: log.clockInLongitude
      };
    }

    consolidatedMap[key].totalMinutes += sessionMins;
    consolidatedMap[key].sessionsCount += 1;
    consolidatedMap[key].sessions.push({
      id: log.id,
      clockInAt: log.clockInAt,
      clockOutAt: log.clockOutAt,
      clockInLatitude: log.clockInLatitude,
      clockInLongitude: log.clockInLongitude,
      totalMinutes: sessionMins,
      durationMinutes: sessionMins,
      notes: log.notes
    });
  }

  const consolidatedList = Object.values(consolidatedMap).map((c) => ({
    ...c,
    consolidatedFormatted: `${Math.floor(c.totalMinutes / 60)}h ${c.totalMinutes % 60}m`
  }));

  const totalLoggedMinutes = consolidatedList.reduce((acc, c) => acc + c.totalMinutes, 0);
  const totalTechniciansActive = consolidatedList.filter((c) => c.activeSession !== null).length;
  const totalCompletedSessions = logs.filter((l) => l.clockOutAt !== null).length;

  // If CSV export requested:
  if (format === 'csv') {
    res.setHeader('Content-Type', 'text/csv');
    res.setHeader('Content-Disposition', 'attachment; filename="technician_attendance_timesheet.csv"');

    const headers = ['Date', 'Technician Name', 'Phone', 'Clock In', 'Clock Out', 'Duration (Hours)', 'Notes'];
    const rows = logs.map((l) => [
      l.date.toISOString().slice(0, 10),
      `"${l.technician.user.name}"`,
      l.technician.user.phone || '',
      l.clockInAt.toISOString(),
      l.clockOutAt ? l.clockOutAt.toISOString() : 'Active Session',
      l.totalMinutes ? (l.totalMinutes / 60).toFixed(2) : '0',
      `"${l.notes || ''}"`
    ]);

    const csvContent = [headers.join(','), ...rows.map((r) => r.join(','))].join('\n');
    return res.send(csvContent);
  }

  return res.json({
    success: true,
    data: {
      logs,
      consolidated: consolidatedList,
      summary: {
        totalLoggedMinutes,
        totalTechniciansActive,
        totalCompletedSessions
      }
    }
  });
});
