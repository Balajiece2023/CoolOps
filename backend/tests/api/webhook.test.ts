import request from 'supertest';
import { app } from '../../src/app';
import { config } from '../../src/config';

describe('WhatsApp Webhook Verification & Processing Tests', () => {
  it('GET /webhooks/whatsapp verifies hub challenge when token matches', async () => {
    const res = await request(app)
      .get('/webhooks/whatsapp')
      .query({
        'hub.mode': 'subscribe',
        'hub.verify_token': config.metaWhatsApp.verifyToken,
        'hub.challenge': 'CHALLENGE_ACCEPTED_12345'
      });

    expect(res.status).toBe(200);
    expect(res.text).toBe('CHALLENGE_ACCEPTED_12345');
  });

  it('GET /webhooks/whatsapp rejects challenge when verify token is incorrect', async () => {
    const res = await request(app)
      .get('/webhooks/whatsapp')
      .query({
        'hub.mode': 'subscribe',
        'hub.verify_token': 'wrong_token',
        'hub.challenge': 'CHALLENGE_ACCEPTED_12345'
      });

    expect(res.status).toBe(403);
  });

  it('POST /webhooks/whatsapp acknowledges event immediately with 200 OK', async () => {
    const res = await request(app)
      .post('/webhooks/whatsapp')
      .send({
        object: 'whatsapp_business_account',
        entry: []
      });

    expect(res.status).toBe(200);
    expect(res.text).toBe('EVENT_RECEIVED');
  });
});
