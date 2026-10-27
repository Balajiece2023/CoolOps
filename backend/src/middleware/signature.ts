import crypto from 'crypto';
import { Request, Response, NextFunction } from 'express';
import { config } from '../config';

/**
 * Validates Meta WhatsApp Webhook X-Hub-Signature-256 header.
 * Meta computes HMAC-SHA256 of raw body using your App Secret.
 */
export function verifyMetaSignature(req: Request, res: Response, next: NextFunction) {
  // If in test env or WhatsApp integration disabled and signature not supplied, allow for testing
  if (config.env === 'test' || !config.metaWhatsApp.enabled) {
    if (!req.headers['x-hub-signature-256']) {
      return next();
    }
  }

  const signatureHeader = req.headers['x-hub-signature-256'] as string;
  if (!signatureHeader) {
    return res.status(401).json({
      success: false,
      error: { code: 'MISSING_SIGNATURE', message: 'Missing X-Hub-Signature-256 header' }
    });
  }

  const [prefix, signature] = signatureHeader.split('=');
  if (prefix !== 'sha256' || !signature) {
    return res.status(401).json({
      success: false,
      error: { code: 'INVALID_SIGNATURE_FORMAT', message: 'Malformed X-Hub-Signature-256 header' }
    });
  }

  const rawBody = (req as any).rawBody || JSON.stringify(req.body);
  const expectedSignature = crypto
    .createHmac('sha256', config.metaWhatsApp.appSecret)
    .update(rawBody)
    .digest('hex');

  const trusted = Buffer.from(expectedSignature, 'utf8');
  const untrusted = Buffer.from(signature, 'utf8');

  if (trusted.length !== untrusted.length || !crypto.timingSafeEqual(trusted, untrusted)) {
    return res.status(401).json({
      success: false,
      error: { code: 'INVALID_SIGNATURE', message: 'HMAC signature verification failed' }
    });
  }

  next();
}
