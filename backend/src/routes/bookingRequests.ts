import { Router, Request, Response } from 'express';
import { z } from 'zod';
import { prisma } from '../prisma';
import { authenticate, authorize } from '../middleware/auth';
import { validateBody } from '../middleware/validate';
import { bookingApprovalService } from '../services/bookingApprovalService';
import { RequestStatus, Role } from '@prisma/client';

export const bookingRequestsRouter = Router();

bookingRequestsRouter.use(authenticate);

// Get list of booking requests with filters
bookingRequestsRouter.get('/', authorize(Role.ADMIN, Role.BOOKING_STAFF), async (req: Request, res: Response) => {
  const { status, page = '1', limit = '20', search } = req.query;

  const whereClause: any = {
    isDeleted: false
  };
  if (status) {
    whereClause.status = status as RequestStatus;
  }

  if (search) {
    whereClause.OR = [
      { referenceNumber: { contains: String(search), mode: 'insensitive' } },
      { customer: { name: { contains: String(search), mode: 'insensitive' } } },
      { customer: { phone: { contains: String(search) } } }
    ];
  }

  const p = parseInt(String(page), 10);
  const l = parseInt(String(limit), 10);

  const [total, requests] = await Promise.all([
    prisma.bookingRequest.count({ where: whereClause }),
    prisma.bookingRequest.findMany({
      where: whereClause,
      include: {
        customer: true,
        address: true,
        serviceType: true,
        acUnit: true,
        booking: {
          include: {
            assignments: { include: { technician: { include: { user: true } } } },
            serviceJob: true
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
      items: requests,
      pagination: {
        page: p,
        limit: l,
        total,
        totalPages: Math.ceil(total / l)
      }
    }
  });
});

// Get single booking request details
bookingRequestsRouter.get('/:id', authorize(Role.ADMIN, Role.BOOKING_STAFF), async (req: Request, res: Response) => {
  const request = await prisma.bookingRequest.findUnique({
    where: { id: req.params.id },
    include: {
      customer: { include: { addresses: true, acUnits: true } },
      address: true,
      serviceType: true,
      acUnit: true,
      booking: {
        include: {
          assignments: { include: { technician: { include: { user: true } } } },
          serviceJob: { include: { checklistItems: true, attachments: true, partsConsumed: true } }
        }
      }
    }
  });

  if (!request) {
    return res.status(404).json({ success: false, error: { code: 'NOT_FOUND', message: 'Booking request not found' } });
  }

  return res.json({ success: true, data: request });
});

const createTicketSchema = z.object({
  customerName: z.string().min(2),
  customerPhone: z.string().min(10),
  customerEmail: z.string().email().optional(),
  addressLine: z.string().min(3),
  area: z.string().min(2),
  pincode: z.string().min(6),
  serviceTypeId: z.string().optional(),
  complaint: z.string().min(3),
  priority: z.enum(['LOW', 'MEDIUM', 'HIGH', 'EMERGENCY']).default('MEDIUM'),
  acBrand: z.string().optional(),
  acType: z.string().optional(),
  acTonnage: z.number().optional(),
  preferredDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  preferredTimeSlot: z.string() // e.g. "09:00-11:00"
});

// Create new Incident Ticket / Booking Request (Staff & Admin only)
bookingRequestsRouter.post('/', authorize(Role.ADMIN, Role.BOOKING_STAFF), validateBody(createTicketSchema), async (req: Request, res: Response) => {
  const body = req.body;
  const staffUserId = req.user!.userId;

  try {
    const result = await prisma.$transaction(async (tx) => {
      // 0. Resolve valid serviceTypeId
      let validServiceId = body.serviceTypeId;
      if (validServiceId) {
        const existing = await tx.serviceType.findUnique({ where: { id: validServiceId } });
        if (!existing) validServiceId = undefined;
      }
      if (!validServiceId) {
        const firstService = await tx.serviceType.findFirst({ where: { isActive: true } });
        validServiceId = firstService?.id;
      }
      if (!validServiceId) {
        const newService = await tx.serviceType.create({
          data: {
            code: 'GENERAL_SERVICE',
            nameEn: 'General AC Inspection & Service',
            nameTa: 'பொது ஏசி ஆய்வு & சர்வீஸ்',
            basePrice: 499
          }
        });
        validServiceId = newService.id;
      }
      // 1. Get or create customer by phone
      let customer = await tx.customer.findUnique({
        where: { phone: body.customerPhone }
      });

      if (!customer) {
        customer = await tx.customer.create({
          data: {
            name: body.customerName,
            phone: body.customerPhone,
            email: body.customerEmail || null
          }
        });
      }

      // 2. Create customer address
      const address = await tx.customerAddress.create({
        data: {
          customerId: customer.id,
          addressLine: body.addressLine,
          area: body.area,
          pincode: body.pincode
        }
      });

      // 3. Optional AC Unit
      let acUnit = null;
      if (body.acBrand || body.acType || body.acTonnage) {
        acUnit = await tx.acUnit.create({
          data: {
            customerId: customer.id,
            addressId: address.id,
            brand: body.acBrand || 'Generic',
            unitType: body.acType || 'SPLIT',
            tonnage: body.acTonnage || 1.5
          }
        });
      }

      // 4. Generate reference number
      const datePart = new Date().toISOString().slice(0, 10).replace(/-/g, '');
      const count = await tx.bookingRequest.count();
      const refNum = `TKT-${datePart}-${(count + 1).toString().padStart(4, '0')}`;

      const preferredDateUtc = new Date(body.preferredDate);
      preferredDateUtc.setUTCHours(0, 0, 0, 0);

      // 5. Create Ticket
      const ticket = await tx.bookingRequest.create({
        data: {
          referenceNumber: refNum,
          customerId: customer.id,
          addressId: address.id,
          serviceTypeId: validServiceId,
          acUnitId: acUnit?.id,
          complaint: body.complaint,
          acBrand: body.acBrand,
          acType: body.acType,
          acTonnage: body.acTonnage,
          priority: body.priority,
          isStaffCreated: true,
          createdByStaffId: staffUserId,
          preferredDate: preferredDateUtc,
          preferredTimeSlot: body.preferredTimeSlot,
          status: RequestStatus.PENDING_APPROVAL
        },
        include: {
          customer: true,
          address: true,
          serviceType: true
        }
      });

      return ticket;
    });

    // Send confirmation message to customer via Outbox
    const { queueOutboxEvent } = await import('../services/outboxService');
    await queueOutboxEvent('TICKET_CREATED', {
      recipientPhone: result.customer.phone,
      messageBody: `Dear ${result.customer.name}, your service incident ticket ${result.referenceNumber} has been logged. Our dispatch team will assign a technician shortly.`,
      ticketId: result.id,
      referenceNumber: result.referenceNumber
    });

    return res.status(201).json({
      success: true,
      message: 'Incident ticket created successfully by staff',
      data: result
    });
  } catch (err: any) {
    return res.status(400).json({
      success: false,
      error: { code: 'TICKET_CREATION_FAILED', message: err.message }
    });
  }
});

const approveSchema = z.object({
  technicianId: z.string().uuid(),
  scheduledDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  timeSlot: z.string(), // "09:00-11:00"
  estimatedAmount: z.number().optional(),
  notes: z.string().optional(),
  overrideAreaRestriction: z.boolean().optional()
});

// Admin Approval: Validates technician availability & schedule conflict
bookingRequestsRouter.post('/:id/approve', authorize(Role.ADMIN), validateBody(approveSchema), async (req: Request, res: Response) => {
  try {
    const result = await bookingApprovalService.approveBookingRequest({
      bookingRequestId: req.params.id,
      technicianId: req.body.technicianId,
      scheduledDate: req.body.scheduledDate,
      timeSlot: req.body.timeSlot,
      estimatedAmount: req.body.estimatedAmount,
      adminUserId: req.user!.userId,
      notes: req.body.notes,
      overrideAreaRestriction: req.body.overrideAreaRestriction ?? true
    });

    return res.json({
      success: true,
      message: 'Booking request approved, assignment created, and service job dispatched',
      data: result
    });
  } catch (err: any) {
    return res.status(400).json({
      success: false,
      error: { code: 'APPROVAL_FAILED', message: err.message }
    });
  }
});

const proposeSchema = z.object({
  proposedDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  proposedTimeSlot: z.string(),
  reason: z.string().optional()
});

// Propose Alternative Slot
bookingRequestsRouter.post('/:id/propose-slot', authorize(Role.ADMIN), validateBody(proposeSchema), async (req: Request, res: Response) => {
  try {
    const updated = await bookingApprovalService.proposeAlternativeSlot({
      bookingRequestId: req.params.id,
      proposedDate: req.body.proposedDate,
      proposedTimeSlot: req.body.proposedTimeSlot,
      adminUserId: req.user!.userId,
      reason: req.body.reason
    });

    return res.json({
      success: true,
      message: 'Alternative slot proposed to customer via WhatsApp',
      data: updated
    });
  } catch (err: any) {
    return res.status(400).json({
      success: false,
      error: { code: 'PROPOSAL_FAILED', message: err.message }
    });
  }
});

const rejectSchema = z.object({
  rejectionReason: z.string().min(5)
});

// Reject Booking Request
bookingRequestsRouter.post('/:id/reject', authorize(Role.ADMIN), validateBody(rejectSchema), async (req: Request, res: Response) => {
  try {
    const updated = await bookingApprovalService.rejectBookingRequest({
      bookingRequestId: req.params.id,
      rejectionReason: req.body.rejectionReason,
      adminUserId: req.user!.userId
    });

    return res.json({
      success: true,
      message: 'Booking request rejected and customer informed',
      data: updated
    });
  } catch (err: any) {
    return res.status(400).json({
      success: false,
      error: { code: 'REJECTION_FAILED', message: err.message }
    });
  }
});

const updateBookingSchema = z.object({
  customerName: z.string().min(2).optional(),
  customerPhone: z.string().min(10).optional(),
  customerEmail: z.string().email().optional().nullable(),
  addressLine: z.string().min(3).optional(),
  area: z.string().min(2).optional(),
  pincode: z.string().min(6).optional(),
  serviceTypeId: z.string().uuid().optional(),
  complaint: z.string().min(3).optional(),
  priority: z.enum(['LOW', 'MEDIUM', 'HIGH', 'EMERGENCY']).optional(),
  acBrand: z.string().optional().nullable(),
  acType: z.string().optional().nullable(),
  acTonnage: z.number().optional().nullable(),
  preferredDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
  preferredTimeSlot: z.string().optional()
});

// Edit Booking Details (Admin & Staff) - Even when confirmed or approved
bookingRequestsRouter.put('/:id', authorize(Role.ADMIN, Role.BOOKING_STAFF), validateBody(updateBookingSchema), async (req: Request, res: Response) => {
  const { id } = req.params;
  const body = req.body;

  try {
    const existing = await prisma.bookingRequest.findUnique({
      where: { id },
      include: { customer: true, address: true, acUnit: true, booking: true }
    });

    if (!existing || existing.isDeleted) {
      return res.status(404).json({ success: false, error: { code: 'NOT_FOUND', message: 'Booking request not found' } });
    }

    const updated = await prisma.$transaction(async (tx) => {
      // 1. Update customer if fields provided
      if (body.customerName || body.customerPhone || body.customerEmail !== undefined) {
        await tx.customer.update({
          where: { id: existing.customerId },
          data: {
            name: body.customerName ?? undefined,
            phone: body.customerPhone ?? undefined,
            email: body.customerEmail !== undefined ? body.customerEmail : undefined
          }
        });
      }

      // 2. Update address if provided
      if (body.addressLine || body.area || body.pincode) {
        await tx.customerAddress.update({
          where: { id: existing.addressId },
          data: {
            addressLine: body.addressLine ?? undefined,
            area: body.area ?? undefined,
            pincode: body.pincode ?? undefined
          }
        });
      }

      // 3. Update or create AC Unit
      if (existing.acUnitId && (body.acBrand !== undefined || body.acType !== undefined || body.acTonnage !== undefined)) {
        await tx.acUnit.update({
          where: { id: existing.acUnitId },
          data: {
            brand: body.acBrand ?? undefined,
            unitType: body.acType ?? undefined,
            tonnage: body.acTonnage ?? undefined
          }
        });
      }

      // 4. Update BookingRequest
      const reqData: any = {};
      if (body.complaint) reqData.complaint = body.complaint;
      if (body.priority) reqData.priority = body.priority;
      if (body.serviceTypeId) reqData.serviceTypeId = body.serviceTypeId;
      if (body.acBrand !== undefined) reqData.acBrand = body.acBrand;
      if (body.acType !== undefined) reqData.acType = body.acType;
      if (body.acTonnage !== undefined) reqData.acTonnage = body.acTonnage;
      if (body.preferredTimeSlot) reqData.preferredTimeSlot = body.preferredTimeSlot;
      if (body.preferredDate) {
        const d = new Date(body.preferredDate);
        d.setUTCHours(0, 0, 0, 0);
        reqData.preferredDate = d;
      }

      const updatedRequest = await tx.bookingRequest.update({
        where: { id },
        data: reqData,
        include: {
          customer: true,
          address: true,
          serviceType: true,
          acUnit: true,
          booking: {
            include: {
              assignments: { include: { technician: { include: { user: true } } } },
              serviceJob: true
            }
          }
        }
      });

      // 5. If booking already exists, sync scheduled details & service type if updated
      if (existing.booking) {
        const bookingUpdate: any = {};
        if (body.serviceTypeId) bookingUpdate.serviceTypeId = body.serviceTypeId;
        if (body.preferredTimeSlot) bookingUpdate.timeSlot = body.preferredTimeSlot;
        if (body.preferredDate) {
          const d = new Date(body.preferredDate);
          d.setUTCHours(0, 0, 0, 0);
          bookingUpdate.scheduledDate = d;
        }

        if (Object.keys(bookingUpdate).length > 0) {
          await tx.booking.update({
            where: { id: existing.booking.id },
            data: bookingUpdate
          });
        }
      }

      return updatedRequest;
    });

    return res.json({
      success: true,
      message: 'Booking details updated successfully',
      data: updated
    });
  } catch (err: any) {
    return res.status(400).json({
      success: false,
      error: { code: 'UPDATE_FAILED', message: err.message }
    });
  }
});

// Delete Booking Request (Admin only - soft delete)
bookingRequestsRouter.delete('/:id', authorize(Role.ADMIN), async (req: Request, res: Response) => {
  const { id } = req.params;

  try {
    const existing = await prisma.bookingRequest.findUnique({
      where: { id },
      include: { booking: { include: { serviceJob: true } } }
    });

    if (!existing || existing.isDeleted) {
      return res.status(404).json({ success: false, error: { code: 'NOT_FOUND', message: 'Booking request not found' } });
    }

    // If there is an active completed job, prevent accidental deletion
    if (existing.booking?.serviceJob?.status === 'COMPLETED') {
      return res.status(400).json({
        success: false,
        error: { code: 'CANNOT_DELETE_COMPLETED', message: 'Cannot delete a booking that has a completed service job. Cancel it instead.' }
      });
    }

    await prisma.$transaction(async (tx) => {
      // Soft-delete request
      await tx.bookingRequest.update({
        where: { id },
        data: { isDeleted: true, status: 'CANCELLED' }
      });

      if (existing.booking) {
        await tx.booking.update({
          where: { id: existing.booking.id },
          data: { status: 'CANCELLED' }
        });

        if (existing.booking.serviceJob) {
          await tx.serviceJob.update({
            where: { id: existing.booking.serviceJob.id },
            data: { status: 'CANCELLED' }
          });
        }
      }
    });

    return res.json({
      success: true,
      message: 'Booking deleted successfully'
    });
  } catch (err: any) {
    return res.status(400).json({
      success: false,
      error: { code: 'DELETE_FAILED', message: err.message }
    });
  }
});

