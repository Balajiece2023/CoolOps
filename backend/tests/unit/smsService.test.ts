import { smsService } from '../../src/services/smsService';

describe('SmsService Unit Tests', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    jest.restoreAllMocks();
  });

  it('normalizes 10-digit Indian mobile numbers to E.164 format', () => {
    expect(smsService.normalizePhoneNumber('9876543210')).toBe('+919876543210');
    expect(smsService.normalizePhoneNumber(' 98765 43210 ')).toBe('+919876543210');
    expect(smsService.normalizePhoneNumber('919876543210')).toBe('+919876543210');
    expect(smsService.normalizePhoneNumber('+919876543210')).toBe('+919876543210');
  });

  it('formats booking created SMS message under 100 characters', async () => {
    const sendSpy = jest.spyOn(smsService, 'sendSms').mockResolvedValueOnce({
      success: true,
      targetPhone: '+919876543210',
      message: 'test',
      provider: 'mock'
    });

    await smsService.sendBookingCreatedSms({
      customerName: 'Karthik',
      customerPhone: '9876543210',
      referenceNumber: 'TKT-20261113-0001',
      scheduledDate: '2026-11-14',
      timeSlot: '09:00-11:00'
    });

    expect(sendSpy).toHaveBeenCalledTimes(1);
    const sentParams = sendSpy.mock.calls[0][0];
    expect(sentParams.to).toBe('9876543210');
    expect(sentParams.message.length).toBeLessThanOrEqual(100);
    expect(sentParams.message).toContain('TKT-20261113-0001');
    expect(sentParams.message).toContain('9677686561');
  });

  it('formats booking confirmed SMS message under 100 characters', async () => {
    const sendSpy = jest.spyOn(smsService, 'sendSms').mockResolvedValueOnce({
      success: true,
      targetPhone: '+919876543210',
      message: 'test',
      provider: 'mock'
    });

    await smsService.sendBookingConfirmedSms({
      customerName: 'Karthik',
      customerPhone: '9876543210',
      bookingNumber: 'BKG-20261113-0001',
      scheduledDate: '2026-11-14',
      timeSlot: '09:00-11:00',
      technicianName: 'Sivakumar'
    });

    expect(sendSpy).toHaveBeenCalledTimes(1);
    const sentParams = sendSpy.mock.calls[0][0];
    expect(sentParams.to).toBe('9876543210');
    expect(sentParams.message.length).toBeLessThanOrEqual(100);
    expect(sentParams.message).toContain('BKG-20261113-0001');
    expect(sentParams.message).toContain('Sivakumar');
  });
});
