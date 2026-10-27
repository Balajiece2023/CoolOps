import { ZodSchema, ZodError } from 'zod';
import { Request, Response, NextFunction } from 'express';

export function validateBody(schema: ZodSchema) {
  return (req: Request, res: Response, next: NextFunction) => {
    try {
      req.body = schema.parse(req.body);
      next();
    } catch (error) {
      if (error instanceof ZodError) {
        return res.status(400).json({
          success: false,
          error: {
            code: 'VALIDATION_ERROR',
            message: 'Invalid request body',
            details: error.errors.map(e => ({ field: e.path.join('.'), message: e.message }))
          }
        });
      }
      return res.status(400).json({ success: false, error: { code: 'BAD_REQUEST', message: 'Failed to parse request body' } });
    }
  };
}
