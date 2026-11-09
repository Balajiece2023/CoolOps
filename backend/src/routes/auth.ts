import { Router, Request, Response } from 'express';
import * as bcrypt from 'bcrypt';
import * as jwt from 'jsonwebtoken';
import { z } from 'zod';
import { prisma } from '../prisma';
import { config } from '../config';
import { validateBody } from '../middleware/validate';
import { authenticate } from '../middleware/auth';
import { emailService } from '../services/emailService';
import { otpService } from '../services/otpService';

export const authRouter = Router();

const loginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(6)
});

const refreshSchema = z.object({
  refreshToken: z.string()
});

authRouter.post('/login', validateBody(loginSchema), async (req: Request, res: Response) => {
  const { email, password } = req.body;

  const user = await prisma.user.findUnique({
    where: { email },
    include: { technician: true }
  });

  if (!user || !user.isActive) {
    return res.status(401).json({
      success: false,
      error: { code: 'INVALID_CREDENTIALS', message: 'Invalid email or password' }
    });
  }

  const isMatch = await bcrypt.compare(password, user.passwordHash);
  if (!isMatch) {
    return res.status(401).json({
      success: false,
      error: { code: 'INVALID_CREDENTIALS', message: 'Invalid email or password' }
    });
  }

  const payload = {
    userId: user.id,
    email: user.email,
    role: user.role,
    technicianId: user.technician?.id
  };

  const accessToken = jwt.sign(payload, config.jwt.accessSecret, { expiresIn: '30d' });
  const refreshToken = jwt.sign({ userId: user.id }, config.jwt.refreshSecret, { expiresIn: '90d' });

  return res.json({
    success: true,
    data: {
      accessToken,
      refreshToken,
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        role: user.role,
        phone: user.phone,
        avatarUrl: user.avatarUrl,
        technicianId: user.technician?.id
      }
    }
  });
});

authRouter.post('/refresh', validateBody(refreshSchema), async (req: Request, res: Response) => {
  const { refreshToken } = req.body;
  try {
    const decoded = jwt.verify(refreshToken, config.jwt.refreshSecret) as { userId: string };
    const user = await prisma.user.findUnique({
      where: { id: decoded.userId },
      include: { technician: true }
    });

    if (!user || !user.isActive) {
      return res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'User not found or inactive' } });
    }

    const payload = {
      userId: user.id,
      email: user.email,
      role: user.role,
      technicianId: user.technician?.id
    };

    const newAccessToken = jwt.sign(payload, config.jwt.accessSecret, { expiresIn: '30d' });
    return res.json({
      success: true,
      data: { accessToken: newAccessToken }
    });
  } catch (err) {
    return res.status(401).json({ success: false, error: { code: 'INVALID_REFRESH_TOKEN', message: 'Refresh token expired or invalid' } });
  }
});

authRouter.get('/me', authenticate, async (req: Request, res: Response) => {
  const user = await prisma.user.findUnique({
    where: { id: req.user!.userId },
    select: {
      id: true,
      email: true,
      name: true,
      role: true,
      phone: true,
      avatarUrl: true,
      technician: {
        select: { id: true, skills: true, serviceAreas: true, isAvailable: true, isOnline: true, currentLatitude: true, currentLongitude: true }
      }
    }
  });

  return res.json({ success: true, data: user });
});

const updateProfileSchema = z.object({
  name: z.string().min(2).optional(),
  phone: z.string().min(10).optional(),
  avatarUrl: z.string().optional().nullable()
});

authRouter.put('/me', authenticate, validateBody(updateProfileSchema), async (req: Request, res: Response) => {
  const { name, phone, avatarUrl } = req.body;
  const updatedUser = await prisma.user.update({
    where: { id: req.user!.userId },
    data: {
      name: name ?? undefined,
      phone: phone ?? undefined,
      avatarUrl: avatarUrl !== undefined ? (avatarUrl === '' ? null : avatarUrl) : undefined
    },
    select: {
      id: true,
      email: true,
      name: true,
      role: true,
      phone: true,
      avatarUrl: true,
      technician: {
        select: { id: true, skills: true, serviceAreas: true, isAvailable: true, isOnline: true, currentLatitude: true, currentLongitude: true }
      }
    }
  });

  return res.json({
    success: true,
    message: 'Profile updated successfully',
    data: updatedUser
  });
});

// In-memory or temporary store for password reset OTPs (email -> { otp, expiresAt })
const passwordResetStore = new Map<string, { otp: string; expiresAt: number }>();

const forgotPasswordSchema = z.object({
  email: z.string().email()
});

authRouter.post('/forgot-password', validateBody(forgotPasswordSchema), async (req: Request, res: Response) => {
  const { email } = req.body;
  const user = await prisma.user.findUnique({ where: { email } });

  if (!user || !user.isActive) {
    return res.status(404).json({
      success: false,
      error: { code: 'USER_NOT_FOUND', message: 'No active user account found with this email' }
    });
  }

  // Generate 6-digit secure cryptographic OTP using open-source otplib/crypto
  const otp = otpService.generateSecureOtp();
  const expiresAt = Date.now() + 10 * 60 * 1000; // 10 minutes

  passwordResetStore.set(email.toLowerCase(), { otp, expiresAt });

  console.log(`🔐 [AUTH] Password reset OTP generated for ${email}: ${otp}`);

  // Send OTP via open-source Nodemailer email module
  const mailResult = await emailService.sendTechnicianPasswordResetOtp({
    to: user.email,
    name: user.name,
    otp
  });

  return res.json({
    success: true,
    message: mailResult.success
      ? `Password reset OTP has been sent to your email (${user.email}).`
      : `Password reset OTP generated. Email notification status: ${mailResult.error || 'simulated'}.`,
    data: {
      email: user.email,
      emailDispatched: mailResult.success,
      expiresInMinutes: 10,
      // Provide demoOtp in development for smooth local testing
      demoOtp: process.env.NODE_ENV !== 'production' ? otp : undefined
    }
  });
});

const resetPasswordSchema = z.object({
  email: z.string().email(),
  otp: z.string().length(6),
  newPassword: z.string().min(6)
});

authRouter.post('/reset-password', validateBody(resetPasswordSchema), async (req: Request, res: Response) => {
  const { email, otp, newPassword } = req.body;
  const record = passwordResetStore.get(email.toLowerCase());

  if (!record || record.expiresAt < Date.now()) {
    return res.status(400).json({
      success: false,
      error: { code: 'OTP_EXPIRED', message: 'Password reset OTP has expired or was not requested. Please request a new one.' }
    });
  }

  if (record.otp !== otp) {
    return res.status(400).json({
      success: false,
      error: { code: 'INVALID_OTP', message: 'The OTP entered is incorrect.' }
    });
  }

  // Hash new password
  const newPasswordHash = await bcrypt.hash(newPassword, 10);

  await prisma.user.update({
    where: { email },
    data: { passwordHash: newPasswordHash }
  });

  // Clear OTP
  passwordResetStore.delete(email.toLowerCase());

  return res.json({
    success: true,
    message: 'Password reset successful! You can now login with your new password.'
  });
});

