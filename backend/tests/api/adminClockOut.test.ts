import request from 'supertest';
import * as jwt from 'jsonwebtoken';
import { app } from '../../src/app';
import { config } from '../../src/config';
import { Role } from '@prisma/client';

describe('Admin Clock-Out API Tests', () => {
  const adminToken = jwt.sign(
    { userId: 'admin-uuid-1', email: 'admin@coolops.com', role: Role.ADMIN },
    config.jwt.accessSecret
  );

  const technicianToken = jwt.sign(
    { userId: 'tech-uuid-1', email: 'tech@coolops.com', role: Role.TECHNICIAN, technicianId: 'tech-1' },
    config.jwt.accessSecret
  );

  it('POST /api/v1/attendance/admin/clock-out returns 401 UNAUTHORIZED when no token is passed', async () => {
    const res = await request(app)
      .post('/api/v1/attendance/admin/clock-out')
      .send({ technicianId: 'some-tech-id' });

    expect(res.status).toBe(401);
    expect(res.body.success).toBe(false);
  });

  it('POST /api/v1/attendance/admin/clock-out returns 403 FORBIDDEN when called by a TECHNICIAN', async () => {
    const res = await request(app)
      .post('/api/v1/attendance/admin/clock-out')
      .set('Authorization', `Bearer ${technicianToken}`)
      .send({ technicianId: 'some-tech-id' });

    expect(res.status).toBe(403);
    expect(res.body.success).toBe(false);
  });

  it('POST /api/v1/attendance/admin/clock-out returns 400 when technicianId is missing', async () => {
    const res = await request(app)
      .post('/api/v1/attendance/admin/clock-out')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({});

    expect(res.status).toBe(400);
    expect(res.body.success).toBe(false);
  });

  it('POST /api/v1/technicians/:id/clock-out returns 401 UNAUTHORIZED when no token is passed', async () => {
    const res = await request(app)
      .post('/api/v1/technicians/tech-123/clock-out')
      .send({});

    expect(res.status).toBe(401);
    expect(res.body.success).toBe(false);
  });

  it('POST /api/v1/technicians/:id/clock-out returns 403 FORBIDDEN when called by a TECHNICIAN', async () => {
    const res = await request(app)
      .post('/api/v1/technicians/tech-123/clock-out')
      .set('Authorization', `Bearer ${technicianToken}`)
      .send({});

    expect(res.status).toBe(403);
    expect(res.body.success).toBe(false);
  });
});
