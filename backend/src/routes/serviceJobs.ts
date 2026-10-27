import { Router, Request, Response } from 'express';
import { z } from 'zod';
import { prisma } from '../prisma';
import { authenticate, authorize } from '../middleware/auth';
import { validateBody } from '../middleware/validate';
import { serviceJobWorkflowService } from '../services/serviceJobWorkflowService';
import { JobStatus, Role } from '@prisma/client';

export const serviceJobsRouter = Router();

serviceJobsRouter.use(authenticate);

// Get list of jobs (Technicians see only their own jobs; Admin/Staff see all)
serviceJobsRouter.get('/', async (req: Request, res: Response) => {
  const { status, date } = req.query;
  const user = req.user!;

  const whereClause: any = {};

  // Least-privilege: technician can only access their assigned jobs
  if (user.role === Role.TECHNICIAN) {
    if (!user.technicianId) {
      return res.status(403).json({ success: false, error: { code: 'FORBIDDEN', message: 'User is not linked to a technician profile' } });
    }
    whereClause.technicianId = user.technicianId;
  }

  if (status) {
    whereClause.status = status as JobStatus;
  }

  if (date) {
    const d = new Date(String(date));
    d.setUTCHours(0, 0, 0, 0);
    const nextD = new Date(d);
    nextD.setDate(d.getDate() + 1);

    whereClause.booking = {
      scheduledDate: { gte: d, lt: nextD }
    };
  }

  const jobs = await prisma.serviceJob.findMany({
    where: whereClause,
    include: {
      booking: {
        include: {
          customer: true,
          address: true,
          serviceType: true
        }
      },
      acUnit: true,
      technician: { include: { user: true } },
      checklistItems: true,
      attachments: true,
      partsConsumed: { include: { part: true } }
    },
    orderBy: { createdAt: 'desc' }
  });

  return res.json({ success: true, data: jobs });
});

// Get job details
serviceJobsRouter.get('/:id', async (req: Request, res: Response) => {
  const job = await prisma.serviceJob.findUnique({
    where: { id: req.params.id },
    include: {
      booking: {
        include: {
          customer: true,
          address: true,
          serviceType: true
        }
      },
      acUnit: true,
      technician: { include: { user: true } },
      checklistItems: true,
      attachments: true,
      partsConsumed: { include: { part: true } },
      invoices: { include: { payments: true } }
    }
  });

  if (!job) {
    return res.status(404).json({ success: false, error: { code: 'NOT_FOUND', message: 'Service job not found' } });
  }

  // Authorization check
  if (req.user!.role === Role.TECHNICIAN && job.technicianId !== req.user!.technicianId) {
    return res.status(403).json({ success: false, error: { code: 'FORBIDDEN', message: 'You can only view your assigned jobs' } });
  }

  return res.json({ success: true, data: job });
});

const statusSchema = z.object({
  status: z.nativeEnum(JobStatus),
  diagnosis: z.string().optional(),
  resolutionNotes: z.string().optional()
});

// Update Job Status (Start, En-route, Arrived, In-progress)
serviceJobsRouter.patch('/:id/status', validateBody(statusSchema), async (req: Request, res: Response) => {
  const user = req.user!;
  const job = await prisma.serviceJob.findUnique({ where: { id: req.params.id } });

  if (!job) return res.status(404).json({ success: false, error: { code: 'NOT_FOUND', message: 'Job not found' } });

  const techId = user.role === Role.ADMIN ? job.technicianId : user.technicianId!;

  try {
    const updated = await serviceJobWorkflowService.updateStatus(
      req.params.id,
      techId,
      req.body.status,
      req.body.diagnosis,
      req.body.resolutionNotes
    );
    return res.json({ success: true, data: updated });
  } catch (err: any) {
    return res.status(400).json({ success: false, error: { code: 'STATUS_UPDATE_FAILED', message: err.message } });
  }
});

const requestOtpSchema = z.object({
  alternatePhone: z.string().min(10).max(15).optional()
});

