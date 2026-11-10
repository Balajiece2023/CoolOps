-- CreateEnum
CREATE TYPE "Role" AS ENUM ('ADMIN', 'BOOKING_STAFF', 'TECHNICIAN', 'ACCOUNTANT');

-- CreateEnum
CREATE TYPE "TicketPriority" AS ENUM ('LOW', 'MEDIUM', 'HIGH', 'EMERGENCY');

-- CreateEnum
CREATE TYPE "RequestStatus" AS ENUM ('PENDING_APPROVAL', 'APPROVED', 'REJECTED', 'ALTERNATIVE_PROPOSED', 'CANCELLED', 'ON_HOLD');

-- CreateEnum
CREATE TYPE "BookingStatus" AS ENUM ('CONFIRMED', 'CANCELLED', 'COMPLETED');

-- CreateEnum
CREATE TYPE "AssignmentStatus" AS ENUM ('ASSIGNED', 'ACCEPTED', 'DECLINED', 'CANCELLED');

-- CreateEnum
CREATE TYPE "JobStatus" AS ENUM ('PENDING', 'EN_ROUTE', 'ARRIVED', 'IN_PROGRESS', 'OTP_PENDING', 'COMPLETED', 'CANCELLED');

-- CreateEnum
CREATE TYPE "StockMovementType" AS ENUM ('INWARD', 'OUTWARD_JOB', 'ADJUSTMENT', 'RETURN');

-- CreateEnum
CREATE TYPE "InvoiceStatus" AS ENUM ('DRAFT', 'ISSUED', 'PARTIALLY_PAID', 'PAID', 'CANCELLED');

-- CreateEnum
CREATE TYPE "PaymentMethod" AS ENUM ('CASH', 'UPI', 'CARD', 'BANK_TRANSFER');

-- CreateEnum
CREATE TYPE "PaymentStatus" AS ENUM ('SUCCESS', 'FAILED', 'REFUNDED');

-- CreateEnum
CREATE TYPE "OutboxStatus" AS ENUM ('PENDING', 'PROCESSING', 'SENT', 'FAILED');

