import { prisma } from '../prisma';
import { JobStatus, StockMovementType, InvoiceStatus, PaymentMethod } from '@prisma/client';
import { createAuditLog } from './auditService';

export class ServiceJobWorkflowService {
  /**
   * Updates Job Status (EN_ROUTE, ARRIVED, IN_PROGRESS, COMPLETED)
   */
  async updateStatus(jobId: string, technicianId: string, newStatus: JobStatus, diagnosis?: string, resolutionNotes?: string) {
    const job = await prisma.serviceJob.findUnique({
      where: { id: jobId },
      include: { technician: true }
    });

    if (!job) throw new Error('Job not found');
    if (job.technicianId !== technicianId) {
      throw new Error('Technician unauthorized to update this job');
    }

    // Guard: Prevent completing job directly without OTP verification!
    if (newStatus === JobStatus.COMPLETED && !job.isOtpVerified) {
      throw new Error('Customer OTP verification is mandatory before completing and closing this ticket.');
    }

    const updateData: any = { status: newStatus };
    const now = new Date();

    if (newStatus === JobStatus.EN_ROUTE && !job.enRouteAt) updateData.enRouteAt = now;
    if (newStatus === JobStatus.ARRIVED && !job.arrivedAt) updateData.arrivedAt = now;
    if (newStatus === JobStatus.IN_PROGRESS && !job.startedAt) updateData.startedAt = now;
    if (newStatus === JobStatus.COMPLETED) {
      updateData.completedAt = now;
      if (diagnosis) updateData.diagnosis = diagnosis;
      if (resolutionNotes) updateData.resolutionNotes = resolutionNotes;
    }

    const updated = await prisma.serviceJob.update({
      where: { id: jobId },
      data: updateData
    });

    await createAuditLog({
      action: 'UPDATE_JOB_STATUS',
      entityType: 'ServiceJob',
      entityId: jobId,
      oldValues: { status: job.status },
      newValues: { status: newStatus }
    });

    return updated;
  }

  /**
   * Generates a 6-digit closure OTP, saves it on the job, and queues WhatsApp/SMS notification to customer
   */
  async requestClosureOtp(jobId: string, technicianId: string, alternatePhone?: string) {
    const job = await prisma.serviceJob.findUnique({
      where: { id: jobId },
      include: {
        technician: { include: { user: true } },
        booking: { include: { customer: true, serviceType: true } }
      }
    });

    if (!job) throw new Error('Job not found');
    if (job.technicianId !== technicianId) {
      throw new Error('Technician unauthorized to request OTP for this job');
    }

    if (job.status === JobStatus.COMPLETED) {
      throw new Error('Job is already completed and closed.');
    }

    // Generate random 6-digit OTP
    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    const expiresAt = new Date(Date.now() + 15 * 60 * 1000); // 15 mins validity
    const targetPhone = alternatePhone?.trim() ? alternatePhone.trim() : job.booking.customer.phone;

    const updatedJob = await prisma.serviceJob.update({
      where: { id: jobId },
      data: {
        closureOtp: otp,
        closureOtpExpiresAt: expiresAt,
        alternateOtpPhone: alternatePhone?.trim() || null,
        status: JobStatus.OTP_PENDING,
        otpAttempts: 0
      }
    });

    // Queue outbound message to customer via Outbox
    const customer = job.booking.customer;
    const msg = `Dear ${customer.name}, technician ${job.technician.user.name} has completed the service for ticket ${job.jobNumber}. If you are satisfied with the service, please share this closure OTP with the technician: *${otp}* (valid for 15 mins).`;

    const { queueOutboxEvent } = await import('./outboxService');
    await queueOutboxEvent('TICKET_CLOSURE_OTP', {
      recipientPhone: targetPhone,
      messageBody: msg,
      jobId,
      otp,
      jobNumber: job.jobNumber
    });

    await createAuditLog({
      action: 'REQUEST_CLOSURE_OTP',
      entityType: 'ServiceJob',
      entityId: jobId,
      newValues: { expiresAt }
    });

    return {
      success: true,
      jobNumber: job.jobNumber,
      status: JobStatus.OTP_PENDING,
      expiresAt,
      // We expose otp in response for simulator/demo testing environments if needed
      demoOtp: process.env.NODE_ENV !== 'production' ? otp : undefined
    };
  }

