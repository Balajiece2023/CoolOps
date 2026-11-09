import { Router, Request, Response } from 'express';
import { z } from 'zod';
import { prisma } from '../prisma';
import { authenticate, authorize } from '../middleware/auth';
import { Role } from '@prisma/client';
import { validateBody } from '../middleware/validate';
import { generateFieldServiceReportPdf } from '../services/fieldServiceReportPdfService';

export const fieldServiceReportsRouter = Router();

fieldServiceReportsRouter.use(authenticate);

const createReportSchema = z.object({
  serviceJobId: z.string().uuid().optional().nullable(),
  reportNumber: z.string().optional(),
  reportType: z.enum(['COMMISSIONING', 'WARRANTY', 'MAIN_CONTACT', 'MAINTENANCE_CONTRACT', 'DO_AND_CHARGE_REPAIR']).default('DO_AND_CHARGE_REPAIR'),
  customerName: z.string().min(2),
  customerAddress: z.string().min(2),
  contactPhone: z.string().optional().nullable(),
  personCalling: z.string().optional().nullable(),
  serviceEngineerName: z.string().optional(),
  complaintDate: z.string().optional().nullable(),
  attendingDate: z.string().optional().nullable(),
  modelNumber: z.string().optional().nullable(),
  indoorSerialNo: z.string().optional().nullable(),
  outdoorSerialNo: z.string().optional().nullable(),
  errorCode: z.string().optional().nullable(),
  runningCurrent: z.string().optional().nullable(),
  suctionPressure: z.string().optional().nullable(),
  dischargePressure: z.string().optional().nullable(),
  roomTemperature: z.string().optional().nullable(),
  voltage: z.string().optional().nullable(),
  equip1Details: z.string().optional().nullable(),
  equip2Details: z.string().optional().nullable(),
  observations: z.string().min(2),
  suggestions: z.string().optional().nullable(),
  customerSignName: z.string().optional().nullable()
});

// 1. List Field Service Reports
fieldServiceReportsRouter.get('/', authorize(Role.ADMIN, Role.BOOKING_STAFF, Role.TECHNICIAN, Role.ACCOUNTANT), async (req: Request, res: Response) => {
  try {
    const { search, reportType, technicianId, serviceJobId, page = '1', limit = '50' } = req.query;

    const pageNum = parseInt(page as string, 10) || 1;
    const limitNum = parseInt(limit as string, 10) || 50;
    const skip = (pageNum - 1) * limitNum;

    const where: any = {};

    if (reportType && reportType !== 'ALL') {
      where.reportType = reportType as string;
    }

    if (serviceJobId) {
      where.serviceJobId = serviceJobId as string;
    }

    if (technicianId) {
      where.technicianId = technicianId as string;
    } else if (req.user!.role === Role.TECHNICIAN) {
      // Find technician record for this user
      const tech = await prisma.technician.findUnique({ where: { userId: req.user!.userId } });
      if (tech) {
        where.OR = [
          { technicianId: tech.id },
          { createdById: req.user!.userId }
        ];
      }
    }

    if (search) {
      const q = String(search).trim();
      where.OR = [
        { reportNumber: { contains: q, mode: 'insensitive' } },
        { customerName: { contains: q, mode: 'insensitive' } },
        { customerAddress: { contains: q, mode: 'insensitive' } },
        { contactPhone: { contains: q, mode: 'insensitive' } },
        { serviceEngineerName: { contains: q, mode: 'insensitive' } },
        { observations: { contains: q, mode: 'insensitive' } }
      ];
    }

    const [total, reports] = await Promise.all([
      prisma.fieldServiceReport.count({ where }),
      prisma.fieldServiceReport.findMany({
        where,
        skip,
        take: limitNum,
        orderBy: { attendingDate: 'desc' },
        include: {
          serviceJob: {
            select: { id: true, jobNumber: true, status: true }
          },
          technician: {
            include: { user: { select: { id: true, name: true, phone: true } } }
          }
        }
      })
    ]);

    return res.json({
      success: true,
      data: {
        total,
        page: pageNum,
        limit: limitNum,
        totalPages: Math.ceil(total / limitNum),
        items: reports
      }
    });
  } catch (err: any) {
    return res.status(500).json({ success: false, error: { message: err.message } });
  }
});