-- CreateTable
CREATE TABLE "users" (
    "id" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "passwordHash" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "role" "Role" NOT NULL,
    "phone" TEXT,
    "avatarUrl" TEXT,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "technicians" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "skills" TEXT[],
    "serviceAreas" TEXT[],
    "maxDailyJobs" INTEGER NOT NULL DEFAULT 4,
    "isAvailable" BOOLEAN NOT NULL DEFAULT true,
    "isOnline" BOOLEAN NOT NULL DEFAULT false,
    "currentLatitude" DOUBLE PRECISION,
    "currentLongitude" DOUBLE PRECISION,
    "lastLocationAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "technicians_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "customers" (
    "id" TEXT NOT NULL,
    "phone" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "email" TEXT,
    "language" TEXT NOT NULL DEFAULT 'en',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "customers_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "customer_addresses" (
    "id" TEXT NOT NULL,
    "customerId" TEXT NOT NULL,
    "addressLine" TEXT NOT NULL,
    "landmark" TEXT,
    "area" TEXT NOT NULL,
    "city" TEXT NOT NULL DEFAULT 'Chennai',
    "pincode" TEXT NOT NULL,
    "latitude" DOUBLE PRECISION,
    "longitude" DOUBLE PRECISION,
    "locationLink" TEXT,
    "isDefault" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "customer_addresses_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ac_units" (
    "id" TEXT NOT NULL,
    "customerId" TEXT NOT NULL,
    "addressId" TEXT,
    "brand" TEXT NOT NULL,
    "modelNumber" TEXT,
    "tonnage" DOUBLE PRECISION NOT NULL,
    "unitType" TEXT NOT NULL,
    "installationYear" INTEGER,
    "locationInHouse" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ac_units_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "service_types" (
    "id" TEXT NOT NULL,
    "code" TEXT NOT NULL,
    "nameEn" TEXT NOT NULL,
    "nameTa" TEXT NOT NULL,
    "description" TEXT,
    "basePrice" DOUBLE PRECISION NOT NULL,
    "estimatedMinutes" INTEGER NOT NULL DEFAULT 90,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "service_types_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "whatsapp_conversations" (
    "id" TEXT NOT NULL,
    "waPhone" TEXT NOT NULL,
    "customerName" TEXT,
    "language" TEXT NOT NULL DEFAULT 'en',
    "step" TEXT NOT NULL DEFAULT 'WELCOME',
    "sessionData" JSONB NOT NULL DEFAULT '{}',
    "lastInteractionAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "whatsapp_conversations_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "whatsapp_messages" (
    "id" TEXT NOT NULL,
    "conversationId" TEXT NOT NULL,
    "providerMessageId" TEXT,
    "direction" TEXT NOT NULL,
    "messageBody" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'SENT',
    "rawPayload" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "whatsapp_messages_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "booking_requests" (
    "id" TEXT NOT NULL,
    "referenceNumber" TEXT NOT NULL,
    "customerId" TEXT NOT NULL,
    "addressId" TEXT NOT NULL,
    "serviceTypeId" TEXT NOT NULL,
    "acUnitId" TEXT,
    "complaint" TEXT NOT NULL,
    "acTonnage" DOUBLE PRECISION,
    "acBrand" TEXT,
    "acType" TEXT,
    "priority" "TicketPriority" NOT NULL DEFAULT 'MEDIUM',
    "latitude" DOUBLE PRECISION,
    "longitude" DOUBLE PRECISION,
    "locationLink" TEXT,
    "isStaffCreated" BOOLEAN NOT NULL DEFAULT false,
    "createdByStaffId" TEXT,
    "preferredDate" TIMESTAMP(3) NOT NULL,
    "preferredTimeSlot" TEXT NOT NULL,
    "status" "RequestStatus" NOT NULL DEFAULT 'PENDING_APPROVAL',
    "isDeleted" BOOLEAN NOT NULL DEFAULT false,
    "rejectionReason" TEXT,
    "holdReason" TEXT,
    "proposedDate" TIMESTAMP(3),
    "proposedTimeSlot" TEXT,
    "customerAcceptedProposed" BOOLEAN,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "booking_requests_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "bookings" (
    "id" TEXT NOT NULL,
    "bookingNumber" TEXT NOT NULL,
    "bookingRequestId" TEXT,
    "customerId" TEXT NOT NULL,
    "addressId" TEXT NOT NULL,
    "serviceTypeId" TEXT NOT NULL,
    "scheduledDate" TIMESTAMP(3) NOT NULL,
    "timeSlot" TEXT NOT NULL,
    "status" "BookingStatus" NOT NULL DEFAULT 'CONFIRMED',
    "totalEstimate" DOUBLE PRECISION NOT NULL,
    "notes" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "bookings_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "technician_assignments" (
    "id" TEXT NOT NULL,
    "bookingId" TEXT NOT NULL,
    "technicianId" TEXT NOT NULL,
    "assignedSlotStart" TIMESTAMP(3) NOT NULL,
    "assignedSlotEnd" TIMESTAMP(3) NOT NULL,
    "status" "AssignmentStatus" NOT NULL DEFAULT 'ASSIGNED',
    "assignedByUserId" TEXT NOT NULL,
    "assignedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "technician_assignments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "service_jobs" (
    "id" TEXT NOT NULL,
    "jobNumber" TEXT NOT NULL,
    "bookingId" TEXT NOT NULL,
    "technicianId" TEXT NOT NULL,
    "acUnitId" TEXT,
    "status" "JobStatus" NOT NULL DEFAULT 'PENDING',
    "diagnosis" TEXT,
    "resolutionNotes" TEXT,
    "closureOtp" TEXT,
    "closureOtpExpiresAt" TIMESTAMP(3),
    "alternateOtpPhone" TEXT,
    "isOtpVerified" BOOLEAN NOT NULL DEFAULT false,
    "otpAttempts" INTEGER NOT NULL DEFAULT 0,
    "startedAt" TIMESTAMP(3),
    "enRouteAt" TIMESTAMP(3),
    "arrivedAt" TIMESTAMP(3),
    "completedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "service_jobs_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "job_checklist_items" (
    "id" TEXT NOT NULL,
    "jobId" TEXT NOT NULL,
    "taskName" TEXT NOT NULL,
    "isChecked" BOOLEAN NOT NULL DEFAULT false,
    "notes" TEXT,
    "completedAt" TIMESTAMP(3),

    CONSTRAINT "job_checklist_items_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "job_attachments" (
    "id" TEXT NOT NULL,
    "jobId" TEXT NOT NULL,
    "attachmentType" TEXT NOT NULL,
    "fileUrl" TEXT NOT NULL,
    "caption" TEXT,
    "uploadedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "job_attachments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "inventory_parts" (
    "id" TEXT NOT NULL,
    "sku" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "category" TEXT NOT NULL,
    "unitPrice" DOUBLE PRECISION NOT NULL,
    "sellingPrice" DOUBLE PRECISION NOT NULL,
    "currentStock" INTEGER NOT NULL DEFAULT 0,
    "minStockAlertLevel" INTEGER NOT NULL DEFAULT 5,
    "supplierName" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "inventory_parts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "job_parts_consumed" (
    "id" TEXT NOT NULL,
    "jobId" TEXT NOT NULL,
    "partId" TEXT NOT NULL,
    "quantity" INTEGER NOT NULL DEFAULT 1,
    "unitPrice" DOUBLE PRECISION NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "job_parts_consumed_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "stock_movements" (
    "id" TEXT NOT NULL,
    "partId" TEXT NOT NULL,
    "type" "StockMovementType" NOT NULL,
    "quantity" INTEGER NOT NULL,
    "balanceAfter" INTEGER NOT NULL,
    "reference" TEXT,
    "notes" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "stock_movements_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "invoices" (
    "id" TEXT NOT NULL,
    "invoiceNumber" TEXT NOT NULL,
    "customerId" TEXT NOT NULL,
    "serviceJobId" TEXT,
    "subtotal" DOUBLE PRECISION NOT NULL,
    "discount" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "taxRate" DOUBLE PRECISION NOT NULL DEFAULT 18.0,
    "taxAmount" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "totalAmount" DOUBLE PRECISION NOT NULL,
    "paidAmount" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "status" "InvoiceStatus" NOT NULL DEFAULT 'ISSUED',
    "dueDate" TIMESTAMP(3) NOT NULL,
    "createdById" TEXT NOT NULL,
    "notes" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "invoices_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "invoice_items" (
    "id" TEXT NOT NULL,
    "invoiceId" TEXT NOT NULL,
    "partId" TEXT,
    "description" TEXT NOT NULL,
    "quantity" INTEGER NOT NULL DEFAULT 1,
    "unitPrice" DOUBLE PRECISION NOT NULL,
    "totalPrice" DOUBLE PRECISION NOT NULL,

    CONSTRAINT "invoice_items_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "payments" (
    "id" TEXT NOT NULL,
    "receiptNumber" TEXT NOT NULL,
    "invoiceId" TEXT NOT NULL,
    "amount" DOUBLE PRECISION NOT NULL,
    "paymentMethod" "PaymentMethod" NOT NULL,
    "referenceNumber" TEXT,
    "status" "PaymentStatus" NOT NULL DEFAULT 'SUCCESS',
    "notes" TEXT,
    "receivedById" TEXT NOT NULL,
    "paymentDate" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "payments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "expenses" (
    "id" TEXT NOT NULL,
    "category" TEXT NOT NULL,
    "amount" DOUBLE PRECISION NOT NULL,
    "description" TEXT NOT NULL,
    "expenseDate" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "recordedByUserId" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "expenses_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "notifications" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "body" TEXT NOT NULL,
    "isRead" BOOLEAN NOT NULL DEFAULT false,
    "linkUrl" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "notifications_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "outbox_events" (
    "id" TEXT NOT NULL,
    "eventType" TEXT NOT NULL,
    "payload" JSONB NOT NULL,
    "status" "OutboxStatus" NOT NULL DEFAULT 'PENDING',
    "retryCount" INTEGER NOT NULL DEFAULT 0,
    "maxRetries" INTEGER NOT NULL DEFAULT 3,
    "lastError" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "processedAt" TIMESTAMP(3),

    CONSTRAINT "outbox_events_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "audit_logs" (
    "id" TEXT NOT NULL,
    "userId" TEXT,
    "action" TEXT NOT NULL,
    "entityType" TEXT NOT NULL,
    "entityId" TEXT NOT NULL,
    "oldValues" JSONB,
    "newValues" JSONB,
    "ipAddress" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "audit_logs_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "technician_attendances" (
    "id" TEXT NOT NULL,
    "technicianId" TEXT NOT NULL,
    "date" TIMESTAMP(3) NOT NULL,
    "clockInAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "clockOutAt" TIMESTAMP(3),
    "clockInLatitude" DOUBLE PRECISION,
    "clockInLongitude" DOUBLE PRECISION,
    "clockOutLatitude" DOUBLE PRECISION,
    "clockOutLongitude" DOUBLE PRECISION,
    "totalMinutes" INTEGER DEFAULT 0,
    "notes" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "technician_attendances_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "technician_location_logs" (
    "id" TEXT NOT NULL,
    "technicianId" TEXT NOT NULL,
    "latitude" DOUBLE PRECISION NOT NULL,
    "longitude" DOUBLE PRECISION NOT NULL,
    "recordedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "technician_location_logs_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "field_service_reports" (
    "id" TEXT NOT NULL,
    "reportNumber" TEXT NOT NULL,
    "serviceJobId" TEXT,
    "technicianId" TEXT,
    "createdById" TEXT NOT NULL,
    "reportType" TEXT NOT NULL DEFAULT 'DO_AND_CHARGE_REPAIR',
    "customerName" TEXT NOT NULL,
    "customerAddress" TEXT NOT NULL,
    "contactPhone" TEXT,
    "personCalling" TEXT,
    "dealerName" TEXT NOT NULL DEFAULT 'CARING COOL TECH',
    "dealerAddress" TEXT NOT NULL DEFAULT 'Ground Floor No.1 Nethaji Nagar, Vallalarpet, Puducherry - 605 004',
    "dealerPhone" TEXT NOT NULL DEFAULT '96776 86561 / 99766 88166',
    "dealerEmail" TEXT NOT NULL DEFAULT 'caringcooltech@gmail.com',
    "serviceEngineerName" TEXT NOT NULL,
    "complaintDate" TIMESTAMP(3),
    "attendingDate" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "modelNumber" TEXT,
    "indoorSerialNo" TEXT,
    "outdoorSerialNo" TEXT,
    "errorCode" TEXT,
    "runningCurrent" TEXT,
    "suctionPressure" TEXT,
    "dischargePressure" TEXT,
    "roomTemperature" TEXT,
    "voltage" TEXT,
    "equip1Details" TEXT,
    "equip2Details" TEXT,
    "observations" TEXT NOT NULL,
    "suggestions" TEXT,
    "customerSignName" TEXT,
    "customerSignUrl" TEXT,
    "technicianSignName" TEXT,
    "technicianSignUrl" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "field_service_reports_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "users_email_key" ON "users"("email");

-- CreateIndex
CREATE UNIQUE INDEX "technicians_userId_key" ON "technicians"("userId");

-- CreateIndex
CREATE UNIQUE INDEX "customers_phone_key" ON "customers"("phone");

-- CreateIndex
CREATE UNIQUE INDEX "service_types_code_key" ON "service_types"("code");

-- CreateIndex
CREATE UNIQUE INDEX "whatsapp_conversations_waPhone_key" ON "whatsapp_conversations"("waPhone");

-- CreateIndex
CREATE UNIQUE INDEX "whatsapp_messages_providerMessageId_key" ON "whatsapp_messages"("providerMessageId");

-- CreateIndex
CREATE INDEX "whatsapp_messages_providerMessageId_idx" ON "whatsapp_messages"("providerMessageId");

-- CreateIndex
CREATE UNIQUE INDEX "booking_requests_referenceNumber_key" ON "booking_requests"("referenceNumber");

-- CreateIndex
CREATE INDEX "booking_requests_status_idx" ON "booking_requests"("status");

-- CreateIndex
CREATE INDEX "booking_requests_isDeleted_idx" ON "booking_requests"("isDeleted");

-- CreateIndex
CREATE UNIQUE INDEX "bookings_bookingNumber_key" ON "bookings"("bookingNumber");

-- CreateIndex
CREATE UNIQUE INDEX "bookings_bookingRequestId_key" ON "bookings"("bookingRequestId");

-- CreateIndex
CREATE INDEX "technician_assignments_technicianId_assignedSlotStart_assig_idx" ON "technician_assignments"("technicianId", "assignedSlotStart", "assignedSlotEnd");

-- CreateIndex
CREATE UNIQUE INDEX "service_jobs_jobNumber_key" ON "service_jobs"("jobNumber");

-- CreateIndex
CREATE UNIQUE INDEX "service_jobs_bookingId_key" ON "service_jobs"("bookingId");

-- CreateIndex
CREATE UNIQUE INDEX "inventory_parts_sku_key" ON "inventory_parts"("sku");

-- CreateIndex
CREATE UNIQUE INDEX "invoices_invoiceNumber_key" ON "invoices"("invoiceNumber");

-- CreateIndex
CREATE UNIQUE INDEX "payments_receiptNumber_key" ON "payments"("receiptNumber");

-- CreateIndex
CREATE INDEX "outbox_events_status_idx" ON "outbox_events"("status");

-- CreateIndex
CREATE INDEX "audit_logs_entityType_entityId_idx" ON "audit_logs"("entityType", "entityId");

-- CreateIndex
CREATE INDEX "technician_attendances_technicianId_date_idx" ON "technician_attendances"("technicianId", "date");

-- CreateIndex
CREATE INDEX "technician_attendances_date_idx" ON "technician_attendances"("date");

-- CreateIndex
CREATE INDEX "technician_location_logs_technicianId_recordedAt_idx" ON "technician_location_logs"("technicianId", "recordedAt");

-- CreateIndex
CREATE UNIQUE INDEX "field_service_reports_reportNumber_key" ON "field_service_reports"("reportNumber");

-- CreateIndex
CREATE INDEX "field_service_reports_customerName_idx" ON "field_service_reports"("customerName");

-- CreateIndex
CREATE INDEX "field_service_reports_attendingDate_idx" ON "field_service_reports"("attendingDate");

-- AddForeignKey
ALTER TABLE "technicians" ADD CONSTRAINT "technicians_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "customer_addresses" ADD CONSTRAINT "customer_addresses_customerId_fkey" FOREIGN KEY ("customerId") REFERENCES "customers"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ac_units" ADD CONSTRAINT "ac_units_customerId_fkey" FOREIGN KEY ("customerId") REFERENCES "customers"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ac_units" ADD CONSTRAINT "ac_units_addressId_fkey" FOREIGN KEY ("addressId") REFERENCES "customer_addresses"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "whatsapp_messages" ADD CONSTRAINT "whatsapp_messages_conversationId_fkey" FOREIGN KEY ("conversationId") REFERENCES "whatsapp_conversations"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "booking_requests" ADD CONSTRAINT "booking_requests_customerId_fkey" FOREIGN KEY ("customerId") REFERENCES "customers"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "booking_requests" ADD CONSTRAINT "booking_requests_addressId_fkey" FOREIGN KEY ("addressId") REFERENCES "customer_addresses"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "booking_requests" ADD CONSTRAINT "booking_requests_serviceTypeId_fkey" FOREIGN KEY ("serviceTypeId") REFERENCES "service_types"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "booking_requests" ADD CONSTRAINT "booking_requests_acUnitId_fkey" FOREIGN KEY ("acUnitId") REFERENCES "ac_units"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "bookings" ADD CONSTRAINT "bookings_bookingRequestId_fkey" FOREIGN KEY ("bookingRequestId") REFERENCES "booking_requests"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "bookings" ADD CONSTRAINT "bookings_customerId_fkey" FOREIGN KEY ("customerId") REFERENCES "customers"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "bookings" ADD CONSTRAINT "bookings_addressId_fkey" FOREIGN KEY ("addressId") REFERENCES "customer_addresses"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "bookings" ADD CONSTRAINT "bookings_serviceTypeId_fkey" FOREIGN KEY ("serviceTypeId") REFERENCES "service_types"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "technician_assignments" ADD CONSTRAINT "technician_assignments_bookingId_fkey" FOREIGN KEY ("bookingId") REFERENCES "bookings"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "technician_assignments" ADD CONSTRAINT "technician_assignments_technicianId_fkey" FOREIGN KEY ("technicianId") REFERENCES "technicians"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "service_jobs" ADD CONSTRAINT "service_jobs_bookingId_fkey" FOREIGN KEY ("bookingId") REFERENCES "bookings"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "service_jobs" ADD CONSTRAINT "service_jobs_technicianId_fkey" FOREIGN KEY ("technicianId") REFERENCES "technicians"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "service_jobs" ADD CONSTRAINT "service_jobs_acUnitId_fkey" FOREIGN KEY ("acUnitId") REFERENCES "ac_units"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "job_checklist_items" ADD CONSTRAINT "job_checklist_items_jobId_fkey" FOREIGN KEY ("jobId") REFERENCES "service_jobs"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "job_attachments" ADD CONSTRAINT "job_attachments_jobId_fkey" FOREIGN KEY ("jobId") REFERENCES "service_jobs"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "job_parts_consumed" ADD CONSTRAINT "job_parts_consumed_jobId_fkey" FOREIGN KEY ("jobId") REFERENCES "service_jobs"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "job_parts_consumed" ADD CONSTRAINT "job_parts_consumed_partId_fkey" FOREIGN KEY ("partId") REFERENCES "inventory_parts"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "stock_movements" ADD CONSTRAINT "stock_movements_partId_fkey" FOREIGN KEY ("partId") REFERENCES "inventory_parts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "invoices" ADD CONSTRAINT "invoices_customerId_fkey" FOREIGN KEY ("customerId") REFERENCES "customers"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "invoices" ADD CONSTRAINT "invoices_serviceJobId_fkey" FOREIGN KEY ("serviceJobId") REFERENCES "service_jobs"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "invoices" ADD CONSTRAINT "invoices_createdById_fkey" FOREIGN KEY ("createdById") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "invoice_items" ADD CONSTRAINT "invoice_items_invoiceId_fkey" FOREIGN KEY ("invoiceId") REFERENCES "invoices"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "invoice_items" ADD CONSTRAINT "invoice_items_partId_fkey" FOREIGN KEY ("partId") REFERENCES "inventory_parts"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "payments" ADD CONSTRAINT "payments_invoiceId_fkey" FOREIGN KEY ("invoiceId") REFERENCES "invoices"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "payments" ADD CONSTRAINT "payments_receivedById_fkey" FOREIGN KEY ("receivedById") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "audit_logs" ADD CONSTRAINT "audit_logs_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "technician_attendances" ADD CONSTRAINT "technician_attendances_technicianId_fkey" FOREIGN KEY ("technicianId") REFERENCES "technicians"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "technician_location_logs" ADD CONSTRAINT "technician_location_logs_technicianId_fkey" FOREIGN KEY ("technicianId") REFERENCES "technicians"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "field_service_reports" ADD CONSTRAINT "field_service_reports_serviceJobId_fkey" FOREIGN KEY ("serviceJobId") REFERENCES "service_jobs"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "field_service_reports" ADD CONSTRAINT "field_service_reports_technicianId_fkey" FOREIGN KEY ("technicianId") REFERENCES "technicians"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "field_service_reports" ADD CONSTRAINT "field_service_reports_createdById_fkey" FOREIGN KEY ("createdById") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

