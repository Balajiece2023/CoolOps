import { prisma } from '../prisma';
import { metaWhatsAppClient } from './metaWhatsAppClient';
import { queueOutboxEvent } from './outboxService';
import { RequestStatus } from '@prisma/client';

export type ConversationStep =
  | 'LANGUAGE_SELECT'
  | 'SERVICE_SELECT'
  | 'COMPLAINT_INPUT'
  | 'NAME_INPUT'
  | 'ADDRESS_INPUT'
  | 'AC_DETAILS_INPUT'
  | 'DATE_INPUT'
  | 'TIME_SLOT_SELECT'
  | 'CONFIRMATION'
  | 'COMPLETED';

interface SessionData {
  language?: 'en' | 'ta';
  serviceTypeCode?: string;
  serviceTypeId?: string;
  serviceTypeName?: string;
  complaint?: string;
  customerName?: string;
  addressLine?: string;
  area?: string;
  pincode?: string;
  acBrand?: string;
  acType?: string;
  acTonnage?: number;
  preferredDate?: string; // YYYY-MM-DD
  preferredTimeSlot?: string;
}

export class WhatsAppBotService {
  /**
   * Main entry point when a customer message is received
   */
  async handleInboundMessage(waPhone: string, messageText: string, providerMsgId?: string) {
    const text = messageText.trim();
    const upperText = text.toUpperCase();

    // 1. Get or create conversation record
    let conversation = await prisma.whatsAppConversation.findUnique({
      where: { waPhone }
    });

    if (!conversation) {
      conversation = await prisma.whatsAppConversation.create({
        data: {
          waPhone,
          step: 'LANGUAGE_SELECT',
          language: 'en',
          sessionData: {}
        }
      });
    }

    // Save inbound message
    await prisma.whatsAppMessage.create({
      data: {
        conversationId: conversation.id,
        providerMessageId: providerMsgId,
        direction: 'INBOUND',
        messageBody: text,
        status: 'RECEIVED'
      }
    });

    let currentStep = conversation.step as ConversationStep;
    let session: SessionData = (conversation.sessionData as any) || {};
    const lang = (session.language || 'en') as 'en' | 'ta';

    // Global Notice: Direct customer booking to Staff Line
    const noticeReply = lang === 'ta'
      ? 'வணக்கம்! FrostPro AC சேவையின் புதிய முன்பதிவுகள் எங்கள் வாடிக்கையாளர் சேவை நிர்வாகிகளால் மட்டுமே பதிவு செய்யப்படுகின்றன.\n\n📞 முன்பதிவு செய்ய அழைக்கவும்: +91 98400 12345\n\n(உங்கள் முன்பதிவு நிலை மற்றும் OTP அறிவிப்புகள் இந்த வாட்ஸ்அப் எண்ணில் தானாகவே அனுப்பப்படும்).'
      : 'Hello! Thank you for reaching FrostPro AC Service. New service bookings & incident tickets are now registered exclusively through our staff helpline.\n\n📞 Call our support staff to book: +91 98400 12345\n\n(Active ticket updates, technician ETA, and completion OTPs will be delivered here automatically).';

    await this.replyAndLog(conversation.id, waPhone, noticeReply);
    return;
  }

  private async sendServiceMenu(conversationId: string, waPhone: string, lang: 'en' | 'ta', isRetry = false) {
    const services = await prisma.serviceType.findMany({ where: { isActive: true }, orderBy: { basePrice: 'asc' } });
    let menu = isRetry
      ? (lang === 'ta' ? 'தவறான தேர்வு. பட்டியலிலிருந்து எண்ணைத் தேர்ந்தெடுக்கவும்:\n\n' : 'Invalid selection. Please choose from the list:\n\n')
      : (lang === 'ta' ? 'எங்கள் சேவைகள்:\n\n' : 'Our AC Services:\n\n');

    services.forEach((s, idx) => {
      const name = lang === 'ta' ? s.nameTa : s.nameEn;
      menu += `${idx + 1}. *${name}* - ₹${s.basePrice}\n`;
    });

    menu += lang === 'ta' ? '\nசேவை எண்ணை பதிலளிக்கவும் (எ.கா: 1):' : '\nReply with service number (e.g., 1):';
    await this.replyAndLog(conversationId, waPhone, menu);
  }

