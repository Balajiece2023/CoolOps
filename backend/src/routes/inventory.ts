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
