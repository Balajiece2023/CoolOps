import { Router, Request, Response } from 'express';
import { z } from 'zod';
import { prisma } from '../prisma';
import { authenticate, authorize } from '../middleware/auth';
import { validateBody } from '../middleware/validate';
import { Role, StockMovementType } from '@prisma/client';

export const inventoryRouter = Router();

inventoryRouter.use(authenticate);

// Get inventory parts with low stock indicators
inventoryRouter.get('/', async (req: Request, res: Response) => {
  const { lowStockOnly, category, search } = req.query;

  const whereClause: any = {};
  if (category) whereClause.category = String(category);
  if (search) {
    whereClause.OR = [
      { name: { contains: String(search), mode: 'insensitive' } },
      { sku: { contains: String(search), mode: 'insensitive' } }
    ];
  }

  const parts = await prisma.inventoryPart.findMany({
    where: whereClause,
    orderBy: { name: 'asc' }
  });

  const filtered = lowStockOnly === 'true'
    ? parts.filter(p => p.currentStock <= p.minStockAlertLevel)
    : parts;

  return res.json({ success: true, data: filtered });
});

const partSchema = z.object({
  sku: z.string().min(3),
  name: z.string().min(3),
  category: z.string(),
  unitPrice: z.number().positive(),
  sellingPrice: z.number().positive(),
  currentStock: z.number().int().nonnegative().default(0),
  minStockAlertLevel: z.number().int().nonnegative().default(5),
  supplierName: z.string().optional()
});

// Create inventory part
inventoryRouter.post('/', authorize(Role.ADMIN, Role.ACCOUNTANT), validateBody(partSchema), async (req: Request, res: Response) => {
  try {
    const part = await prisma.inventoryPart.create({ data: req.body });
    return res.status(201).json({ success: true, data: part });
  } catch (err: any) {
    return res.status(400).json({ success: false, error: { code: 'CREATE_PART_FAILED', message: err.message } });
  }
});

const updatePartSchema = z.object({
  sku: z.string().min(3).optional(),
  name: z.string().min(3).optional(),
  category: z.string().optional(),
  unitPrice: z.number().positive().optional(),
  sellingPrice: z.number().positive().optional(),
  currentStock: z.number().int().nonnegative().optional(),
  minStockAlertLevel: z.number().int().nonnegative().optional(),
  supplierName: z.string().optional().nullable()
});

// Edit inventory part (Admin & Accountant)
inventoryRouter.put('/:id', authorize(Role.ADMIN, Role.ACCOUNTANT), validateBody(updatePartSchema), async (req: Request, res: Response) => {
  try {
    const existing = await prisma.inventoryPart.findUnique({ where: { id: req.params.id } });
    if (!existing) {
      return res.status(404).json({ success: false, error: { code: 'NOT_FOUND', message: 'Inventory part not found' } });
    }

    const updated = await prisma.inventoryPart.update({
      where: { id: req.params.id },
      data: req.body
    });

    return res.json({ success: true, message: 'Inventory part updated successfully', data: updated });
  } catch (err: any) {
    return res.status(400).json({ success: false, error: { code: 'UPDATE_PART_FAILED', message: err.message } });
  }
});

// Delete inventory part (Admin only)
inventoryRouter.delete('/:id', authorize(Role.ADMIN), async (req: Request, res: Response) => {
  try {
    const existing = await prisma.inventoryPart.findUnique({
      where: { id: req.params.id },
      include: {
        _count: {
          select: { consumedInJobs: true, invoiceItems: true }
        }
      }
    });

    if (!existing) {
      return res.status(404).json({ success: false, error: { code: 'NOT_FOUND', message: 'Inventory part not found' } });
    }

    if (existing._count.consumedInJobs > 0 || existing._count.invoiceItems > 0) {
      // If part has historical links, set currentStock to 0 to prevent breaking ledger
      await prisma.inventoryPart.update({
        where: { id: req.params.id },
        data: { currentStock: 0 }
      });
      return res.json({
        success: true,
        message: 'Part has historical job references; stock set to 0 (deactivated from operations).'
      });
    }

    await prisma.inventoryPart.delete({ where: { id: req.params.id } });
    return res.json({ success: true, message: 'Inventory part deleted successfully' });
  } catch (err: any) {
    return res.status(400).json({ success: false, error: { code: 'DELETE_PART_FAILED', message: err.message } });
  }
});

const stockAdjustSchema = z.object({
  quantity: z.number().int(), // positive for inward, negative for outward
  type: z.nativeEnum(StockMovementType),
  notes: z.string().optional(),
  reference: z.string().optional()
});

// Adjust stock or record stock inward
inventoryRouter.post('/:id/adjust-stock', authorize(Role.ADMIN, Role.ACCOUNTANT), validateBody(stockAdjustSchema), async (req: Request, res: Response) => {
  const { quantity, type, notes, reference } = req.body;

  try {
    const result = await prisma.$transaction(async (tx) => {
      const part = await tx.inventoryPart.findUnique({ where: { id: req.params.id } });
      if (!part) throw new Error('Part not found');

      const newStock = part.currentStock + quantity;
      if (newStock < 0) throw new Error(`Stock cannot drop below 0. Current: ${part.currentStock}`);

      await tx.inventoryPart.update({
        where: { id: part.id },
        data: { currentStock: newStock }
      });

      const movement = await tx.stockMovement.create({
        data: {
          partId: part.id,
          type,
          quantity,
          balanceAfter: newStock,
          reference,
          notes
        }
      });

      return { part: { ...part, currentStock: newStock }, movement };
    });

    return res.json({ success: true, message: 'Stock adjusted successfully', data: result });
  } catch (err: any) {
    return res.status(400).json({ success: false, error: { code: 'STOCK_ADJUSTMENT_FAILED', message: err.message } });
  }
});

// Get movements history for a part
inventoryRouter.get('/:id/movements', async (req: Request, res: Response) => {
  const movements = await prisma.stockMovement.findMany({
    where: { partId: req.params.id },
    orderBy: { createdAt: 'desc' },
    take: 50
  });

  return res.json({ success: true, data: movements });
});