  /**
   * Verifies the customer OTP entered by technician to officially close the ticket
   */
  async verifyClosureOtpAndClose(jobId: string, technicianId: string, enteredOtp: string, diagnosis?: string, resolutionNotes?: string) {
    const job = await prisma.serviceJob.findUnique({
      where: { id: jobId },
      include: {
        booking: { include: { customer: true, serviceType: true } }
      }
    });

    if (!job) throw new Error('Job not found');
    if (job.technicianId !== technicianId) {
      throw new Error('Technician unauthorized for this job');
    }

    if (job.status === JobStatus.COMPLETED) {
      throw new Error('Job is already completed');
    }

    if (!job.closureOtp || !job.closureOtpExpiresAt) {
      throw new Error('No active OTP found. Please request an OTP first.');
    }

    if (new Date() > new Date(job.closureOtpExpiresAt)) {
      throw new Error('OTP has expired. Please request a new OTP.');
    }

    if (job.otpAttempts >= 3) {
      throw new Error('Maximum OTP verification attempts exceeded. Please request a new OTP.');
    }

    if (job.closureOtp.trim() !== enteredOtp.trim()) {
      await prisma.serviceJob.update({
        where: { id: jobId },
        data: { otpAttempts: { increment: 1 } }
      });
      throw new Error('Invalid OTP. Please verify the code received by the customer.');
    }

    // OTP Verified! Complete and close the ticket atomically
    const now = new Date();
    const closedJob = await prisma.serviceJob.update({
      where: { id: jobId },
      data: {
        status: JobStatus.COMPLETED,
        isOtpVerified: true,
        completedAt: now,
        diagnosis: diagnosis || job.diagnosis,
        resolutionNotes: resolutionNotes || job.resolutionNotes,
        closureOtp: null // Clear OTP once consumed
      }
    });

    // Notify customer on successful closure
    const { queueOutboxEvent } = await import('./outboxService');
    const customer = job.booking.customer;
    await queueOutboxEvent('TICKET_CLOSED', {
      recipientPhone: customer.phone,
      messageBody: `Dear ${customer.name}, your service ticket ${job.jobNumber} has been verified and closed successfully. Thank you for choosing FrostPro!`,
      jobId,
      jobNumber: job.jobNumber
    });

    await createAuditLog({
      action: 'VERIFY_OTP_AND_CLOSE_TICKET',
      entityType: 'ServiceJob',
      entityId: jobId,
      newValues: { status: JobStatus.COMPLETED, isOtpVerified: true }
    });

    return closedJob;
  }

  /**
   * Consumes an inventory spare part for a job inside a transaction:
   * updates inventory_parts, records job_parts_consumed, and logs stock_movements
   */
  async consumePart(jobId: string, partId: string, quantity: number) {
    return await prisma.$transaction(async (tx) => {
      const part = await tx.inventoryPart.findUnique({ where: { id: partId } });
      if (!part) throw new Error('Inventory part not found');
      if (part.currentStock < quantity) {
        throw new Error(`Insufficient stock for ${part.name}. Available: ${part.currentStock}, Requested: ${quantity}`);
      }

      const newStock = part.currentStock - quantity;

      // 1. Decrement part stock
      await tx.inventoryPart.update({
        where: { id: partId },
        data: { currentStock: newStock }
      });

      // 2. Record stock movement
      await tx.stockMovement.create({
        data: {
          partId,
          type: StockMovementType.OUTWARD_JOB,
          quantity: -quantity,
          balanceAfter: newStock,
          reference: jobId,
          notes: `Consumed for job ${jobId}`
        }
      });

      // 3. Record part consumed in job
      const consumed = await tx.jobPartConsumed.create({
        data: {
          jobId,
          partId,
          quantity,
          unitPrice: part.sellingPrice
        }
      });

      return { consumed, currentStock: newStock };
    });
  }

