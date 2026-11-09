import { Router, Request, Response } from 'express';
import { z } from 'zod';
import { prisma } from '../prisma';
import { authenticate, authorize } from '../middleware/auth';
import { validateBody } from '../middleware/validate';
import { serviceJobWorkflowService } from '../services/serviceJobWorkflowService';
import { generateInvoicePdf } from '../services/invoicePdfService';
import { Role, PaymentMethod, InvoiceStatus } from '@prisma/client';

export const billingRouter = Router();

billingRouter.use(authenticate);

// 1. Consolidated Financial Summary ("Consol" Dashboard)
billingRouter.get('/consol-summary', authorize(Role.ADMIN, Role.ACCOUNTANT), async (_req: Request, res: Response) => {
  try {
    const invoices = await prisma.invoice.findMany({
      include: {
        customer: true,
        payments: true
      },
      orderBy: { createdAt: 'desc' }
    });

    const expenses = await prisma.expense.findMany({
      orderBy: { expenseDate: 'desc' }
    });

    // 1. Income & Settlements Metrics
    let totalIncome = 0;
    let receivedAmount = 0;
    let fullySettledCount = 0;
    let fullySettledAmount = 0;
    let partiallySettledCount = 0;
    let partiallySettledPaid = 0;
    let partiallySettledRemaining = 0;
    let onHoldCount = 0;
    let onHoldAmount = 0;

    for (const inv of invoices) {
      totalIncome += inv.totalAmount;
      receivedAmount += inv.paidAmount;

      if (inv.status === InvoiceStatus.PAID) {
        fullySettledCount++;
        fullySettledAmount += inv.totalAmount;
      } else if (inv.status === InvoiceStatus.PARTIALLY_PAID) {
        partiallySettledCount++;
        partiallySettledPaid += inv.paidAmount;
        partiallySettledRemaining += Math.max(0, inv.totalAmount - inv.paidAmount);
      } else {
        // ISSUED, DRAFT - completely on-hold
        onHoldCount++;
        onHoldAmount += inv.totalAmount;
      }
    }

    const totalRemainingOnHold = Math.max(0, totalIncome - receivedAmount);
    const settlementRate = totalIncome > 0 ? Math.round((receivedAmount / totalIncome) * 100) : 100;

    // 2. Expense Metrics
    let totalExpenses = 0;
    const categoryTotals: Record<string, { total: number; count: number }> = {};

    for (const exp of expenses) {
      totalExpenses += exp.amount;
      const cat = exp.category.toUpperCase();
      if (!categoryTotals[cat]) {
        categoryTotals[cat] = { total: 0, count: 0 };
      }
      categoryTotals[cat].total += exp.amount;
      categoryTotals[cat].count++;
    }

    const expensesByCategory = Object.entries(categoryTotals).map(([cat, data]) => ({
      category: cat,
      totalAmount: data.total,
      count: data.count,
      percentage: totalExpenses > 0 ? Math.round((data.total / totalExpenses) * 100) : 0
    })).sort((a, b) => b.totalAmount - a.totalAmount);

    // 3. Net Cash Flow
    const netCashFlow = receivedAmount - totalExpenses;

    // 4. Recent Settlement Transactions
    const recentSettlements = await prisma.payment.findMany({
      take: 8,
      orderBy: { paymentDate: 'desc' },
      include: {
        invoice: {
          include: { customer: true }
        },
        receivedBy: {
          select: { name: true }
        }
      }
    });

    return res.json({
      success: true,
      data: {
        summary: {
          totalIncome: Math.round(totalIncome * 100) / 100,
          receivedAmount: Math.round(receivedAmount * 100) / 100,
          onHoldAmount: Math.round(totalRemainingOnHold * 100) / 100,
          settlementRate,
          totalExpenses: Math.round(totalExpenses * 100) / 100,
          netCashFlow: Math.round(netCashFlow * 100) / 100,
          invoicesCount: invoices.length,
          expensesCount: expenses.length
        },
        categorisedIncome: {
          fullySettled: {
            count: fullySettledCount,
            amount: Math.round(fullySettledAmount * 100) / 100
          },
          partiallySettled: {
            count: partiallySettledCount,
            received: Math.round(partiallySettledPaid * 100) / 100,
            onHoldRemaining: Math.round(partiallySettledRemaining * 100) / 100
          },
          completelyOnHold: {
            count: onHoldCount,
            amount: Math.round(onHoldAmount * 100) / 100
          }
        },
        expensesByCategory,
        recentSettlements: recentSettlements.map((p) => ({
          id: p.id,
          receiptNumber: p.receiptNumber,
          invoiceNumber: p.invoice.invoiceNumber,
          customerName: p.invoice.customer.name,
          amount: p.amount,
          paymentMethod: p.paymentMethod,
          referenceNumber: p.referenceNumber,
          date: p.paymentDate,
          receivedByName: p.receivedBy.name
        }))
      }
    });
  } catch (err: any) {
    return res.status(500).json({ success: false, error: { code: 'CONSOL_FAILED', message: err.message } });
  }
});

