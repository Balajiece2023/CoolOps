import { Router, Request, Response } from 'express';
import { z } from 'zod';
import bcrypt from 'bcrypt';
import { prisma } from '../prisma';
import { authenticate, authorize } from '../middleware/auth';
import { validateBody } from '../middleware/validate';
import { Role } from '@prisma/client';

export const usersRouter = Router();

usersRouter.use(authenticate);

// 1. List all staff & users (Admin only)
usersRouter.get('/', authorize(Role.ADMIN), async (_req: Request, res: Response) => {
  const users = await prisma.user.findMany({
    select: {
      id: true,
      email: true,
      name: true,
      role: true,
      phone: true,
      avatarUrl: true,
      isActive: true,
      createdAt: true,
      technician: {
        select: {
          id: true,
          skills: true,
          serviceAreas: true,
          maxDailyJobs: true,
          isOnline: true,
          isAvailable: true
        }
      }
    },
    orderBy: { createdAt: 'desc' }
  });

  return res.json({ success: true, data: users });
});

const createUserSchema = z.object({
  name: z.string().min(2),
  email: z.string().email(),
  password: z.string().min(6),
  phone: z.string().min(10).optional(),
  role: z.nativeEnum(Role),
  avatarUrl: z.string().optional(),
  skills: z.array(z.string()).optional(),
  serviceAreas: z.array(z.string()).optional(),
  maxDailyJobs: z.number().int().positive().optional()
});

// 2. Add new user with any role (Admin only)
usersRouter.post('/', authorize(Role.ADMIN), validateBody(createUserSchema), async (req: Request, res: Response) => {
  const { name, email, password, phone, role, avatarUrl, skills, serviceAreas, maxDailyJobs } = req.body;

  try {
    const existing = await prisma.user.findUnique({ where: { email } });
    if (existing) {
      return res.status(400).json({ success: false, error: { code: 'USER_EXISTS', message: 'User with this email already exists' } });
    }

    const passwordHash = await bcrypt.hash(password, 10);

    const user = await prisma.$transaction(async (tx) => {
      const newUser = await tx.user.create({
        data: {
          email,
          passwordHash,
          name,
          phone,
          role,
          avatarUrl: avatarUrl || null,
          isActive: true
        }
      });

      if (role === Role.TECHNICIAN) {
        await tx.technician.create({
          data: {
            userId: newUser.id,
            skills: skills && skills.length > 0 ? skills : ['SPLIT', 'WINDOW'],
            serviceAreas: serviceAreas && serviceAreas.length > 0 ? serviceAreas : ['Chennai Central'],
            maxDailyJobs: maxDailyJobs || 4,
            isAvailable: true,
            isOnline: false
          }
        });
      }

      return newUser;
    });

    return res.status(201).json({
      success: true,
      message: `User ${user.name} (${user.role}) created successfully`,
      data: {
        id: user.id,
        email: user.email,
        name: user.name,
        role: user.role,
        phone: user.phone,
        avatarUrl: user.avatarUrl
      }
    });
  } catch (err: any) {
    return res.status(400).json({ success: false, error: { code: 'CREATE_USER_FAILED', message: err.message } });
  }
});

const updateUserSchema = z.object({
  name: z.string().min(2).optional(),
  phone: z.string().min(10).optional(),
  role: z.nativeEnum(Role).optional(),
  avatarUrl: z.string().optional().nullable(),
  isActive: z.boolean().optional()
});

// 3. Update user details & status (Admin only)
usersRouter.put('/:id', authorize(Role.ADMIN), validateBody(updateUserSchema), async (req: Request, res: Response) => {
  try {
    const existing = await prisma.user.findUnique({ where: { id: req.params.id } });
    if (!existing) {
      return res.status(404).json({ success: false, error: { code: 'NOT_FOUND', message: 'User not found' } });
    }

    const updated = await prisma.user.update({
      where: { id: req.params.id },
      data: req.body,
      select: {
        id: true,
        email: true,
        name: true,
        role: true,
        phone: true,
        avatarUrl: true,
        isActive: true
      }
    });

    return res.json({ success: true, message: 'User updated successfully', data: updated });
  } catch (err: any) {
    return res.status(400).json({ success: false, error: { code: 'UPDATE_USER_FAILED', message: err.message } });
  }
});

// 4. Delete / Deactivate user (Admin only)
usersRouter.delete('/:id', authorize(Role.ADMIN), async (req: Request, res: Response) => {
  const adminId = req.user!.userId;
  if (req.params.id === adminId) {
    return res.status(400).json({
      success: false,
      error: { code: 'SELF_DELETION_PROHIBITED', message: 'You cannot delete your own active admin account.' }
    });
  }

  try {
    const user = await prisma.user.findUnique({
      where: { id: req.params.id },
      include: { technician: { include: { serviceJobs: { where: { status: { in: ['PENDING', 'EN_ROUTE', 'ARRIVED', 'IN_PROGRESS'] } } } } } }
    });

    if (!user) {
      return res.status(404).json({ success: false, error: { code: 'NOT_FOUND', message: 'User not found' } });
    }

    if (user.technician && user.technician.serviceJobs.length > 0) {
      return res.status(400).json({
        success: false,
        error: { code: 'ACTIVE_JOBS_EXIST', message: `Cannot delete technician with ${user.technician.serviceJobs.length} active service jobs.` }
      });
    }

    // Soft delete/deactivate to protect financial invoices and audit history
    await prisma.$transaction(async (tx) => {
      await tx.user.update({
        where: { id: user.id },
        data: { isActive: false }
      });

      if (user.technician) {
        await tx.technician.update({
          where: { id: user.technician.id },
          data: { isAvailable: false, isOnline: false }
        });
      }
    });

    return res.json({
      success: true,
      message: `User ${user.name} (${user.role}) has been deactivated and removed.`
    });
  } catch (err: any) {
    return res.status(400).json({ success: false, error: { code: 'DELETE_USER_FAILED', message: err.message } });
  }
});