  /**
   * Generates Invoice from Completed Job & its consumed parts
   */
  async generateJobInvoice(jobId: string, createdById: string, discount = 0, taxRate = 18.0) {
    return await prisma.$transaction(async (tx) => {
      const job = await tx.serviceJob.findUnique({
        where: { id: jobId },
        include: {
          booking: { include: { customer: true, serviceType: true } },
          partsConsumed: { include: { part: true } }
        }
      });

      if (!job) throw new Error('Job not found');

      // Calculate totals
      let subtotal = job.booking.serviceType.basePrice;
      const itemsData: any[] = [
        {
          description: `${job.booking.serviceType.nameEn} (Labor & Service)`,
          quantity: 1,
          unitPrice: job.booking.serviceType.basePrice,
          totalPrice: job.booking.serviceType.basePrice
        }
      ];

      for (const p of job.partsConsumed) {
        const itemTotal = p.quantity * p.unitPrice;
        subtotal += itemTotal;
        itemsData.push({
          partId: p.partId,
          description: `${p.part.name} (Part/Refrigerant)`,
          quantity: p.quantity,
          unitPrice: p.unitPrice,
          totalPrice: itemTotal
        });
      }

      const taxableAmount = Math.max(0, subtotal - discount);
      const taxAmount = (taxableAmount * taxRate) / 100.0;
      const totalAmount = taxableAmount + taxAmount;

      const datePart = new Date().toISOString().split('T')[0].replace(/-/g, '');
      const invCount = await tx.invoice.count();
      const invoiceNumber = `INV-${datePart}-${String(invCount + 1).padStart(4, '0')}`;

      const dueDate = new Date();
      dueDate.setDate(dueDate.getDate() + 7);

      const invoice = await tx.invoice.create({
        data: {
          invoiceNumber,
          customerId: job.booking.customerId,
          serviceJobId: job.id,
          subtotal,
          discount,
          taxRate,
          taxAmount,
          totalAmount,
          paidAmount: 0,
          status: InvoiceStatus.ISSUED,
          dueDate,
          createdById,
          items: {
            create: itemsData
          }
        },
        include: { items: true, customer: true }
      });

      return invoice;
    });
  }

  /**
   * Records a payment against an invoice inside a transaction
   */
  async recordPayment(invoiceId: string, amount: number, method: PaymentMethod, referenceNumber: string | undefined, receivedById: string) {
    return await prisma.$transaction(async (tx) => {
      const invoice = await tx.invoice.findUnique({ where: { id: invoiceId } });
      if (!invoice) throw new Error('Invoice not found');

      const newPaidAmount = invoice.paidAmount + amount;
      const newStatus = newPaidAmount >= invoice.totalAmount ? InvoiceStatus.PAID : InvoiceStatus.PARTIALLY_PAID;

      const receiptCount = await tx.payment.count();
      const receiptNumber = `RCT-${Date.now().toString().slice(-6)}-${String(receiptCount + 1).padStart(4, '0')}`;

      const payment = await tx.payment.create({
        data: {
          receiptNumber,
          invoiceId,
          amount,
          paymentMethod: method,
          referenceNumber,
          receivedById
        }
      });

      const updatedInvoice = await tx.invoice.update({
        where: { id: invoiceId },
        data: {
          paidAmount: newPaidAmount,
          status: newStatus
        }
      });

      return { payment, invoice: updatedInvoice };
    });
  }
}

export const serviceJobWorkflowService = new ServiceJobWorkflowService();
