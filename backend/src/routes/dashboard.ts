import { Router, Request, Response } from 'express';
import { prisma } from '../prisma';
import { authenticate, authorize } from '../middleware/auth';
import { Role, RequestStatus, JobStatus, InvoiceStatus } from '@prisma/client';

export const dashboardRouter = Router();

dashboardRouter.use(authenticate);

dashboardRouter.get('/stats', authorize(Role.ADMIN, Role.BOOKING_STAFF, Role.ACCOUNTANT), async (req: Request, res: Response) => {
  const today = new Date();
  today.setUTCHours(0, 0, 0, 0);
  const tomorrow = new Date(today);
  tomorrow.setDate(today.getDate() + 1);

  const [
    pendingRequestsCount,
    todayBookingsCount,
    ongoingJobsCount,
    completedJobsCount,
    lowStockCount,
    invoicesSummary
  ] = await Promise.all([
    prisma.bookingRequest.count({ where: { status: RequestStatus.PENDING_APPROVAL } }),
    prisma.booking.count({ where: { scheduledDate: { gte: today, lt: tomorrow } } }),
    prisma.serviceJob.count({ where: { status: { in: [JobStatus.ARRIVED, JobStatus.IN_PROGRESS] } } }),
    prisma.serviceJob.count({ where: { status: JobStatus.COMPLETED } }),
    prisma.inventoryPart.count({ where: { currentStock: { lte: 5 } } }),
    prisma.invoice.findMany({
      select: { totalAmount: true, paidAmount: true, status: true }
    })
  ]);

  let totalBilled = 0;
  let totalCollected = 0;
  let totalOverdue = 0;

  for (const inv of invoicesSummary) {
    totalBilled += inv.totalAmount;
    totalCollected += inv.paidAmount;
    if (inv.status !== InvoiceStatus.PAID && inv.status !== InvoiceStatus.CANCELLED) {
      totalOverdue += (inv.totalAmount - inv.paidAmount);
    }
  }

  return res.json({
    success: true,
    data: {
      pendingRequestsCount,
      todayBookingsCount,
      ongoingJobsCount,
      completedJobsCount,
      lowStockCount,
      totalBilled,
      totalCollected,
      totalOverdue
    }
  });
});

// Technicians List & Availability
dashboardRouter.get('/technicians', authorize(Role.ADMIN, Role.BOOKING_STAFF), async (req: Request, res: Response) => {
  const { date } = req.query;

  const techs = await prisma.technician.findMany({
    include: {
      user: {
        select: { id: true, name: true, email: true, phone: true, isActive: true }
      },
      assignments: {
        where: date ? {
          assignedSlotStart: {
            gte: new Date(`${date}T00:00:00Z`),
            lte: new Date(`${date}T23:59:59Z`)
          }
        } : undefined,
        include: {
          booking: {
            include: { address: true, serviceType: true, customer: true }
          }
        }
      }
    }
  });

  return res.json({ success: true, data: techs });
});

// Service Types Catalogue
dashboardRouter.get('/service-types', async (req: Request, res: Response) => {
  const services = await prisma.serviceType.findMany({
    where: { isActive: true },
    orderBy: { basePrice: 'asc' }
  });
  return res.json({ success: true, data: services });
});

// Customers directory
dashboardRouter.get('/customers', authorize(Role.ADMIN, Role.BOOKING_STAFF), async (req: Request, res: Response) => {
  const { search } = req.query;
  const where: any = {};
  if (search) {
    where.OR = [
      { name: { contains: String(search), mode: 'insensitive' } },
      { phone: { contains: String(search) } }
    ];
  }

  const customers = await prisma.customer.findMany({
    where,
    include: {
      addresses: true,
      acUnits: true,
      _count: { select: { bookings: true, bookingRequests: true } }
    },
    take: 50,
    orderBy: { createdAt: 'desc' }
  });

  return res.json({ success: true, data: customers });
});