// 2. Get Single Report by ID
fieldServiceReportsRouter.get('/:id', authorize(Role.ADMIN, Role.BOOKING_STAFF, Role.TECHNICIAN, Role.ACCOUNTANT), async (req: Request, res: Response) => {
  try {
    const report = await prisma.fieldServiceReport.findUnique({
      where: { id: req.params.id },
      include: {
        serviceJob: {
          include: {
            booking: { include: { customer: true, address: true, serviceType: true } }
          }
        },
        technician: {
          include: { user: true }
        },
        createdBy: {
          select: { id: true, name: true, role: true }
        }
      }
    });

    if (!report) {
      return res.status(404).json({ success: false, error: { message: 'Field service report not found' } });
    }

    return res.json({ success: true, data: report });
  } catch (err: any) {
    return res.status(500).json({ success: false, error: { message: err.message } });
  }
});

// 3. Create Field Service Report
fieldServiceReportsRouter.post('/', authorize(Role.ADMIN, Role.TECHNICIAN, Role.BOOKING_STAFF), validateBody(createReportSchema), async (req: Request, res: Response) => {
  try {
    const b = req.body;

    // Resolve technicianId and service engineer name
    let technicianId = null;
    let engineerName = b.serviceEngineerName?.trim();

    if (req.user!.role === Role.TECHNICIAN) {
      const tech = await prisma.technician.findUnique({
        where: { userId: req.user!.userId },
        include: { user: true }
      });
      if (tech) {
        technicianId = tech.id;
        if (!engineerName) engineerName = tech.user.name;
      }
    }

    if (!engineerName) {
      const user = await prisma.user.findUnique({ where: { id: req.user!.userId } });
      engineerName = user?.name || 'Service Engineer';
    }

    // Auto-generate reportNumber if omitted (e.g. "1110", "1111" or "FSR-20261104-0001")
    let reportNumber = b.reportNumber?.trim();
    if (!reportNumber) {
      const totalReports = await prisma.fieldServiceReport.count();
      reportNumber = String(1110 + totalReports);
    }

    // Check if reportNumber is taken
    const existingNum = await prisma.fieldServiceReport.findUnique({ where: { reportNumber } });
    if (existingNum) {
      reportNumber = `${reportNumber}-${Date.now().toString().slice(-4)}`;
    }

    const report = await prisma.fieldServiceReport.create({
      data: {
        reportNumber,
        serviceJobId: b.serviceJobId || null,
        technicianId,
        createdById: req.user!.userId,
        reportType: b.reportType,
        customerName: b.customerName,
        customerAddress: b.customerAddress,
        contactPhone: b.contactPhone || null,
        personCalling: b.personCalling || null,
        serviceEngineerName: engineerName,
        complaintDate: b.complaintDate ? new Date(b.complaintDate) : null,
        attendingDate: b.attendingDate ? new Date(b.attendingDate) : new Date(),
        modelNumber: b.modelNumber || null,
        indoorSerialNo: b.indoorSerialNo || null,
        outdoorSerialNo: b.outdoorSerialNo || null,
        errorCode: b.errorCode || null,
        runningCurrent: b.runningCurrent || null,
        suctionPressure: b.suctionPressure || null,
        dischargePressure: b.dischargePressure || null,
        roomTemperature: b.roomTemperature || null,
        voltage: b.voltage || null,
        equip1Details: b.equip1Details || null,
        equip2Details: b.equip2Details || null,
        observations: b.observations,
        suggestions: b.suggestions || null,
        customerSignName: b.customerSignName || null
      }
    });

    return res.status(201).json({
      success: true,
      message: 'Field Service Report generated successfully',
      data: report
    });
  } catch (err: any) {
    return res.status(500).json({ success: false, error: { message: err.message } });
  }
});

// 4. Update Report
fieldServiceReportsRouter.put('/:id', authorize(Role.ADMIN, Role.TECHNICIAN), async (req: Request, res: Response) => {
  try {
    const report = await prisma.fieldServiceReport.update({
      where: { id: req.params.id },
      data: req.body
    });

    return res.json({ success: true, message: 'Report updated', data: report });
  } catch (err: any) {
    return res.status(500).json({ success: false, error: { message: err.message } });
  }
});

// 5. Delete Report
fieldServiceReportsRouter.delete('/:id', authorize(Role.ADMIN, Role.TECHNICIAN), async (req: Request, res: Response) => {
  try {
    await prisma.fieldServiceReport.delete({
      where: { id: req.params.id }
    });

    return res.json({ success: true, message: 'Field service report deleted' });
  } catch (err: any) {
    return res.status(500).json({ success: false, error: { message: err.message } });
  }
});

// 6. Download / View PDF Report
fieldServiceReportsRouter.get('/:id/pdf', authorize(Role.ADMIN, Role.BOOKING_STAFF, Role.TECHNICIAN, Role.ACCOUNTANT), async (req: Request, res: Response) => {
  try {
    await generateFieldServiceReportPdf(req.params.id, res);
  } catch (err: any) {
    return res.status(404).json({ success: false, error: { message: err.message } });
  }
});

