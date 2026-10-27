import { prisma } from '../prisma';
import { OutboxStatus } from '@prisma/client';

export async function queueOutboxEvent(eventType: string, payload: any, tx?: any) {
  const db = tx || prisma;
  return await db.outboxEvent.create({
    data: {
      eventType,
      payload,
      status: OutboxStatus.PENDING,
      retryCount: 0,
      maxRetries: 3
    }
  });
}

/**
 * Background worker to process pending outbound events (such as WhatsApp messages)
 */
export async function processOutboxQueue(senderFn: (event: any) => Promise<boolean>) {
  const pendingEvents = await prisma.outboxEvent.findMany({
    where: {
      status: OutboxStatus.PENDING,
      retryCount: { lt: 3 }
    },
    take: 10,
    orderBy: { createdAt: 'asc' }
  });

  for (const event of pendingEvents) {
    try {
      await prisma.outboxEvent.update({
        where: { id: event.id },
        data: { status: OutboxStatus.PROCESSING }
      });

      const success = await senderFn(event);
      if (success) {
        await prisma.outboxEvent.update({
          where: { id: event.id },
          data: { status: OutboxStatus.SENT, processedAt: new Date() }
        });
      } else {
        await prisma.outboxEvent.update({
          where: { id: event.id },
          data: {
            status: event.retryCount + 1 >= event.maxRetries ? OutboxStatus.FAILED : OutboxStatus.PENDING,
            retryCount: { increment: 1 },
            lastError: 'Sender returned false'
          }
        });
      }
    } catch (err: any) {
      await prisma.outboxEvent.update({
        where: { id: event.id },
        data: {
          status: event.retryCount + 1 >= event.maxRetries ? OutboxStatus.FAILED : OutboxStatus.PENDING,
          retryCount: { increment: 1 },
          lastError: err?.message || 'Unknown processing error'
        }
      });
    }
  }
}
