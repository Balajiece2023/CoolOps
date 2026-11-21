import { config } from '../config';

export interface SendSmsParams {
  to: string;
  message: string;
  senderId?: string;
  context?: string;
}

export interface SendSmsResult {
  success: boolean;
  targetPhone: string;
  message: string;
  provider: string;
  messageId?: string;
  details?: string;
  error?: string;
}

export interface BookingCreatedSmsParams {
  customerName: string;
  customerPhone: string;
  referenceNumber: string;
  scheduledDate?: string | Date | null;
  timeSlot?: string | null;
  serviceName?: string | null;
}

export interface BookingConfirmedSmsParams {
  customerName: string;
  customerPhone: string;
  bookingNumber: string;
  scheduledDate: string | Date;
  timeSlot: string;
  technicianName?: string;
  technicianPhone?: string;
}

function formatDateForSms(dateInput?: string | Date | null): string {
  if (!dateInput) return 'Today';
  const d = new Date(dateInput);
  if (isNaN(d.getTime())) return 'Scheduled';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return `${d.getDate()}-${months[d.getMonth()]}`;
}

export class SmsService {
  /**
   * Cleans and normalizes phone number to international E.164 format (+91...)
   */
  normalizePhoneNumber(phone: string): string {
    if (!phone) return '';
    const clean = phone.replace(/[^0-9]/g, '');
    if (clean.length === 10) {
      return `+91${clean}`;
    }
    if (clean.startsWith('91') && clean.length === 12) {
      return `+${clean}`;
    }
    if (phone.startsWith('+')) {
      return phone;
    }
    return `+${clean}`;
  }

  /**
   * Sends raw SMS via OpenSMS / Open-Source SMS Gateway API with automatic fallback simulation
   */
  async sendSms(params: SendSmsParams): Promise<SendSmsResult> {
    const { to, message, senderId, context = 'GENERAL' } = params;
    const targetPhone = this.normalizePhoneNumber(to);

    if (!targetPhone || targetPhone.length < 10) {
      console.warn(`⚠️ [SMS-DISPATCHER] Skipped sending SMS: invalid target phone "${to}"`);
      return {
        success: false,
        targetPhone: to,
        message,
        provider: 'none',
        error: 'Invalid phone number'
      };
    }

    console.log(`📨 [SMS-DISPATCHER] [${context}] Dispatching to ${targetPhone} (${message.length} chars):\n"${message}"`);

    const apiUrl = config.openSms.apiUrl || config.smsGateway.url || 'https://opensms.wansaw.com/v1/sms/send';
    const apiKey = config.openSms.apiKey || config.smsGateway.apiKey;
    const resolvedSenderId = senderId || config.smsGateway.senderId || 'COOLTC';

    if (apiUrl && apiKey) {
      try {
        const headers: Record<string, string> = {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${apiKey}`,
          'x-api-key': apiKey
        };

        const payload = {
          recipient: targetPhone,
          message,
          // Compatibility with multi-recipient & generic SMS gateway payloads
          phoneNumbers: [targetPhone],
          to: targetPhone,
          phone: targetPhone,
          text: message,
          senderId: resolvedSenderId
        };

        const response = await fetch(apiUrl, {
          method: 'POST',
          headers,
          body: JSON.stringify(payload)
        });

        const resData: any = await response.json().catch(() => ({}));

        if (response.ok) {
          const messageId = resData?.id || resData?.messageId || `sms_${Date.now()}`;
          console.log(`✅ [SMS-SENT] Successfully dispatched SMS to ${targetPhone} via OpenSMS Gateway (ID: ${messageId})`);
          return {
            success: true,
            targetPhone,
            message,
            provider: 'opensms-gateway',
            messageId,
            details: `SMS dispatched via OpenSMS Gateway (ID: ${messageId})`
          };
        } else {
          console.warn(`⚠️ [SMS-GATEWAY-WARN] OpenSMS Gateway returned HTTP ${response.status}:`, resData);
          return {
            success: false,
            targetPhone,
            message,
            provider: 'opensms-gateway',
            error: `HTTP ${response.status}: ${resData?.error || resData?.message || 'Gateway rejected message'}`
          };
        }
      } catch (err: any) {
        console.error(`❌ [SMS-GATEWAY-ERROR] Failed to connect to SMS Gateway: ${err.message}`);
        return {
          success: false,
          targetPhone,
          message,
          provider: 'opensms-gateway',
          error: err.message
        };
      }
    }

    // Default simulator logger if no API credentials configured
    console.log(`📲 [SMS-SIMULATOR] Dispatched SMS to ${targetPhone}:\n"${message}"`);
    return {
      success: true,
      targetPhone,
      message,
      provider: 'opensms-simulator',
      messageId: `sim_${Date.now()}`,
      details: 'SMS simulated successfully'
    };
  }

  /**
   * Dispatches Booking Created SMS to customer
   */
  async sendBookingCreatedSms(params: BookingCreatedSmsParams): Promise<SendSmsResult> {
    const {
      customerPhone,
      referenceNumber,
      scheduledDate,
      timeSlot
    } = params;

    const ref = referenceNumber;
    const dateStr = formatDateForSms(scheduledDate);
    const slotStr = timeSlot ? ` (${timeSlot})` : '';

    // Keep message under 100 characters for gateway compatibility
    let message = `Caring Cool Tech: AC Complaint Booking #${ref} created for ${dateStr}${slotStr}. Ph: 9677686561`;
    if (message.length > 100) {
      message = `CCT AC Service: Booking #${ref} created for ${dateStr}. Ph: 9677686561`;
    }
    if (message.length > 100) {
      const shortRef = ref.split('-').length > 2 ? `${ref.split('-')[0]}-${ref.split('-').slice(-1)[0]}` : ref;
      message = `CCT: Booking #${shortRef} created for ${dateStr}. Help: 9677686561`;
    }

    return this.sendSms({
      to: customerPhone,
      message,
      context: 'BOOKING_CREATED'
    });
  }

  /**
   * Dispatches Confirmed & Scheduled Booking SMS to customer with technician info
   */
  async sendBookingConfirmedSms(params: BookingConfirmedSmsParams): Promise<SendSmsResult> {
    const {
      customerPhone,
      bookingNumber,
      scheduledDate,
      timeSlot,
      technicianName
    } = params;

    const num = bookingNumber;
    const dateStr = formatDateForSms(scheduledDate);
    const techPart = technicianName ? ` Tech: ${technicianName.split(' ')[0]}.` : '';

    let message = `Caring Cool Tech: AC Complaint Booking #${num} confirmed for ${dateStr}.${techPart} Ph: 9677686561`;
    if (message.length > 100) {
      message = `CCT: Booking #${num} confirmed for ${dateStr}.${techPart} Ph: 9677686561`;
    }
    if (message.length > 100) {
      const shortNum = num.split('-').length > 2 ? `${num.split('-')[0]}-${num.split('-').slice(-1)[0]}` : num;
      message = `CCT: Booking #${shortNum} confirmed for ${dateStr}. Ph: 9677686561`;
    }

    return this.sendSms({
      to: customerPhone,
      message,
      context: 'BOOKING_CONFIRMED'
    });
  }
}

export const smsService = new SmsService();
