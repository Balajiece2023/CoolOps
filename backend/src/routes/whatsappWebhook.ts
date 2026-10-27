import { Router, Request, Response } from 'express';
import { config } from '../config';
import { verifyMetaSignature } from '../middleware/signature';
import { whatsAppBotService } from '../services/whatsAppBotService';
import { prisma } from '../prisma';

export const whatsappWebhookRouter = Router();

/**
 * GET /webhooks/whatsapp
 * Meta Webhook Challenge Verification
 */
whatsappWebhookRouter.get('/', (req: Request, res: Response) => {
  const mode = req.query['hub.mode'];
  const token = req.query['hub.verify_token'];
  const challenge = req.query['hub.challenge'];

  if (mode === 'subscribe' && token === config.metaWhatsApp.verifyToken) {
    console.log('[Meta Webhook] Successfully verified webhook subscription challenge!');
    return res.status(200).send(challenge);
  }

  console.warn('[Meta Webhook] Subscription verification failed. Invalid token.');
  return res.status(403).json({ error: 'Verification token mismatch' });
});

/**
 * POST /webhooks/whatsapp
 * Inbound messages and status notifications from Meta Cloud API
 */
whatsappWebhookRouter.post('/', verifyMetaSignature, async (req: Request, res: Response) => {
  // 1. Immediately return 200 OK to Meta to prevent retry loops
  res.status(200).send('EVENT_RECEIVED');

  const body = req.body;
  if (body.object !== 'whatsapp_business_account') {
    return;
  }

  // 2. Process events asynchronously
  try {
    const entries = body.entry || [];
    for (const entry of entries) {
      const changes = entry.changes || [];
      for (const change of changes) {
        const value = change.value;
        if (!value) continue;

        // Inbound Messages
        if (value.messages && value.messages.length > 0) {
          for (const msg of value.messages) {
            const providerMsgId = msg.id;
            const fromPhone = msg.from; // e.g. "919840012345"

            // Webhook Deduplication: Check if providerMessageId was already processed
            if (providerMsgId) {
              const existing = await prisma.whatsAppMessage.findUnique({
                where: { providerMessageId: providerMsgId }
              });
              if (existing) {
                console.log(`[Meta Webhook] Deduplicated message: ${providerMsgId}`);
                continue;
              }
            }

            let textContent = '';
            if (msg.type === 'text') {
              textContent = msg.text?.body || '';
            } else if (msg.type === 'button') {
              textContent = msg.button?.text || msg.button?.payload || '';
            } else if (msg.type === 'interactive') {
              textContent = msg.interactive?.button_reply?.title || msg.interactive?.list_reply?.title || '';
            }

            if (textContent && fromPhone) {
              await whatsAppBotService.handleInboundMessage(fromPhone, textContent, providerMsgId);
            }
          }
        }

        // Outbound Message Status Updates (SENT, DELIVERED, READ, FAILED)
        if (value.statuses && value.statuses.length > 0) {
          for (const st of value.statuses) {
            const providerMsgId = st.id;
            const newStatus = (st.status || '').toUpperCase();
            if (providerMsgId && newStatus) {
              await prisma.whatsAppMessage.updateMany({
                where: { providerMessageId: providerMsgId },
                data: { status: newStatus }
              });
            }
          }
        }
      }
    }
  } catch (err) {
    console.error('[Meta Webhook Async Error]', err);
  }
});

/**
 * POST /webhooks/whatsapp/simulate
 * Dedicated simulator endpoint for testing WhatsApp chat flow without Meta credentials!
 */
whatsappWebhookRouter.post('/simulate', async (req: Request, res: Response) => {
  const { phone, message } = req.body;
  if (!phone || !message) {
    return res.status(400).json({ success: false, error: 'phone and message are required' });
  }

  const mockProviderId = `sim_${Date.now()}_${Math.random().toString(36).substring(7)}`;
  await whatsAppBotService.handleInboundMessage(phone, message, mockProviderId);

  // Return current conversation state and latest bot reply
  const conversation = await prisma.whatsAppConversation.findUnique({
    where: { waPhone: phone },
    include: {
      messages: {
        orderBy: { createdAt: 'desc' },
        take: 3
      }
    }
  });

  return res.json({
    success: true,
    data: {
      step: conversation?.step,
      sessionData: conversation?.sessionData,
      recentMessages: conversation?.messages
    }
  });
});
