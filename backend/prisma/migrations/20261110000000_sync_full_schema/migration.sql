-- CreateEnum
CREATE TYPE "TicketPriority" AS ENUM ('LOW', 'MEDIUM', 'HIGH', 'EMERGENCY');

-- AlterEnum
ALTER TYPE "RequestStatus" ADD VALUE 'ON_HOLD';

-- AlterEnum
ALTER TYPE "JobStatus" ADD VALUE 'OTP_PENDING';

-- AlterTable
ALTER TABLE "users" ADD COLUMN "avatarUrl" TEXT;

-- AlterTable
ALTER TABLE "technicians" ADD COLUMN "currentLatitude" DOUBLE PRECISION,
ADD COLUMN "currentLongitude" DOUBLE PRECISION,
ADD COLUMN "isOnline" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN "lastLocationAt" TIMESTAMP(3);

-- AlterTable
ALTER TABLE "customer_addresses" ADD COLUMN "latitude" DOUBLE PRECISION,
ADD COLUMN "locationLink" TEXT,
ADD COLUMN "longitude" DOUBLE PRECISION;

-- AlterTable
ALTER TABLE "booking_requests" ADD COLUMN "createdByStaffId" TEXT,
ADD COLUMN "holdReason" TEXT,
ADD COLUMN "isDeleted" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN "isStaffCreated" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN "latitude" DOUBLE PRECISION,
ADD COLUMN "locationLink" TEXT,
ADD COLUMN "longitude" DOUBLE PRECISION,
ADD COLUMN "priority" "TicketPriority" NOT NULL DEFAULT 'MEDIUM';

-- AlterTable
ALTER TABLE "service_jobs" ADD COLUMN "alternateOtpPhone" TEXT,
ADD COLUMN "closureOtp" TEXT,
ADD COLUMN "closureOtpExpiresAt" TIMESTAMP(3),
ADD COLUMN "isOtpVerified" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN "otpAttempts" INTEGER NOT NULL DEFAULT 0;

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
CREATE INDEX "booking_requests_isDeleted_idx" ON "booking_requests"("isDeleted");

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
ALTER TABLE "technician_attendances" ADD CONSTRAINT "technician_attendances_technicianId_fkey" FOREIGN KEY ("technicianId") REFERENCES "technicians"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "technician_location_logs" ADD CONSTRAINT "technician_location_logs_technicianId_fkey" FOREIGN KEY ("technicianId") REFERENCES "technicians"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "field_service_reports" ADD CONSTRAINT "field_service_reports_serviceJobId_fkey" FOREIGN KEY ("serviceJobId") REFERENCES "service_jobs"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "field_service_reports" ADD CONSTRAINT "field_service_reports_technicianId_fkey" FOREIGN KEY ("technicianId") REFERENCES "technicians"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "field_service_reports" ADD CONSTRAINT "field_service_reports_createdById_fkey" FOREIGN KEY ("createdById") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