// Request Customer Closure OTP (Triggered by Technician/Admin when work is finished)
serviceJobsRouter.post('/:id/request-closure-otp', async (req: Request, res: Response) => {
  const user = req.user!;
  const job = await prisma.serviceJob.findUnique({ where: { id: req.params.id } });

  if (!job) return res.status(404).json({ success: false, error: { code: 'NOT_FOUND', message: 'Job not found' } });

  const techId = user.role === Role.ADMIN ? job.technicianId : user.technicianId!;
  const alternatePhone = req.body.alternatePhone ? String(req.body.alternatePhone).trim() : undefined;

  try {
    const result = await serviceJobWorkflowService.requestClosureOtp(req.params.id, techId, alternatePhone);
    return res.json({
      success: true,
      message: alternatePhone
        ? `OTP sent to customer's alternate phone (${alternatePhone}) successfully`
        : 'OTP sent to customer phone successfully',
      data: result
    });
  } catch (err: any) {
    return res.status(400).json({ success: false, error: { code: 'OTP_REQUEST_FAILED', message: err.message } });
  }
});

const verifyOtpSchema = z.object({
  otp: z.string().min(4).max(8),
  diagnosis: z.string().optional(),
  resolutionNotes: z.string().optional()
});

// Verify Customer Closure OTP to finalize and close ticket
serviceJobsRouter.post('/:id/verify-closure-otp', validateBody(verifyOtpSchema), async (req: Request, res: Response) => {
  const user = req.user!;
  const job = await prisma.serviceJob.findUnique({ where: { id: req.params.id } });

  if (!job) return res.status(404).json({ success: false, error: { code: 'NOT_FOUND', message: 'Job not found' } });

  const techId = user.role === Role.ADMIN ? job.technicianId : user.technicianId!;

  try {
    const closed = await serviceJobWorkflowService.verifyClosureOtpAndClose(
      req.params.id,
      techId,
      req.body.otp,
      req.body.diagnosis,
      req.body.resolutionNotes
    );
    return res.json({
      success: true,
      message: 'Ticket successfully verified and closed with customer OTP!',
      data: closed
    });
  } catch (err: any) {
    return res.status(400).json({ success: false, error: { code: 'OTP_VERIFICATION_FAILED', message: err.message } });
  }
});

const checklistSchema = z.object({
  isChecked: z.boolean(),
  notes: z.string().optional()
});

// Check off checklist task item
serviceJobsRouter.patch('/:id/checklist/:itemId', validateBody(checklistSchema), async (req: Request, res: Response) => {
  const item = await prisma.jobChecklistItem.findUnique({ where: { id: req.params.itemId } });
  if (!item || item.jobId !== req.params.id) {
    return res.status(404).json({ success: false, error: { code: 'NOT_FOUND', message: 'Checklist item not found' } });
  }

  const updated = await prisma.jobChecklistItem.update({
    where: { id: req.params.itemId },
    data: {
      isChecked: req.body.isChecked,
      notes: req.body.notes,
      completedAt: req.body.isChecked ? new Date() : null
    }
  });

  return res.json({ success: true, data: updated });
});

const attachmentSchema = z.object({
  attachmentType: z.enum(['BEFORE_PHOTO', 'AFTER_PHOTO', 'REPORT', 'DIAGNOSIS_SIGNATURE']),
  fileUrl: z.string().url().or(z.string().min(5)),
  caption: z.string().optional()
});

// Upload job photo/report attachment
serviceJobsRouter.post('/:id/attachments', validateBody(attachmentSchema), async (req: Request, res: Response) => {
  const attachment = await prisma.jobAttachment.create({
    data: {
      jobId: req.params.id,
      attachmentType: req.body.attachmentType,
      fileUrl: req.body.fileUrl,
      caption: req.body.caption
    }
  });

  return res.json({ success: true, data: attachment });
});

const consumePartSchema = z.object({
  partId: z.string().uuid(),
  quantity: z.number().int().positive()
});

// Consume spare part for job (deducts inventory, records stock movement)
serviceJobsRouter.post('/:id/consume-part', validateBody(consumePartSchema), async (req: Request, res: Response) => {
  try {
    const result = await serviceJobWorkflowService.consumePart(req.params.id, req.body.partId, req.body.quantity);
    return res.json({
      success: true,
      message: 'Spare part consumed and stock deducted successfully',
      data: result
    });
  } catch (err: any) {
    return res.status(400).json({ success: false, error: { code: 'PART_CONSUMPTION_FAILED', message: err.message } });
  }
});
