import PDFDocument from 'pdfkit';
import { prisma } from '../prisma';
import { Response } from 'express';

export async function getTechnicianReportData(technicianId: string) {
  const tech = await prisma.technician.findUnique({
    where: { id: technicianId },
    include: {
      user: {
        select: { id: true, name: true, email: true, phone: true, isActive: true, createdAt: true }
      },
      attendances: {
        orderBy: [{ date: 'desc' }, { clockInAt: 'desc' }]
      },
      serviceJobs: {
        include: {
          booking: {
            include: { customer: true, address: true, serviceType: true }
          },
          acUnit: true,
          partsConsumed: { include: { part: true } }
        },
        orderBy: { createdAt: 'desc' }
      }
    }
  });

  if (!tech) {
    throw new Error('Technician not found');
  }

  // Calculate metrics
  const totalBookings = tech.serviceJobs.length;
  const completedJobs = tech.serviceJobs.filter((j) => j.status === 'COMPLETED').length;
  const ongoingJobs = tech.serviceJobs.filter((j) => ['EN_ROUTE', 'ARRIVED', 'IN_PROGRESS', 'OTP_PENDING'].includes(j.status)).length;
  const cancelledJobs = tech.serviceJobs.filter((j) => j.status === 'CANCELLED').length;

  let totalMinutesWorked = 0;
  for (const att of tech.attendances) {
    if (att.totalMinutes && att.totalMinutes > 0) {
      totalMinutesWorked += att.totalMinutes;
    } else if (att.clockInAt) {
      const end = att.clockOutAt || new Date();
      const diff = Math.max(0, Math.round((end.getTime() - att.clockInAt.getTime()) / (1000 * 60)));
      totalMinutesWorked += diff;
    }
  }

  const totalHoursWorked = Number((totalMinutesWorked / 60).toFixed(1));
  const completionRate = totalBookings > 0 ? Math.round((completedJobs / totalBookings) * 100) : 0;

  // Query actual revenue generated from invoices linked to this technician's jobs
  const jobIds = tech.serviceJobs.map((j) => j.id);
  const invoices = await prisma.invoice.findMany({
    where: { serviceJobId: { in: jobIds } }
  });

  let totalRevenueGenerated = 0;
  for (const inv of invoices) {
    totalRevenueGenerated += (inv.paidAmount || inv.totalAmount || 0);
  }

  const mappedSessions = tech.attendances.map((a) => {
    let mins = a.totalMinutes || 0;
    if (!mins && a.clockInAt) {
      const end = a.clockOutAt || new Date();
      mins = Math.max(0, Math.round((end.getTime() - a.clockInAt.getTime()) / (1000 * 60)));
    }
    return {
      id: a.id,
      date: a.date.toISOString().slice(0, 10),
      clockInAt: a.clockInAt,
      clockOutAt: a.clockOutAt,
      totalMinutes: mins,
      durationMinutes: mins,
      durationFormatted: mins ? `${Math.floor(mins / 60)}h ${mins % 60}m` : 'In Progress',
      notes: a.notes || 'Field Shift'
    };
  });

  const mappedJobs = tech.serviceJobs.map((j) => ({
    id: j.id,
    jobNumber: j.jobNumber,
    status: j.status,
    customerName: j.booking.customer.name,
    customerPhone: j.booking.customer.phone,
    serviceName: j.booking.serviceType.nameEn,
    address: `${j.booking.address.addressLine}, ${j.booking.address.area}`,
    scheduledDate: j.booking.scheduledDate,
    timeSlot: j.booking.timeSlot,
    completedAt: j.completedAt,
    diagnosis: j.diagnosis,
    resolutionNotes: j.resolutionNotes,
    partsConsumedCount: j.partsConsumed.length
  }));

  return {
    technician: {
      id: tech.id,
      name: tech.user.name,
      email: tech.user.email,
      phone: tech.user.phone || '',
      skills: tech.skills,
      serviceAreas: tech.serviceAreas,
      maxDailyJobs: tech.maxDailyJobs,
      isActive: tech.user.isActive,
      joinedAt: tech.user.createdAt
    },
    metrics: {
      totalBookings,
      totalJobsAssigned: totalBookings,
      completedJobs,
      ongoingJobs,
      cancelledJobs,
      completionRate: `${completionRate}%`,
      totalMinutesWorked,
      totalHoursWorked,
      totalTimesheetHours: totalHoursWorked,
      totalRevenueGenerated: Math.round(totalRevenueGenerated),
      totalShiftsCount: tech.attendances.length
    },
    timesheetSummary: {
      totalHours: totalHoursWorked,
      totalMinutes: totalMinutesWorked,
      sessionsCount: tech.attendances.length,
      sessions: mappedSessions
    },
    attendances: mappedSessions,
    recentJobs: mappedJobs,
    orderHistory: mappedJobs
  };
}

