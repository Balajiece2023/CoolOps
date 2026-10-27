import request from 'supertest';
import { app } from '../../src/app';

describe('Role-Based Access Control Middleware Tests', () => {
  it('GET /api/v1/booking-requests returns 401 UNAUTHORIZED when no token is passed', async () => {
    const res = await request(app).get('/api/v1/booking-requests');
    expect(res.status).toBe(401);
    expect(res.body.success).toBe(false);
    expect(res.body.error.code).toBe('UNAUTHORIZED');
  });

  it('GET /api/v1/billing/invoices returns 401 UNAUTHORIZED when invalid token passed', async () => {
    const res = await request(app)
      .get('/api/v1/billing/invoices')
      .set('Authorization', 'Bearer invalid.jwt.token');

    expect(res.status).toBe(401);
    expect(res.body.success).toBe(false);
  });
});
