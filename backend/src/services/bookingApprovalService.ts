import { prisma } from '../prisma';
import { BookingStatus, RequestStatus, AssignmentStatus, JobStatus } from '@prisma/client';
import { queueOutboxEvent } from './outboxService';
import { createAuditLog } from './auditService';
import { metaWhatsAppClient } from './metaWhatsAppClient';

export interface ApproveBookingInput {
  bookingRequestId: string;
  technicianId: string;
  scheduledDate: string; // YYYY-MM-DD
  timeSlot: string;      // "09:00-11:00"
  estimatedAmount?: number;
  adminUserId: string;
  notes?: string;
  overrideAreaRestriction?: boolean;
}

export interface ProposeAlternativeSlotInput {
  bookingRequestId: string;
  proposedDate: string;  // YYYY-MM-DD
  proposedTimeSlot: string;
  adminUserId: string;
  reason?: string;
}

export interface RejectBookingInput {
  bookingRequestId: string;
  rejectionReason: string;
  adminUserId: string;
}

export class BookingApprovalService {
  /**
   * Helper to parse "09:00-11:00" into start and end UTC Date objects for a given date string
   */
  static parseSlotDateRange(dateStr: string, slotStr: string): { start: Date; end: Date } {
    const [startH, endH] = slotStr.split('-');
    const [sHours, sMins] = startH.split(':').map(Number);
    const [eHours, eMins] = endH.split(':').map(Number);

    const start = new Date(dateStr);
    start.setUTCHours(sHours, sMins, 0, 0);

    const end = new Date(dateStr);
    end.setUTCHours(eHours, eMins, 0, 0);

    return { start, end };
  }