// 2. Get list of invoices
billingRouter.get('/invoices', authorize(Role.ADMIN, Role.ACCOUNTANT, Role.TECHNICIAN), async (req: Request, res: Response) => {
  const { status, customerId, search } = req.query;

  const whereClause: any = {};
  if (status) whereClause.status = status;
  if (customerId) whereClause.customerId = customerId;
  if (search) {
    whereClause.OR = [
      { invoiceNumber: { contains: String(search), mode: 'insensitive' } },
      { customer: { name: { contains: String(search), mode: 'insensitive' } } },
      { customer: { phone: { contains: String(search), mode: 'insensitive' } } }
    ];
  }

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

// 3. Get invoice by ID
billingRouter.get('/invoices/:id', authorize(Role.ADMIN, Role.ACCOUNTANT, Role.TECHNICIAN), async (req: Request, res: Response) => {
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

// 3b. Delete invoice (with all line items & payments)
billingRouter.delete('/invoices/:id', authorize(Role.ADMIN, Role.ACCOUNTANT, Role.TECHNICIAN), async (req: Request, res: Response) => {
  try {
    const invoice = await prisma.invoice.findUnique({ where: { id: req.params.id } });
    if (!invoice) {
      return res.status(404).json({ success: false, error: { code: 'NOT_FOUND', message: 'Invoice not found' } });
    }

    await prisma.$transaction([
      prisma.invoiceItem.deleteMany({ where: { invoiceId: req.params.id } }),
      prisma.payment.deleteMany({ where: { invoiceId: req.params.id } }),
      prisma.invoice.delete({ where: { id: req.params.id } })
    ]);

    return res.json({ success: true, message: `Invoice ${invoice.invoiceNumber} deleted successfully` });
  } catch (err: any) {
    return res.status(500).json({ success: false, error: { message: err.message } });
  }
});

// 4. Download PDF Invoice
billingRouter.get('/invoices/:id/pdf', authorize(Role.ADMIN, Role.ACCOUNTANT, Role.TECHNICIAN), async (req: Request, res: Response) => {
  try {
    await generateInvoicePdf(req.params.id, res);
  } catch (err: any) {
    return res.status(500).json({ success: false, error: { code: 'PDF_ERROR', message: err.message } });
  }
});

// 4b. Check if invoice already exists for a Service Job
billingRouter.get('/invoices/check-job/:jobId', authorize(Role.ADMIN, Role.ACCOUNTANT, Role.TECHNICIAN), async (req: Request, res: Response) => {
  try {
    const existing = await prisma.invoice.findFirst({
      where: { serviceJobId: req.params.jobId, status: { not: 'CANCELLED' } },
      include: { items: true, customer: true }
    });

    return res.json({
      success: true,
      hasInvoice: !!existing,
      invoice: existing ? {
        id: existing.id,
        invoiceNumber: existing.invoiceNumber,
        totalAmount: existing.totalAmount,
        paidAmount: existing.paidAmount,
        remainingBalance: Math.max(0, existing.totalAmount - existing.paidAmount),
        status: existing.status,
        createdAt: existing.createdAt
      } : null
    });
  } catch (err: any) {
    return res.status(500).json({ success: false, error: { message: err.message } });
  }
});

// 5. Generate Invoice from Completed Job (with duplicate verification & option to replace or duplicate)
const generateInvoiceSchema = z.object({
  jobId: z.string().uuid(),
  discount: z.number().nonnegative().optional(),
  taxRate: z.number().nonnegative().optional(),
  allowDuplicate: z.boolean().optional(),
  replaceExisting: z.boolean().optional()
});

billingRouter.post('/invoices/generate-from-job', authorize(Role.ADMIN, Role.ACCOUNTANT, Role.TECHNICIAN), validateBody(generateInvoiceSchema), async (req: Request, res: Response) => {
  try {
    const { jobId, discount = 0, taxRate = 18.0, allowDuplicate = false, replaceExisting = false } = req.body;

    // Check for existing invoice
    const existing = await prisma.invoice.findFirst({
      where: { serviceJobId: jobId, status: { not: 'CANCELLED' } }
    });

    if (existing && !allowDuplicate && !replaceExisting) {
      return res.status(409).json({
        success: false,
        alreadyExists: true,
        error: {
          code: 'INVOICE_ALREADY_EXISTS',
          message: `An invoice (${existing.invoiceNumber}) of ₹${existing.totalAmount} has already been generated for this job.`
        },
        data: {
          id: existing.id,
          invoiceNumber: existing.invoiceNumber,
          totalAmount: existing.totalAmount,
          paidAmount: existing.paidAmount,
          remainingBalance: Math.max(0, existing.totalAmount - existing.paidAmount),
          status: existing.status,
          createdAt: existing.createdAt
        }
      });
    }

    if (existing && replaceExisting) {
      await prisma.$transaction([
        prisma.invoiceItem.deleteMany({ where: { invoiceId: existing.id } }),
        prisma.payment.deleteMany({ where: { invoiceId: existing.id } }),
        prisma.invoice.delete({ where: { id: existing.id } })
      ]);
    }

    const invoice = await serviceJobWorkflowService.generateJobInvoice(
      jobId,
      req.user!.userId,
      discount,
      taxRate
    );

    return res.json({ success: true, message: 'Invoice generated successfully', data: invoice });
  } catch (err: any) {
    return res.status(400).json({ success: false, error: { code: 'INVOICE_GENERATION_FAILED', message: err.message } });
  }
});

// 6. Create Custom Bill / Invoice directly (with duplicate verification & option to replace or duplicate)
const customInvoiceItemSchema = z.object({
  description: z.string().min(1),
  quantity: z.number().int().positive().default(1),
  unitPrice: z.number().nonnegative(),
  partId: z.string().uuid().optional()
});

const customInvoiceSchema = z.object({
  customerId: z.string().uuid().optional(),
  serviceJobId: z.string().uuid().optional().nullable(),
  customerName: z.string().min(2).optional(),
  customerPhone: z.string().min(10).optional(),
  customerEmail: z.string().email().optional(),
  customerAddress: z.string().optional(),
  items: z.array(customInvoiceItemSchema).min(1),
  discount: z.number().nonnegative().default(0),
  taxRate: z.number().nonnegative().default(18.0),
  dueDate: z.string().optional(),
  notes: z.string().optional(),
  upfrontSettlementAmount: z.number().nonnegative().optional(),
  paymentMethod: z.nativeEnum(PaymentMethod).optional(),
  referenceNumber: z.string().optional(),
  allowDuplicate: z.boolean().optional(),
  replaceExisting: z.boolean().optional()
});

billingRouter.post('/invoices/custom', authorize(Role.ADMIN, Role.ACCOUNTANT, Role.TECHNICIAN), validateBody(customInvoiceSchema), async (req: Request, res: Response) => {
  const {
    customerId: inputCustId,
    serviceJobId,
    customerName,
    customerPhone,
    customerEmail,
    customerAddress,
    items,
    discount,
    taxRate,
    dueDate: inputDueDate,
    notes,
    upfrontSettlementAmount,
    paymentMethod,
    referenceNumber,
    allowDuplicate = false,
    replaceExisting = false
  } = req.body;

  try {
    // Check if an invoice already exists for this service job
    if (serviceJobId) {
      const existing = await prisma.invoice.findFirst({
        where: { serviceJobId, status: { not: 'CANCELLED' } }
      });

      if (existing && !allowDuplicate && !replaceExisting) {
        return res.status(409).json({
          success: false,
          alreadyExists: true,
          error: {
            code: 'INVOICE_ALREADY_EXISTS',
            message: `An invoice (${existing.invoiceNumber}) of ₹${existing.totalAmount} already exists for this job.`
          },
          data: {
            id: existing.id,
            invoiceNumber: existing.invoiceNumber,
            totalAmount: existing.totalAmount,
            paidAmount: existing.paidAmount,
            remainingBalance: Math.max(0, existing.totalAmount - existing.paidAmount),
            status: existing.status,
            createdAt: existing.createdAt
          }
        });
      }

      if (existing && replaceExisting) {
        await prisma.$transaction([
          prisma.invoiceItem.deleteMany({ where: { invoiceId: existing.id } }),
          prisma.payment.deleteMany({ where: { invoiceId: existing.id } }),
          prisma.invoice.delete({ where: { id: existing.id } })
        ]);
      }
    }
    const result = await prisma.$transaction(async (tx) => {
      // 1. Resolve or create customer
      let customerId = inputCustId;
      if (!customerId) {
        if (!customerPhone) throw new Error('Customer phone number is required when creating a custom bill');

        const existingCust = await tx.customer.findUnique({ where: { phone: customerPhone } });
        if (existingCust) {
          customerId = existingCust.id;
        } else {
          const newCust = await tx.customer.create({
            data: {
              name: customerName || 'Valued Client',
              phone: customerPhone,
              email: customerEmail,
              addresses: customerAddress ? {
                create: {
                  addressLine: customerAddress,
                  area: 'Chennai',
                  city: 'Chennai',
                  pincode: '600001'
                }
              } : undefined
            }
          });
          customerId = newCust.id;
        }
      }

      // 2. Compute financial totals
      let subtotal = 0;
      const itemsData = items.map((i: any) => {
        const itemTotal = i.quantity * i.unitPrice;
        subtotal += itemTotal;
        return {
          description: i.description,
          quantity: i.quantity,
          unitPrice: i.unitPrice,
          totalPrice: itemTotal,
          partId: i.partId || null
        };
      });

      const taxable = Math.max(0, subtotal - discount);
      const taxAmount = (taxable * taxRate) / 100.0;
      const totalAmount = Math.round((taxable + taxAmount) * 100) / 100;

      // 3. Invoice Number & Due Date
      const datePart = new Date().toISOString().split('T')[0].replace(/-/g, '');
      const invCount = await tx.invoice.count();
      const invoiceNumber = `INV-${datePart}-${String(invCount + 1).padStart(4, '0')}`;

      const dueDate = inputDueDate ? new Date(inputDueDate) : new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);

      // 4. Initial upfront settlement check
      const upfront = upfrontSettlementAmount && upfrontSettlementAmount > 0 ? upfrontSettlementAmount : 0;
      const initialStatus = upfront >= totalAmount ? InvoiceStatus.PAID : (upfront > 0 ? InvoiceStatus.PARTIALLY_PAID : InvoiceStatus.ISSUED);

      const invoice = await tx.invoice.create({
        data: {
          invoiceNumber,
          customerId,
          serviceJobId: serviceJobId || null,
          subtotal,
          discount,
          taxRate,
          taxAmount,
          totalAmount,
          paidAmount: upfront,
          status: initialStatus,
          dueDate,
          notes,
          createdById: req.user!.userId,
          items: {
            create: itemsData
          }
        },
        include: {
          customer: true,
          items: true,
          payments: true
        }
      });

      // 5. If upfront settlement paid, record receipt
      if (upfront > 0) {
        const rctCount = await tx.payment.count();
        const receiptNumber = `RCT-${datePart}-${String(rctCount + 1).padStart(4, '0')}`;
        await tx.payment.create({
          data: {
            receiptNumber,
            invoiceId: invoice.id,
            amount: upfront,
            paymentMethod: paymentMethod || PaymentMethod.CASH,
            referenceNumber,
            receivedById: req.user!.userId,
            notes: 'Upfront settlement on invoice generation'
          }
        });
      }

      return invoice;
    });

    return res.status(201).json({
      success: true,
      message: 'Custom bill generated successfully!',
      data: result
    });
  } catch (err: any) {
    return res.status(400).json({ success: false, error: { code: 'CUSTOM_INVOICE_FAILED', message: err.message } });
  }
});

// 7. Record Payment / Settlement against Invoice
const settlementSchema = z.object({
  amount: z.number().positive(),
  paymentMethod: z.nativeEnum(PaymentMethod),
  referenceNumber: z.string().optional(),
  notes: z.string().optional()
});

billingRouter.post('/invoices/:id/settlement', authorize(Role.ADMIN, Role.ACCOUNTANT, Role.TECHNICIAN), validateBody(settlementSchema), async (req: Request, res: Response) => {
  const { amount, paymentMethod, referenceNumber, notes } = req.body;

  try {
    const result = await prisma.$transaction(async (tx) => {
      const invoice = await tx.invoice.findUnique({
        where: { id: req.params.id },
        include: { customer: true }
      });

      if (!invoice) throw new Error('Invoice not found');

      const remainingBefore = Math.max(0, invoice.totalAmount - invoice.paidAmount);
      if (remainingBefore <= 0) {
        throw new Error('This bill is already fully settled and paid.');
      }

      const newPaidAmount = Math.round((invoice.paidAmount + amount) * 100) / 100;
      const isFullSettlement = newPaidAmount >= invoice.totalAmount;
      const newStatus = isFullSettlement ? InvoiceStatus.PAID : InvoiceStatus.PARTIALLY_PAID;
      const remainingSettlement = Math.max(0, invoice.totalAmount - newPaidAmount);

      const datePart = new Date().toISOString().split('T')[0].replace(/-/g, '');
      const rctCount = await tx.payment.count();
      const receiptNumber = `RCT-${datePart}-${String(rctCount + 1).padStart(4, '0')}`;

      const payment = await tx.payment.create({
        data: {
          receiptNumber,
          invoiceId: invoice.id,
          amount,
          paymentMethod,
          referenceNumber,
          receivedById: req.user!.userId,
          notes
        }
      });

      const updatedInvoice = await tx.invoice.update({
        where: { id: invoice.id },
        data: {
          paidAmount: newPaidAmount,
          status: newStatus
        },
        include: {
          customer: true,
          payments: true
        }
      });

      return {
        payment,
        invoice: updatedInvoice,
        remainingSettlementAmount: remainingSettlement,
        isFullSettlement
      };
    });

    return res.json({
      success: true,
      message: result.isFullSettlement ? 'Bill settled in full!' : `Settlement of ₹${amount} recorded. Remaining: ₹${result.remainingSettlementAmount}`,
      data: result
    });
  } catch (err: any) {
    return res.status(400).json({ success: false, error: { code: 'SETTLEMENT_FAILED', message: err.message } });
  }
});

// 8. Day-to-Day Technician Expense & Cash Float Tracker Endpoints
billingRouter.get('/expenses', authorize(Role.ADMIN, Role.ACCOUNTANT, Role.TECHNICIAN), async (req: Request, res: Response) => {
  const { category, startDate, endDate, userId } = req.query;

  const whereClause: any = {};
  if (req.user!.role === Role.TECHNICIAN) {
    // Technicians track their own expenses and float allocations
    whereClause.recordedByUserId = req.user!.userId;
  } else if (userId) {
    whereClause.recordedByUserId = String(userId);
  }

  if (category && category !== 'ALL') {
    whereClause.category = String(category).toUpperCase();
  }
  if (startDate || endDate) {
    whereClause.expenseDate = {};
    if (startDate) whereClause.expenseDate.gte = new Date(String(startDate));
    if (endDate) whereClause.expenseDate.lte = new Date(String(endDate));
  }

  const expenses = await prisma.expense.findMany({
    where: whereClause,
    orderBy: { expenseDate: 'desc' }
  });

  // Calculate float allocations vs actual field expenses
  let totalAdvance = 0;
  let totalSpent = 0;

  for (const exp of expenses) {
    if (exp.category === 'ADVANCE' || exp.category === 'FLOAT') {
      totalAdvance += exp.amount;
    } else {
      totalSpent += exp.amount;
    }
  }

  const remainingBalance = Math.round((totalAdvance - totalSpent) * 100) / 100;

  return res.json({
    success: true,
    data: {
      items: expenses,
      summary: {
        totalAdvance,
        totalSpent,
        remainingBalance
      }
    }
  });
});

const createExpenseSchema = z.object({
  category: z.string().min(2),
  amount: z.number().positive(),
  description: z.string().min(2),
  expenseDate: z.string().optional(),
  targetUserId: z.string().optional() // For Admin allocating cash float to technician
});

billingRouter.post('/expenses', authorize(Role.ADMIN, Role.ACCOUNTANT, Role.TECHNICIAN), validateBody(createExpenseSchema), async (req: Request, res: Response) => {
  try {
    const isAdv = req.body.category.toUpperCase().trim() === 'ADVANCE' || req.body.category.toUpperCase().trim() === 'FLOAT';
    let assignedUserId = req.user!.userId;

    // If admin is allocating float/advance, assign to target technician
    if (isAdv && req.body.targetUserId && req.user!.role !== Role.TECHNICIAN) {
      assignedUserId = req.body.targetUserId;
    }

    const expense = await prisma.expense.create({
      data: {
        category: req.body.category.toUpperCase().trim(),
        amount: req.body.amount,
        description: req.body.description.trim(),
        expenseDate: req.body.expenseDate ? new Date(req.body.expenseDate) : new Date(),
        recordedByUserId: assignedUserId
      }
    });

    return res.status(201).json({
      success: true,
      message: isAdv ? 'Advance cash float allocated successfully!' : 'Daily expense recorded successfully!',
      data: expense
    });
  } catch (err: any) {
    return res.status(400).json({ success: false, error: { code: 'EXPENSE_FAILED', message: err.message } });
  }
});

billingRouter.delete('/expenses/:id', authorize(Role.ADMIN, Role.ACCOUNTANT, Role.TECHNICIAN), async (req: Request, res: Response) => {
  try {
    await prisma.expense.delete({ where: { id: req.params.id } });
    return res.json({ success: true, message: 'Expense entry deleted successfully' });
  } catch (err: any) {
    return res.status(400).json({ success: false, error: { code: 'DELETE_EXPENSE_FAILED', message: err.message } });
  }
});
