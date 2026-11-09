import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import rateLimit from 'express-rate-limit';
import { config } from './config';
import { authRouter } from './routes/auth';
import { usersRouter } from './routes/users';
import { bookingRequestsRouter } from './routes/bookingRequests';
import { serviceJobsRouter } from './routes/serviceJobs';
import { billingRouter } from './routes/billing';
import { inventoryRouter } from './routes/inventory';
import { dashboardRouter } from './routes/dashboard';
import { techniciansRouter } from './routes/technicians';
import { attendanceRouter } from './routes/attendance';
import { clientsRouter } from './routes/clients';
import { fieldServiceReportsRouter } from './routes/fieldServiceReports';
import { apiDocsRouter } from './routes/apiDocs';
import { whatsappWebhookRouter } from './routes/whatsappWebhook';

export const app = express();

// Security Middlewares
app.use(helmet());
app.use(cors({ origin: config.corsOrigin, credentials: true }));

// Capture Raw Body for Webhook HMAC Signature Verification (with 15MB limit for local photo uploads)
app.use(express.json({
  limit: '15mb',
  verify: (req: any, _res, buf) => {
    req.rawBody = buf.toString();
  }
}));
app.use(express.urlencoded({ extended: true, limit: '15mb' }));

if (config.env !== 'test') {
  app.use(morgan('dev'));
}

// Global Rate Limiter
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 1000,
  message: { success: false, error: { code: 'RATE_LIMIT_EXCEEDED', message: 'Too many requests, please try again later.' } }
});
app.use(limiter);

// Deep Health & Diagnostics Check (Server, Database, Network)
app.get('/health', async (_req, res) => {
  const startTime = Date.now();
  let dbStatus = 'DISCONNECTED';
  let dbLatencyMs = 0;
  let dbError: string | null = null;

  try {
    const { prisma } = await import('./prisma');
    const dbStart = Date.now();
    await prisma.$queryRaw`SELECT 1`;
    dbLatencyMs = Date.now() - dbStart;
    dbStatus = 'CONNECTED';
  } catch (err: any) {
    dbStatus = 'FAILED';
    dbError = err.message || 'Unknown database connection failure';
  }

  const isHealthy = dbStatus === 'CONNECTED';
  const responseCode = isHealthy ? 200 : 503;

  return res.status(responseCode).json({
    status: isHealthy ? 'healthy' : 'degraded',
    diagnosis: isHealthy 
      ? 'All systems operational (Server + PostgreSQL DB ok)'
      : 'Server is running, but PostgreSQL database is unreachable or disconnected',
    timestamp: new Date().toISOString(),
    uptimeSeconds: Math.floor(process.uptime()),
    subsystems: {
      server: {
        status: 'UP',
        port: config.port,
        environment: config.env,
        nodeVersion: process.version,
        memoryUsageMb: Math.round(process.memoryUsage().heapUsed / 1024 / 1024)
      },
      database: {
        status: dbStatus,
        latencyMs: dbLatencyMs,
        error: dbError
      }
    },
    service: config.business.name
  });
});

// REST API Routes
const api = express.Router();
api.use('/auth', authRouter);
api.use('/users', usersRouter);
api.use('/booking-requests', bookingRequestsRouter);
api.use('/service-jobs', serviceJobsRouter);
api.use('/billing', billingRouter);
api.use('/inventory', inventoryRouter);
api.use('/dashboard', dashboardRouter);
api.use('/technicians', techniciansRouter);
api.use('/attendance', attendanceRouter);
api.use('/clients', clientsRouter);
api.use('/service-reports', fieldServiceReportsRouter);

// Interactive API Testing Console & Documentation
app.use('/api/docs', apiDocsRouter);
app.use('/docs', apiDocsRouter);
app.use('/test-console', apiDocsRouter);

// Webhooks (Meta WhatsApp / External services)
app.use('/webhooks/whatsapp', whatsappWebhookRouter);

app.use(config.apiPrefix, api);

// 404 handler
app.use((_req, res) => {
  res.status(404).json({ success: false, error: { code: 'NOT_FOUND', message: 'Endpoint not found' } });
});

// Centralized Error handler
app.use((err: any, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
  console.error('[Unhandled Server Error]', err);
  res.status(500).json({
    success: false,
    error: {
      code: 'INTERNAL_SERVER_ERROR',
      message: config.env === 'development' ? err.message : 'An internal server error occurred'
    }
  });
});

export function startServer() {
  return app.listen(config.port, '0.0.0.0', () => {
    console.log(`🚀 [Caring CoolTech AC Server] running on http://0.0.0.0:${config.port}${config.apiPrefix}`);
  });
}
