import { Router, Request, Response } from 'express';
import { z } from 'zod';
import { prisma } from '../prisma';
import { authenticate, authorize } from '../middleware/auth';
import { validateBody } from '../middleware/validate';
import { serviceJobWorkflowService } from '../services/serviceJobWorkflowService';
import { generateInvoicePdf } from '../services/invoicePdfService';
import { Role, PaymentMethod } from '@prisma/client';

export const billingRouter = Router();

billingRouter.use(authenticate);

// Get list of invoices
billingRouter.get('/invoices', authorize(Role.ADMIN, Role.ACCOUNTANT), async (req: Request, res: Response) => {
  const { status, customerId } = req.query;

  const whereClause: any = {};
  if (status) whereClause.status = status;
  if (customerId) whereClause.customerId = customerId;

  const invoices = await prisma.invoice.findMany({
    where: whereClause,
    include: {
      customer: true,
      items: true,
      payments: true,
      serviceJob: true
    },
    orderBy: { createdAt: 'desc' }
  });

  return res.json({ success: true, data: invoices });
});

// Get invoice by ID
billingRouter.get('/invoices/:id', authorize(Role.ADMIN, Role.ACCOUNTANT), async (req: Request, res: Response) => {
  const invoice = await prisma.invoice.findUnique({
    where: { id: req.params.id },
    include: {
      customer: { include: { addresses: true } },
      items: true,
      payments: { include: { receivedBy: { select: { name: true } } } },
      serviceJob: { include: { booking: { include: { serviceType: true } } } }
    }
  });

  if (!invoice) return res.status(404).json({ success: false, error: { code: 'NOT_FOUND', message: 'Invoice not found' } });
  return res.json({ success: true, data: invoice });
});

// Download PDF Invoice
billingRouter.get('/invoices/:id/pdf', authorize(Role.ADMIN, Role.ACCOUNTANT), async (req: Request, res: Response) => {
  try {
    await generateInvoicePdf(req.params.id, res);
  } catch (err: any) {
    return res.status(500).json({ success: false, error: { code: 'PDF_ERROR', message: err.message } });
  }
});

const generateInvoiceSchema = z.object({
  jobId: z.string().uuid(),
  discount: z.number().nonnegative().optional(),
  taxRate: z.number().nonnegative().optional()
});

// Generate Invoice from Completed Job
billingRouter.post('/invoices/generate-from-job', authorize(Role.ADMIN, Role.ACCOUNTANT), validateBody(generateInvoiceSchema), async (req: Request, res: Response) => {
  try {
    const invoice = await serviceJobWorkflowService.generateJobInvoice(
      req.body.jobId,
      req.user!.userId,
      req.body.discount || 0,
      req.body.taxRate || 18.0
    );

    return res.json({ success: true, message: 'Invoice generated successfully', data: invoice });
  } catch (err: any) {
    return res.status(400).json({ success: false, error: { code: 'INVOICE_GENERATION_FAILED', message: err.message } });
  }
});

const paymentSchema = z.object({
  invoiceId: z.string().uuid(),
  amount: z.number().positive(),
  paymentMethod: z.nativeEnum(PaymentMethod),
  referenceNumber: z.string().optional()
});

// Record Payment against Invoice
billingRouter.post('/payments', authorize(Role.ADMIN, Role.ACCOUNTANT), validateBody(paymentSchema), async (req: Request, res: Response) => {
  try {
    const result = await serviceJobWorkflowService.recordPayment(
      req.body.invoiceId,
      req.body.amount,
      req.body.paymentMethod,
      req.body.referenceNumber,
      req.user!.userId
    );

    return res.json({ success: true, message: 'Payment recorded successfully', data: result });
  } catch (err: any) {
    return res.status(400).json({ success: false, error: { code: 'PAYMENT_FAILED', message: err.message } });
  }
});
