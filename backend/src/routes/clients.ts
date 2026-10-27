import { Router, Request, Response } from 'express';
import { z } from 'zod';
import { prisma } from '../prisma';
import { authenticate, authorize } from '../middleware/auth';
import { validateBody } from '../middleware/validate';
import { Role } from '@prisma/client';

export const clientsRouter = Router();

clientsRouter.use(authenticate);

// 1. Search and list clients with summary metrics (Admin & Staff)
clientsRouter.get('/', authorize(Role.ADMIN, Role.BOOKING_STAFF), async (req: Request, res: Response) => {
  const { search, page = '1', limit = '20' } = req.query;

  const p = parseInt(String(page), 10);
  const l = parseInt(String(limit), 10);

  const whereClause: any = {};
  if (search) {
    whereClause.OR = [
      { name: { contains: String(search), mode: 'insensitive' } },
      { phone: { contains: String(search) } },
      { email: { contains: String(search), mode: 'insensitive' } }
    ];
  }

  const [total, clients] = await Promise.all([
    prisma.customer.count({ where: whereClause }),
    prisma.customer.findMany({
      where: whereClause,
      include: {
        addresses: true,
        acUnits: true,
        _count: {
          select: {
            bookings: true,
            invoices: true
          }
        }
      },
      orderBy: { createdAt: 'desc' },
      skip: (p - 1) * l,
      take: l
    })
  ]);

  return res.json({
    success: true,
    data: {
      items: clients,
      pagination: {
        page: p,
        limit: l,
        total,
        totalPages: Math.ceil(total / l)
      }
    }
  });
});

// 2. Client 360 View: Full profile, lifetime service history, past invoices & AC units (Admin & Staff)
clientsRouter.get('/:id/360', authorize(Role.ADMIN, Role.BOOKING_STAFF), async (req: Request, res: Response) => {
  const { id } = req.params;

  const client = await prisma.customer.findUnique({
    where: { id },
    include: {
      addresses: true,
      acUnits: true,
      bookings: {
        include: {
          serviceType: true,
          address: true,
          assignments: {
            include: {
              technician: { include: { user: true } }
            }
          },
          serviceJob: {
            include: {
              checklistItems: true,
              partsConsumed: { include: { part: true } }
            }
          }
        },
        orderBy: { createdAt: 'desc' }
      },
      invoices: {
        include: {
          items: true,
          payments: true
        },
        orderBy: { createdAt: 'desc' }
      }
    }
  });

  if (!client) {
    return res.status(404).json({ success: false, error: { code: 'NOT_FOUND', message: 'Client not found' } });
  }

  // Calculate lifetime value (total revenue collected from this client)
  const totalPaid = client.invoices.reduce((acc, inv) => {
    const invPayments = inv.payments.reduce((pAcc, p) => pAcc + (p.status === 'SUCCESS' ? p.amount : 0), 0);
    return acc + invPayments;
  }, 0);

  return res.json({
    success: true,
    data: {
      ...client,
      metrics: {
        totalBookings: client.bookings.length,
        totalInvoices: client.invoices.length,
        totalLifetimeSpend: totalPaid
      }
    }
  });
});

const updateClientSchema = z.object({
  name: z.string().min(2).optional(),
  phone: z.string().min(10).optional(),
  email: z.string().email().optional().nullable(),
  language: z.enum(['en', 'ta']).optional()
});

// 3. Edit Client Details (Admin & Staff)
clientsRouter.put('/:id', authorize(Role.ADMIN, Role.BOOKING_STAFF), validateBody(updateClientSchema), async (req: Request, res: Response) => {
  const { id } = req.params;
  const { name, phone, email, language } = req.body;

  try {
    const existing = await prisma.customer.findUnique({ where: { id } });
    if (!existing) {
      return res.status(404).json({ success: false, error: { code: 'NOT_FOUND', message: 'Client not found' } });
    }

    // Check phone conflict
    if (phone && phone !== existing.phone) {
      const phoneConflict = await prisma.customer.findUnique({ where: { phone } });
      if (phoneConflict) {
        return res.status(400).json({ success: false, error: { code: 'PHONE_EXISTS', message: 'Another client already has this phone number' } });
      }
    }

    const updated = await prisma.customer.update({
      where: { id },
      data: {
        name: name ?? undefined,
        phone: phone ?? undefined,
        email: email !== undefined ? email : undefined,
        language: language ?? undefined
      },
      include: {
        addresses: true,
        acUnits: true
      }
    });

    return res.json({
      success: true,
      message: 'Client details updated successfully',
      data: updated
    });
  } catch (err: any) {
    return res.status(400).json({ success: false, error: { code: 'UPDATE_FAILED', message: err.message } });
  }
});

const updateAddressSchema = z.object({
  addressLine: z.string().min(3),
  landmark: z.string().optional().nullable(),
  area: z.string().min(2),
  city: z.string().default('Chennai'),
  pincode: z.string().min(6)
});

// 4. Update Client Address (Admin & Staff)
clientsRouter.put('/addresses/:addressId', authorize(Role.ADMIN, Role.BOOKING_STAFF), validateBody(updateAddressSchema), async (req: Request, res: Response) => {
  const { addressId } = req.params;
  const { addressLine, landmark, area, city, pincode } = req.body;

  try {
    const updated = await prisma.customerAddress.update({
      where: { id: addressId },
      data: {
        addressLine,
        landmark: landmark ?? undefined,
        area,
        city,
        pincode
      }
    });

    return res.json({
      success: true,
      message: 'Address updated successfully',
      data: updated
    });
  } catch (err: any) {
    return res.status(400).json({ success: false, error: { code: 'UPDATE_FAILED', message: err.message } });
  }
});
