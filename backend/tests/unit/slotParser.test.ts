import { BookingApprovalService } from '../../src/services/bookingApprovalService';

describe('BookingApprovalService Date Slot Parser', () => {
  it('correctly parses morning slot into UTC start and end Date', () => {
    const { start, end } = BookingApprovalService.parseSlotDateRange('2026-10-17', '09:00-11:00');
    expect(start.toISOString()).toBe('2026-10-17T09:00:00.000Z');
    expect(end.toISOString()).toBe('2026-10-17T11:00:00.000Z');
    expect(end.getTime()).toBeGreaterThan(start.getTime());
  });

  it('correctly detects slot duration of 2 hours', () => {
    const { start, end } = BookingApprovalService.parseSlotDateRange('2026-10-17', '14:00-16:00');
    const diffHours = (end.getTime() - start.getTime()) / (1000 * 60 * 60);
    expect(diffHours).toBe(2);
  });
});