  /**
   * Approves a booking request, validates technician constraints inside a transaction,
   * creates Confirmed Booking, Technician Assignment, and Service Job.
   */
  async approveBookingRequest(input: ApproveBookingInput) {
    const { start, end } = BookingApprovalService.parseSlotDateRange(input.scheduledDate, input.timeSlot);

    return await prisma.$transaction(async (tx) => {
      // 1. Fetch Booking Request
      const request = await tx.bookingRequest.findUnique({
        where: { id: input.bookingRequestId },
        include: { customer: true, address: true, serviceType: true }
      });

      if (!request) {
        throw new Error('Booking request not found');
      }

      if (request.status !== RequestStatus.PENDING_APPROVAL && request.status !== RequestStatus.ALTERNATIVE_PROPOSED) {
        throw new Error(`Cannot approve request with current status: ${request.status}`);
      }

      // 2. Fetch Technician and validate constraints
      const tech = await tx.technician.findUnique({
        where: { id: input.technicianId },
        include: { user: true }
      });

      if (!tech || !tech.isAvailable || !tech.user.isActive) {
        throw new Error('Technician is not available or inactive');
      }

      // Check service area match if configured
      if (tech.serviceAreas.length > 0 && request.address?.area && !input.overrideAreaRestriction) {
        const areaMatched = tech.serviceAreas.some(area =>
          request.address.area.toLowerCase().includes(area.toLowerCase()) ||
          area.toLowerCase().includes(request.address.area.toLowerCase())
        );
        if (!areaMatched) {
          throw new Error(`Technician does not service customer area: ${request.address.area}. Serviced areas: ${tech.serviceAreas.join(', ')}`);
        }
      }

      // 3. Concurrency check: Ensure NO overlapping active assignments for this technician
      const overlappingAssignment = await tx.technicianAssignment.findFirst({
        where: {
          technicianId: tech.id,
          status: { in: [AssignmentStatus.ASSIGNED, AssignmentStatus.ACCEPTED] },
          OR: [
            {
              // starts before slot end and ends after slot start
              assignedSlotStart: { lt: end },
              assignedSlotEnd: { gt: start }
            }
          ]
        }
      });

      if (overlappingAssignment) {
        throw new Error(`Technician ${tech.user.name} already has an active assignment in time range ${input.scheduledDate} ${input.timeSlot}`);
      }

      // 4. Check technician daily max jobs quota
      const startOfDay = new Date(input.scheduledDate);
      startOfDay.setUTCHours(0, 0, 0, 0);
      const endOfDay = new Date(input.scheduledDate);
      endOfDay.setUTCHours(23, 59, 59, 999);

      const dailyJobsCount = await tx.technicianAssignment.count({
        where: {
          technicianId: tech.id,
          status: { in: [AssignmentStatus.ASSIGNED, AssignmentStatus.ACCEPTED] },
          assignedSlotStart: { gte: startOfDay, lte: endOfDay }
        }
      });

      if (dailyJobsCount >= tech.maxDailyJobs) {
        throw new Error(`Technician has reached maximum capacity of ${tech.maxDailyJobs} jobs for ${input.scheduledDate}`);
      }

      // 5. Update Booking Request to APPROVED
      await tx.bookingRequest.update({
        where: { id: request.id },
        data: { status: RequestStatus.APPROVED }
      });

      // 6. Create Confirmed Booking
      const bookingCount = await tx.booking.count();
      const datePart = input.scheduledDate.replace(/-/g, '');
      const bookingNumber = `BKG-${datePart}-${String(bookingCount + 1).padStart(4, '0')}`;

      const booking = await tx.booking.create({
        data: {
          bookingNumber,
          bookingRequestId: request.id,
          customerId: request.customerId,
          addressId: request.addressId,
          serviceTypeId: request.serviceTypeId,
          scheduledDate: new Date(input.scheduledDate),
          timeSlot: input.timeSlot,
          status: BookingStatus.CONFIRMED,
          totalEstimate: input.estimatedAmount || request.serviceType.basePrice,
          notes: input.notes
        }
      });

      // 7. Create Technician Assignment
      const assignment = await tx.technicianAssignment.create({
        data: {
          bookingId: booking.id,
          technicianId: tech.id,
          assignedSlotStart: start,
          assignedSlotEnd: end,
          status: AssignmentStatus.ASSIGNED,
          assignedByUserId: input.adminUserId
        }
      });

      // 8. Create Service Job
      const jobCount = await tx.serviceJob.count();
      const jobNumber = `JOB-${datePart}-${String(jobCount + 1).padStart(4, '0')}`;

      const job = await tx.serviceJob.create({
        data: {
          jobNumber,
          bookingId: booking.id,
          technicianId: tech.id,
          acUnitId: request.acUnitId,
          status: JobStatus.PENDING
        }
      });

      // 9. Pre-populate standard checklist items
      const standardTasks = [
        'Inspect AC Filters and clean dust/debris',
        'Check cooling coil and evaporator cleanliness',
        'Verify refrigerant / gas operating pressure',
        'Inspect indoor/outdoor electrical connections and amperage',
        'Test condensation drain pipe for water flow/choking',
        'Final cooling temperature and remote control check'
      ];

      for (const task of standardTasks) {
        await tx.jobChecklistItem.create({
          data: {
            jobId: job.id,
            taskName: task,
            isChecked: false
          }
        });
      }

      // 10. Queue WhatsApp Confirmation message to Customer via Outbox
      const notifyMessage = request.customer.language === 'ta'
        ? `🎉 *உங்கள் AC முன்பதிவு உறுதி செய்யப்பட்டது!*\n\n` +
          `• முன்பதிவு எண்: *${booking.bookingNumber}*\n` +
          `• சேவை: ${request.serviceType.nameTa}\n` +
          `• தேதி & நேரம்: ${input.scheduledDate} (${input.timeSlot})\n` +
          `• தொழில்நுட்ப வல்லுநர்: ${tech.user.name} (${tech.user.phone || 'FrostPro'})\n\n` +
          `தொழில்நுட்ப வல்லுநர் வரும் முன் உங்களைத் தொடர்புகொள்வார். நன்றி!`
        : `🎉 *Your AC Service Booking is Confirmed!*\n\n` +
          `• Booking ID: *${booking.bookingNumber}*\n` +
          `• Service: ${request.serviceType.nameEn}\n` +
          `• Slot: ${input.scheduledDate} (${input.timeSlot})\n` +
          `• Technician: ${tech.user.name} (${tech.user.phone || 'FrostPro Team'})\n\n` +
          `Our technician will call you before arriving. Thank you for choosing FrostPro!`;

      await queueOutboxEvent('WHATSAPP_SEND_MESSAGE', {
        to: request.customer.phone,
        body: notifyMessage
      }, tx);

      // Audit Log
      await createAuditLog({
        userId: input.adminUserId,
        action: 'APPROVE_AND_SCHEDULE_BOOKING',
        entityType: 'BookingRequest',
        entityId: request.id,
        newValues: { bookingId: booking.id, assignmentId: assignment.id, jobId: job.id, techId: tech.id }
      });

      return { booking, assignment, job };
    });
  }