export async function generateTechnicianReportPdf(technicianId: string, res: Response) {
  const data = await getTechnicianReportData(technicianId);

  const doc = new PDFDocument({ margin: 40, size: 'A4' });

  const safeFileName = data.technician.name.replace(/\s+/g, '_');
  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader('Content-Disposition', `attachment; filename="Technician_Report_${safeFileName}.pdf"`);

  doc.pipe(res);

  // 1. Header
  doc.fontSize(20).fillColor('#1E75BB').text('CARING COOL TECH', 40, 40);
  doc.fontSize(10).fillColor('#64748B').text('GR FL NO.1 NETHAGI NAGAR VALARAMPET PUDUCHERRY-605 004', 40, 66);
  doc.text(`Phone: 9677686561 | Generated: ${new Date().toLocaleString('en-IN', { timeZone: 'Asia/Kolkata' })}`, 40, 78);

  doc.strokeColor('#CBD5E1').lineWidth(1).moveTo(40, 95).lineTo(555, 95).stroke();

  // 2. Title & Profile Box
  doc.fontSize(15).fillColor('#0F172A').text('FIELD TECHNICIAN PERFORMANCE & TIMESHEET DOSSIER', 40, 110);
  
  doc.rect(40, 130, 515, 65).fillAndStroke('#F8FAFC', '#E2E8F0');
  doc.fontSize(11).fillColor('#0F172A');
  doc.text(`Technician Name: ${data.technician.name}`, 52, 142);
  doc.text(`Contact: ${data.technician.phone} | Email: ${data.technician.email}`, 52, 158);
  doc.text(`Service Zones: ${data.technician.serviceAreas.join(', ')} | Skills: ${data.technician.skills.join(', ')}`, 52, 174);

  // 3. Key Operational Metrics Summary
  doc.fontSize(12).fillColor('#0284C7').text('Operational Summary & Performance KPIs', 40, 210);
  doc.strokeColor('#E2E8F0').lineWidth(0.5).moveTo(40, 226).lineTo(555, 226).stroke();

  const metricsY = 236;
  const colW = 125;
  const metrics = [
    { label: 'Total Assigned', val: `${data.metrics.totalBookings} Jobs` },
    { label: 'Completed Jobs', val: `${data.metrics.completedJobs} Jobs` },
    { label: 'Completion Rate', val: data.metrics.completionRate },
    { label: 'Total Hours Worked', val: `${data.metrics.totalHoursWorked} hrs` },
  ];

  metrics.forEach((m, idx) => {
    const x = 40 + idx * colW;
    doc.rect(x, metricsY, colW - 8, 44).fillAndStroke('#F1F5F9', '#CBD5E1');
    doc.fontSize(8).fillColor('#64748B').text(m.label, x + 8, metricsY + 8);
    doc.fontSize(13).fillColor('#0F172A').text(m.val, x + 8, metricsY + 22);
  });

  // 4. Timesheet Shift Intervals Table
  let currentY = 300;
  doc.fontSize(12).fillColor('#0284C7').text('Timesheet & Attendance Shift Logs', 40, currentY);
  currentY += 18;

  doc.rect(40, currentY, 515, 20).fill('#0F172A');
  doc.fontSize(8).fillColor('#FFFFFF');
  doc.text('Date', 46, currentY + 6);
  doc.text('Clock In', 120, currentY + 6);
  doc.text('Clock Out', 220, currentY + 6);
  doc.text('Duration', 330, currentY + 6);
  doc.text('Notes', 420, currentY + 6);
  currentY += 20;

  const attendanceSlice = data.attendances.slice(0, 8);
  if (attendanceSlice.length === 0) {
    doc.fontSize(9).fillColor('#64748B').text('No shift intervals recorded yet.', 46, currentY + 8);
    currentY += 24;
  } else {
    attendanceSlice.forEach((att) => {
      doc.rect(40, currentY, 515, 18).fillAndStroke('#FFFFFF', '#F1F5F9');
      doc.fontSize(8).fillColor('#334155');
      doc.text(att.date, 46, currentY + 5);
      doc.text(new Date(att.clockInAt).toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit' }), 120, currentY + 5);
      doc.text(att.clockOutAt ? new Date(att.clockOutAt).toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit' }) : 'In Progress', 220, currentY + 5);
      doc.text(att.durationFormatted, 330, currentY + 5);
      doc.text(att.notes.slice(0, 22), 420, currentY + 5);
      currentY += 18;
    });
  }

  // 5. Job & Order History Table
  currentY += 16;
  doc.fontSize(12).fillColor('#0284C7').text('Assigned Service Jobs & Order History', 40, currentY);
  currentY += 18;

  doc.rect(40, currentY, 515, 20).fill('#0F172A');
  doc.fontSize(8).fillColor('#FFFFFF');
  doc.text('Job Number', 46, currentY + 6);
  doc.text('Customer', 140, currentY + 6);
  doc.text('Service Type', 260, currentY + 6);
  doc.text('Scheduled', 410, currentY + 6);
  doc.text('Status', 485, currentY + 6);
  currentY += 20;

  const jobsSlice = data.orderHistory.slice(0, 10);
  if (jobsSlice.length === 0) {
    doc.fontSize(9).fillColor('#64748B').text('No service jobs assigned yet.', 46, currentY + 8);
    currentY += 24;
  } else {
    jobsSlice.forEach((job) => {
      doc.rect(40, currentY, 515, 18).fillAndStroke('#FFFFFF', '#F1F5F9');
      doc.fontSize(8).fillColor('#334155');
      doc.text(job.jobNumber, 46, currentY + 5);
      doc.text(job.customerName.slice(0, 18), 140, currentY + 5);
      doc.text(job.serviceName.slice(0, 24), 260, currentY + 5);
      doc.text(new Date(job.scheduledDate).toLocaleDateString(), 410, currentY + 5);
      
      const statusColor = job.status === 'COMPLETED' ? '#16A34A' : job.status === 'CANCELLED' ? '#DC2626' : '#D97706';
      doc.fillColor(statusColor).text(job.status, 485, currentY + 5);
      currentY += 18;
    });
  }

  // Footer
  doc.strokeColor('#CBD5E1').lineWidth(1).moveTo(40, 780).lineTo(555, 780).stroke();
  doc.fontSize(8).fillColor('#94A3B8').text(
    'CARING COOL TECH • Field Service Operations • Puducherry - 605 004',
    40,
    790,
    { align: 'center', width: 515 }
  );

  doc.end();
}