  private async saveBookingRequest(waPhone: string, session: SessionData) {
    return await prisma.$transaction(async (tx) => {
      // 1. Find or create Customer
      let customer = await tx.customer.findUnique({ where: { phone: waPhone } });
      if (!customer) {
        customer = await tx.customer.create({
          data: {
            phone: waPhone,
            name: session.customerName || 'Valued Customer',
            language: session.language || 'en'
          }
        });
      }

      // 2. Create Customer Address
      const address = await tx.customerAddress.create({
        data: {
          customerId: customer.id,
          addressLine: session.addressLine || 'Address provided via WhatsApp',
          area: session.area || 'Central',
          pincode: session.pincode || '600001',
          city: 'Chennai',
          isDefault: true
        }
      });

      // 3. Create AC Unit record if details present
      let acUnitId: string | undefined = undefined;
      if (session.acBrand) {
        const acUnit = await tx.acUnit.create({
          data: {
            customerId: customer.id,
            addressId: address.id,
            brand: session.acBrand,
            tonnage: session.acTonnage || 1.5,
            unitType: session.acType || 'SPLIT'
          }
        });
        acUnitId = acUnit.id;
      }

      // 4. Generate reference number
      const datePart = (session.preferredDate || new Date().toISOString().split('T')[0]).replace(/-/g, '');
      const count = await tx.bookingRequest.count();
      const referenceNumber = `REQ-${datePart}-${String(count + 1).padStart(4, '0')}`;

      // 5. Create Booking Request in PENDING_APPROVAL
      const bookingRequest = await tx.bookingRequest.create({
        data: {
          referenceNumber,
          customerId: customer.id,
          addressId: address.id,
          serviceTypeId: session.serviceTypeId!,
          acUnitId,
          complaint: session.complaint || 'General AC Service',
          acBrand: session.acBrand,
          acType: session.acType,
          acTonnage: session.acTonnage,
          preferredDate: new Date(session.preferredDate || new Date()),
          preferredTimeSlot: session.preferredTimeSlot || '09:00-11:00',
          status: RequestStatus.PENDING_APPROVAL
        }
      });

      // 6. Queue Outbox Notification for internal staff
      await queueOutboxEvent('BOOKING_REQUEST_CREATED', {
        bookingRequestId: bookingRequest.id,
        referenceNumber,
        customerName: customer.name,
        phone: customer.phone,
        service: session.serviceTypeName
      }, tx);

      return bookingRequest;
    });
  }

  private async transition(waPhone: string, step: ConversationStep, sessionData: SessionData) {
    await prisma.whatsAppConversation.update({
      where: { waPhone },
      data: {
        step,
        sessionData: sessionData as any,
        lastInteractionAt: new Date()
      }
    });
  }

  private async resetConversation(waPhone: string) {
    await prisma.whatsAppConversation.upsert({
      where: { waPhone },
      update: {
        step: 'LANGUAGE_SELECT',
        sessionData: {},
        lastInteractionAt: new Date()
      },
      create: {
        waPhone,
        step: 'LANGUAGE_SELECT',
        sessionData: {}
      }
    });
  }

  private async replyAndLog(conversationId: string, waPhone: string, text: string) {
    // 1. Send via WhatsApp client
    const res = await metaWhatsAppClient.sendTextMessage(waPhone, text);

    // 2. Record outbound message in DB
    await prisma.whatsAppMessage.create({
      data: {
        conversationId,
        providerMessageId: res.messageId,
        direction: 'OUTBOUND',
        messageBody: text,
        status: res.success ? 'SENT' : 'FAILED'
      }
    });
  }
}

export const whatsAppBotService = new WhatsAppBotService();