  /**
   * Proposes an alternative slot if requested slot cannot be accommodated
   */
  async proposeAlternativeSlot(input: ProposeAlternativeSlotInput) {
    const updated = await prisma.bookingRequest.update({
      where: { id: input.bookingRequestId },
      data: {
        status: RequestStatus.ALTERNATIVE_PROPOSED,
        proposedDate: new Date(input.proposedDate),
        proposedTimeSlot: input.proposedTimeSlot,
        customerAcceptedProposed: null,
        rejectionReason: input.reason
      },
      include: { customer: true }
    });

    const notify = updated.customer.language === 'ta'
      ? `📅 *மாற்று நேர பரிந்துரை (FrostPro AC Services)*\n\n` +
        `மன்னிக்கவும், நீங்கள் கோரிய நேரம் கிடைக்கவில்லை. மாற்று நேரமாக *${input.proposedDate} (${input.proposedTimeSlot})* பரிந்துரைக்கிறோம்.\n\n` +
        `ஏற்றுக்கொள்ள 1 அல்லது ACCEPT என பதிலளிக்கவும்.\nரத்து செய்ய CANCEL என பதிலளிக்கவும்.`
      : `📅 *Alternative Slot Proposed (FrostPro AC Services)*\n\n` +
        `We could not accommodate your requested slot. We propose: *${input.proposedDate} (${input.proposedTimeSlot})*.\n\n` +
        `Reply 1 or ACCEPT to accept this slot.\nReply CANCEL to cancel.`;

    await queueOutboxEvent('WHATSAPP_SEND_MESSAGE', {
      to: updated.customer.phone,
      body: notify
    });

    await createAuditLog({
      userId: input.adminUserId,
      action: 'PROPOSE_ALTERNATIVE_SLOT',
      entityType: 'BookingRequest',
      entityId: input.bookingRequestId,
      newValues: { proposedDate: input.proposedDate, proposedSlot: input.proposedTimeSlot }
    });

    return updated;
  }

  /**
   * Rejects a booking request with explanation
   */
  async rejectBookingRequest(input: RejectBookingInput) {
    const updated = await prisma.bookingRequest.update({
      where: { id: input.bookingRequestId },
      data: {
        status: RequestStatus.REJECTED,
        rejectionReason: input.rejectionReason
      },
      include: { customer: true }
    });

    const notify = updated.customer.language === 'ta'
      ? `❌ உங்கள் AC முன்பதிவு கோரிக்கை எண் ${updated.referenceNumber} நிராகரிக்கப்பட்டது.\nகாரணம்: ${input.rejectionReason}\nவேறு சேவைக்கு அழைக்கவும்: +91 98400 12345.`
      : `❌ Your AC service request ${updated.referenceNumber} could not be accepted.\nReason: ${input.rejectionReason}\nPlease contact us at +91 98400 12345 for assistance.`;

    await queueOutboxEvent('WHATSAPP_SEND_MESSAGE', {
      to: updated.customer.phone,
      body: notify
    });

    await createAuditLog({
      userId: input.adminUserId,
      action: 'REJECT_BOOKING_REQUEST',
      entityType: 'BookingRequest',
      entityId: input.bookingRequestId,
      newValues: { reason: input.rejectionReason }
    });

    return updated;
  }
}

export const bookingApprovalService = new BookingApprovalService();
