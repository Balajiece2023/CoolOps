import PDFDocument from 'pdfkit';
import { prisma } from '../prisma';
import { Response } from 'express';
import * as path from 'path';
import * as fs from 'fs';

function formatDate(date: Date | string | null | undefined): string {
  if (!date) return '-';
  const d = new Date(date);
  if (isNaN(d.getTime())) return '-';
  const day = String(d.getDate()).padStart(2, '0');
  const month = String(d.getMonth() + 1).padStart(2, '0');
  const year = d.getFullYear();
  return `${day}.${month}.${year}`;
}

export async function generateFieldServiceReportPdf(reportId: string, res: Response) {
  const report = await prisma.fieldServiceReport.findUnique({
    where: { id: reportId },
    include: {
      serviceJob: {
        include: {
          booking: {
            include: { customer: true, address: true, serviceType: true }
          },
          technician: {
            include: { user: true }
          }
        }
      },
      technician: {
        include: { user: true }
      }
    }
  });

  if (!report) {
    throw new Error('Field Service Report not found');
  }

  const doc = new PDFDocument({
    margin: 28,
    size: 'A4',
    info: {
      Title: `Field Service Report ${report.reportNumber}`,
      Author: 'Caring Cool Tech'
    }
  });

  const safeFileName = `FSR_${report.reportNumber.replace(/[^a-zA-Z0-9_-]/g, '_')}.pdf`;
  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader('Content-Disposition', `inline; filename="${safeFileName}"`);

  doc.pipe(res);

  const left = 28;
  const top = 28;
  const pageWidth = 595.28 - 2 * left; // ~539 pt
  let curY = top;

  // 1. Brand header bar: TOSHIBA, CCT, CARRIER (Mitsubishi and Blue Star removed)
  const brandBarHeight = 36;
  doc.rect(left, curY, pageWidth, brandBarHeight).lineWidth(0.8).stroke('#0F172A');

  // Brand blocks: 3 columns across header
  const colWidth = pageWidth / 3;

  // 1. Toshiba (Left)
  doc.fontSize(11).font('Helvetica-Bold').fillColor('#DC2626')
    .text('TOSHIBA', left, curY + 8, { width: colWidth, align: 'center' });
  doc.fontSize(6.5).font('Helvetica').fillColor('#64748B')
    .text('Leading Innovation >>>', left, curY + 23, { width: colWidth, align: 'center' });

  // 2. CCT Center Logo
  const cctColX = left + colWidth;
  const logoPath = path.join(process.cwd(), 'assets', 'cct_logo.png');
  const fallbackPath = path.join(process.cwd(), '..', 'mobile', 'assets', 'images', 'cct_logo.png');
  const resolvedLogo = fs.existsSync(logoPath) ? logoPath : (fs.existsSync(fallbackPath) ? fallbackPath : null);

  if (resolvedLogo) {
    try {
      doc.image(resolvedLogo, cctColX + (colWidth - 64) / 2, curY + 2, { fit: [64, 32] });
    } catch (_) {
      doc.fontSize(15).font('Helvetica-Bold').fillColor('#0284C7')
        .text('CCT', cctColX, curY + 6, { width: colWidth, align: 'center' });
      doc.fontSize(6.5).font('Helvetica').fillColor('#0284C7')
        .text('turn to the experts', cctColX, curY + 23, { width: colWidth, align: 'center' });
    }
  } else {
    doc.fontSize(15).font('Helvetica-Bold').fillColor('#0284C7')
      .text('CCT', cctColX, curY + 6, { width: colWidth, align: 'center' });
    doc.fontSize(6.5).font('Helvetica').fillColor('#0284C7')
      .text('turn to the experts', cctColX, curY + 23, { width: colWidth, align: 'center' });
  }

  // 3. Carrier Logo (Right)
  const carrierColX = left + colWidth * 2;
  const carrierLogoPath = path.join(process.cwd(), 'assets', 'carrier_logo.png');
  const carrierFallbackPath = path.join(process.cwd(), '..', 'mobile', 'assets', 'images', 'carrier_logo.png');
  const resolvedCarrierLogo = fs.existsSync(carrierLogoPath)
    ? carrierLogoPath
    : (fs.existsSync(carrierFallbackPath) ? carrierFallbackPath : null);

  const carFitW = 76;
  const carFitH = 28;
  const carX = carrierColX + (colWidth - carFitW) / 2;
  const carY = curY + (brandBarHeight - carFitH) / 2;

  if (resolvedCarrierLogo) {
    try {
      doc.image(resolvedCarrierLogo, carX, carY, { fit: [carFitW, carFitH], align: 'center', valign: 'center' });
    } catch (_) {
      const pillW = 76;
      const pillH = 24;
      const carPillX = carrierColX + (colWidth - pillW) / 2;
      const carPillY = curY + 6;
      doc.roundedRect(carPillX, carPillY, pillW, pillH, 12).fillColor('#003882').fill();
      doc.fontSize(12).font('Helvetica-BoldOblique').fillColor('#FFFFFF')
        .text('Carrier', carPillX, carPillY + 5, { width: pillW, align: 'center' });
    }
  } else {
    const pillW = 76;
    const pillH = 24;
    const carPillX = carrierColX + (colWidth - pillW) / 2;
    const carPillY = curY + 6;
    doc.roundedRect(carPillX, carPillY, pillW, pillH, 12).fillColor('#003882').fill();
    doc.fontSize(12).font('Helvetica-BoldOblique').fillColor('#FFFFFF')
      .text('Carrier', carPillX, carPillY + 5, { width: pillW, align: 'center' });
  }

  curY += brandBarHeight + 6;

  // 2. Title & Report Number
  doc.fontSize(14).font('Helvetica-Bold').fillColor('#000000')
    .text('FIELD SERVICE REPORT', left, curY, { width: pageWidth - 100, align: 'center', underline: true });

  doc.fontSize(10).font('Helvetica-Bold').fillColor('#000000')
    .text(`No.   ${report.reportNumber}`, left + pageWidth - 120, curY, { width: 120, align: 'right' });

  curY += 24;

  // 3. Classification Checkboxes
  const boxTypes = [
    { key: 'COMMISSIONING', label: 'COMMISSIONING' },
    { key: 'WARRANTY', label: 'WARRANTY' },
    { key: 'MAIN_CONTACT', label: 'MAIN CONTACT' },
    { key: 'DO_AND_CHARGE_REPAIR', label: 'DO & CHARGE REPAIR' }
  ];

  doc.fontSize(8).font('Helvetica-Bold').fillColor('#000000')
    .text('REPORT ON :', left, curY + 2);

  let cbX = left + 75;
  for (const bt of boxTypes) {
    const isSelected = report.reportType === bt.key ||
      (bt.key === 'MAIN_CONTACT' && (report.reportType === 'MAINTENANCE_CONTRACT' || report.reportType === 'AMC'));

    // Draw box
    doc.rect(cbX, curY, 110, 16).lineWidth(0.8).stroke('#000000');
    if (isSelected) {
      doc.save()
        .lineWidth(1.6)
        .strokeColor('#0F172A')
        .moveTo(cbX + 3, curY + 8)
        .lineTo(cbX + 6, curY + 12)
        .lineTo(cbX + 12, curY + 4)
        .stroke()
        .restore();
    }
    doc.fontSize(7.5).font('Helvetica-Bold').fillColor('#000000')
      .text(bt.label, cbX + 16, curY + 4, { width: 90, align: 'left' });

    cbX += 114;
  }

  curY += 22;

  // 4. Main Details Grid: Customer (Left) vs Dealer (Right)
  const gridHeight = 110;
  const halfWidth = pageWidth / 2;

  // Outer border
  doc.rect(left, curY, pageWidth, gridHeight).lineWidth(0.8).stroke('#000000');
  // Vertical divider
  doc.moveTo(left + halfWidth, curY).lineTo(left + halfWidth, curY + gridHeight).lineWidth(0.8).stroke('#000000');

  // Left side: Customer details
  doc.fontSize(8).font('Helvetica-Bold').fillColor('#000000')
    .text('CUSTOMER NAME :', left + 8, curY + 8);
  doc.fontSize(9).font('Helvetica').fillColor('#000000')
    .text(report.customerName.toUpperCase(), left + 100, curY + 8, { width: halfWidth - 108 });

  doc.fontSize(8).font('Helvetica-Bold').fillColor('#000000')
    .text('& ADDRESS :', left + 8, curY + 26);
  doc.fontSize(8).font('Helvetica').fillColor('#000000')
    .text(report.customerAddress, left + 72, curY + 26, { width: halfWidth - 80 });

  doc.fontSize(8).font('Helvetica-Bold').fillColor('#000000')
    .text('CONTACT TEL NO :', left + 8, curY + 68);
  doc.fontSize(8).font('Helvetica').fillColor('#000000')
    .text(report.contactPhone || '-', left + 100, curY + 68);

  doc.fontSize(8).font('Helvetica-Bold').fillColor('#000000')
    .text('PERSON CALLING :', left + 8, curY + 88);
  doc.fontSize(8).font('Helvetica').fillColor('#000000')
    .text(report.personCalling || '-', left + 100, curY + 88);

  // Right side: Dealer Details
  const rightX = left + halfWidth + 8;
  doc.fontSize(8).font('Helvetica-Bold').fillColor('#000000')
    .text('DEALER & ADDRESS :', rightX, curY + 6);

  doc.fontSize(11).font('Helvetica-Bold').fillColor('#DC2626')
    .text('CARING COOL TECH', rightX + 60, curY + 18, { width: halfWidth - 75, align: 'center' });
  doc.fontSize(6.5).font('Helvetica').fillColor('#334155')
    .text('(Any Brand Aircon Sales & Service Commercial)', rightX, curY + 32, { width: halfWidth - 16, align: 'center' });
  doc.fontSize(6.5).font('Helvetica').fillColor('#334155')
    .text(report.dealerAddress, rightX, curY + 42, { width: halfWidth - 16, align: 'center' });
  const displayDealerPhone = (report.dealerPhone || '96776 86561 / 99766 88166').replace('99776', '96776');
  doc.fontSize(7).font('Helvetica-Bold').fillColor('#0F172A')
    .text(`Mobile : ${displayDealerPhone}`, rightX, curY + 54, { width: halfWidth - 16, align: 'center' });
  doc.fontSize(6.5).font('Helvetica').fillColor('#0F172A')
    .text(`Email : ${report.dealerEmail}`, rightX, curY + 64, { width: halfWidth - 16, align: 'center' });

  // Service Engg. Name line inside dealer box
  doc.moveTo(left + halfWidth, curY + 82).lineTo(left + pageWidth, curY + 82).lineWidth(0.6).stroke('#000000');
  doc.fontSize(8).font('Helvetica-Bold').fillColor('#000000')
    .text('Service Engg. Name :', rightX, curY + 88);
  doc.fontSize(9).font('Helvetica-Bold').fillColor('#0284C7')
    .text(report.serviceEngineerName.toUpperCase(), rightX + 100, curY + 88);

  curY += gridHeight;

  // 5. Dates and Serial Numbers Bar
  const datesBarHeight = 38;
  doc.rect(left, curY, pageWidth, datesBarHeight).lineWidth(0.8).stroke('#000000');
  doc.moveTo(left + halfWidth, curY).lineTo(left + halfWidth, curY + datesBarHeight).lineWidth(0.8).stroke('#000000');

  // Left: Complaint & Attending
  doc.fontSize(7.5).font('Helvetica-Bold').fillColor('#000000')
    .text('COMPLAINT', left + 8, curY + 4, { underline: true });
  doc.fontSize(7.5).font('Helvetica').fillColor('#000000')
    .text(`DATE: ${formatDate(report.complaintDate)}`, left + 8, curY + 16);

  doc.fontSize(7.5).font('Helvetica-Bold').fillColor('#000000')
    .text('ATTENDING', left + 140, curY + 4, { underline: true });
  doc.fontSize(7.5).font('Helvetica').fillColor('#000000')
    .text(`DATE: ${formatDate(report.attendingDate)}`, left + 140, curY + 16);

  // Right: Indoor & Outdoor Serial Numbers
  doc.fontSize(7.5).font('Helvetica-Bold').fillColor('#000000')
    .text('INDOOR SL. NO     :', rightX, curY + 6);
  doc.fontSize(8).font('Helvetica').fillColor('#000000')
    .text(report.indoorSerialNo || '-', rightX + 100, curY + 6);

  doc.fontSize(7.5).font('Helvetica-Bold').fillColor('#000000')
    .text('OUT DOOR SL. NO :', rightX, curY + 20);
  doc.fontSize(8).font('Helvetica').fillColor('#000000')
    .text(report.outdoorSerialNo || '-', rightX + 100, curY + 20);

  curY += datesBarHeight;

  // 6. Multi-Unit Model & Serial Number Table (5 Rows)
  const tableStartY = curY;
  const colSl = 38;
  const colModel = (pageWidth - colSl) / 2;
  const colSerial = colModel;
  const xSl = left;
  const xModel = xSl + colSl;
  const xSerial = xModel + colModel;

  const tableHeaderH = 15;
  const tableRowH = 15;
  const numRows = 5;
  const tableTotalH = tableHeaderH + (numRows * tableRowH);

  // Table Outer Border
  doc.rect(left, tableStartY, pageWidth, tableTotalH).lineWidth(0.8).stroke('#000000');

  // Table Header Background & Text
  doc.rect(left, tableStartY, pageWidth, tableHeaderH).fillAndStroke('#F8FAFC', '#000000');
  doc.fontSize(7.5).font('Helvetica-Bold').fillColor('#000000');
  doc.text('Sl.No.', xSl, tableStartY + 4, { width: colSl, align: 'center' });
  doc.text('UNIT MODEL No.', xModel, tableStartY + 4, { width: colModel, align: 'center' });
  doc.text('UNIT SERIAL No.', xSerial, tableStartY + 4, { width: colSerial, align: 'center' });

  // Vertical dividers through entire table
  doc.moveTo(xModel, tableStartY).lineTo(xModel, tableStartY + tableTotalH).lineWidth(0.6).stroke('#000000');
  doc.moveTo(xSerial, tableStartY).lineTo(xSerial, tableStartY + tableTotalH).lineWidth(0.6).stroke('#000000');

  // Collect unit data to populate rows
  const unitsData: { model: string; serial: string }[] = [];
  const bookingObj = report.serviceJob?.booking as any;
  const fallbackModel = bookingObj?.serviceType?.nameEn ? `${bookingObj.serviceType.nameEn} Unit` : '';
  const primaryModel = report.modelNumber || fallbackModel;
  const primarySerial = report.indoorSerialNo || report.outdoorSerialNo || '';

  if (primaryModel || primarySerial) {
    unitsData.push({ model: primaryModel, serial: primarySerial });
  }
  if (report.outdoorSerialNo && report.outdoorSerialNo !== primarySerial) {
    unitsData.push({
      model: report.modelNumber ? `${report.modelNumber} (ODU)` : 'Outdoor Unit',
      serial: report.outdoorSerialNo
    });
  }

  // Draw 5 rows
  let rowY = tableStartY + tableHeaderH;
  for (let i = 1; i <= numRows; i++) {
    doc.moveTo(left, rowY).lineTo(left + pageWidth, rowY).lineWidth(0.5).stroke('#000000');

    doc.fontSize(7.5).font('Helvetica').fillColor('#000000')
      .text(`${i}`, xSl, rowY + 4, { width: colSl, align: 'center' });

    const unit = unitsData[i - 1];
    if (unit) {
      if (unit.model) {
        doc.fontSize(7.5).font('Helvetica-Bold').fillColor('#0F172A')
          .text(unit.model, xModel + 6, rowY + 4, { width: colModel - 12, align: 'left' });
      }
      if (unit.serial) {
        doc.fontSize(7.5).font('Helvetica').fillColor('#0F172A')
          .text(unit.serial, xSerial + 6, rowY + 4, { width: colSerial - 12, align: 'left' });
      }
    }

    rowY += tableRowH;
  }

  curY = tableStartY + tableTotalH;

  // 7. OBSERVATIONS / REPORT & ACTION Box
  const obsBoxH = 92;
  doc.rect(left, curY, pageWidth, obsBoxH).lineWidth(0.8).stroke('#000000');

  doc.fontSize(8).font('Helvetica-Bold').fillColor('#000000')
    .text('OBSERVATIONS / REPORT & ACTION :', left + 8, curY + 6);

  const obsText = report.observations ? report.observations.trim() : '';
  const sugText = report.suggestions && report.suggestions.trim().length > 0 ? ` | Suggestion: ${report.suggestions.trim()}` : '';
  const fullObsText = `${obsText}${sugText}`.trim();

  if (fullObsText) {
    doc.fontSize(7.5).font('Helvetica').fillColor('#0F172A')
      .text(fullObsText, left + 10, curY + 20, {
        width: pageWidth - 20,
        lineGap: 2
      });
  }

  // 2 Dotted lines for visual notes
  const dotStart = curY + 46;
  doc.save()
    .lineWidth(0.5)
    .strokeColor('#94A3B8')
    .dash(1.5, { space: 2.5 });

  for (let l = 0; l < 2; l++) {
    const dy = dotStart + (l * 20);
    if (dy < curY + obsBoxH - 8) {
      doc.moveTo(left + 8, dy).lineTo(left + pageWidth - 8, dy).stroke();
    }
  }
  doc.restore();

  curY += obsBoxH;

  // 8. FINAL TEST MEASUREMENTS (AS APPLICABLE) - Exact table matching official report
  const ftmHeaderH = 15;
  const ftmRowH = 16;
  const ftmTotalH = ftmHeaderH + (4 * ftmRowH);
  const ftmColW = pageWidth / 4; // 4 equal columns

  // Outer border & Header background
  doc.rect(left, curY, pageWidth, ftmTotalH).lineWidth(0.8).stroke('#000000');
  doc.rect(left, curY, pageWidth, ftmHeaderH).fillAndStroke('#F1F5F9', '#000000');

  doc.fontSize(7.5).font('Helvetica-Bold').fillColor('#000000')
    .text('Final Test Measurements (As applicable)', left, curY + 4, { width: pageWidth, align: 'center' });

  // Draw 3 vertical column dividers inside measurements table
  for (let c = 1; c < 4; c++) {
    const vx = left + (c * ftmColW);
    doc.moveTo(vx, curY + ftmHeaderH).lineTo(vx, curY + ftmTotalH).lineWidth(0.6).stroke('#000000');
  }

  // Helper function to render a measurement cell
  const renderFtmCell = (colIdx: number, rowIdx: number, label: string, val: string, unit: string = '') => {
    const cx = left + (colIdx * ftmColW);
    const cy = curY + ftmHeaderH + (rowIdx * ftmRowH);
    const padX = 6;
    const textY = cy + 4;

    doc.fontSize(6.5).font('Helvetica-Bold').fillColor('#1E293B')
      .text(label, cx + padX, textY, { width: ftmColW - (padX * 2), continued: true });

    if (val && val.trim().length > 0) {
      doc.fontSize(7).font('Helvetica-Bold').fillColor('#0284C7')
        .text(` ${val.trim()}`, { continued: unit.length > 0 });
      if (unit) {
        doc.fontSize(6.5).font('Helvetica').fillColor('#475569').text(` ${unit}`);
      }
    } else {
      doc.fontSize(6.5).font('Helvetica').fillColor('#94A3B8')
        .text(' -', { continued: unit.length > 0 });
      if (unit) {
        doc.fontSize(6.5).font('Helvetica').fillColor('#94A3B8').text(` ${unit}`);
      }
    }
  };

  // Draw 4 horizontal row lines
  for (let r = 1; r <= 4; r++) {
    const ry = curY + ftmHeaderH + (r * ftmRowH);
    if (r < 4) {
      doc.moveTo(left, ry).lineTo(left + pageWidth, ry).lineWidth(0.5).stroke('#000000');
    }
  }

  // Row 1:
  // Col 0: Power Servo/Stab: Yes [ ] No [ ]
  const r0cy = curY + ftmHeaderH;
  const isPowerYes = (report.powerServoStab || '').toUpperCase() === 'YES';
  const isPowerNo = (report.powerServoStab || '').toUpperCase() === 'NO';

  doc.fontSize(6.5).font('Helvetica-Bold').fillColor('#1E293B')
    .text('Power Servo/Stab:', left + 5, r0cy + 4, { continued: true });
  doc.font('Helvetica').fillColor('#000000').text(' Yes ');

  // Yes box
  const yesBoxX = left + 76;
  const boxY = r0cy + 4;
  doc.rect(yesBoxX, boxY, 8, 8).lineWidth(0.6).stroke('#000000');
  if (isPowerYes) {
    doc.save()
      .lineWidth(1.2).strokeColor('#0284C7')
      .moveTo(yesBoxX + 1.5, boxY + 4).lineTo(yesBoxX + 3.5, boxY + 6.5).lineTo(yesBoxX + 6.5, boxY + 1.5)
      .stroke().restore();
  }

  doc.fontSize(6.5).font('Helvetica').fillColor('#000000')
    .text(' No ', yesBoxX + 12, r0cy + 4, { continued: false });

  // No box
  const noBoxX = yesBoxX + 26;
  doc.rect(noBoxX, boxY, 8, 8).lineWidth(0.6).stroke('#000000');
  if (isPowerNo) {
    doc.save()
      .lineWidth(1.2).strokeColor('#0284C7')
      .moveTo(noBoxX + 1.5, boxY + 4).lineTo(noBoxX + 3.5, boxY + 6.5).lineTo(noBoxX + 6.5, boxY + 1.5)
      .stroke().restore();
  }

  // Row 1 remaining columns
  renderFtmCell(1, 0, 'Voltage (N- Earth):', report.voltageNEarth || '', 'V');
  renderFtmCell(2, 0, 'Press (Suc):', report.pressSuc || report.suctionPressure || '', 'psi');
  renderFtmCell(3, 0, 'Room Temp.:', report.roomTemp || report.roomTemperature || '', '°C');

  // Row 2:
  renderFtmCell(0, 1, 'Voltage (L1-N):', report.voltageL1N || report.voltage || '', 'V');
  renderFtmCell(1, 1, 'Voltage (L1 - L2):', report.voltageL1L2 || '', 'V');
  renderFtmCell(2, 1, 'Press (Dis):', report.pressDis || report.dischargePressure || '', 'psi');
  renderFtmCell(3, 1, 'Supply Air Temp.:', report.supplyAirTemp || '', '°C');

  // Row 3:
  renderFtmCell(0, 2, 'Voltage (L2-N):', report.voltageL2N || '', 'V');
  renderFtmCell(1, 2, 'Voltage (L2 - L3):', report.voltageL2L3 || '', 'V');
  renderFtmCell(2, 2, 'Comp. Current:', report.compCurrent || '', 'Amp');
  renderFtmCell(3, 2, 'Return Air Temp.:', report.returnAirTemp || '', '°C');

  // Row 4:
  renderFtmCell(0, 3, 'Voltage (L3-N):', report.voltageL3N || '', 'V');
  renderFtmCell(1, 3, 'Voltage (L3 - L1):', report.voltageL3L1 || '', 'V');
  renderFtmCell(2, 3, 'Unit Currents:', report.unitCurrents || report.runningCurrent || '', 'Amp');
  renderFtmCell(3, 3, 'Ambient Temp.:', report.ambientTemp || '', '°C');

  curY += ftmTotalH;

  // 9. Signatures Block (Bottom)
  const sigSpacing = 28;
  curY += sigSpacing;

  // Signature names / digital stamps
  if (report.customerSignName) {
    doc.fontSize(8.5).font('Helvetica-Oblique').fillColor('#0F172A')
      .text(`Signed by: ${report.customerSignName}`, left + 14, curY - 12);
  }

  doc.fontSize(8.5).font('Helvetica-Bold').fillColor('#0284C7')
    .text(report.serviceEngineerName, left + halfWidth + 40, curY - 12);

  // Signature Labels exactly matching template
  doc.fontSize(7.5).font('Helvetica-Bold').fillColor('#000000')
    .text('(CUSTOMER\'S SIGNATURE WITH SEAL)', left + 14, curY);

  doc.fontSize(7.5).font('Helvetica-Bold').fillColor('#000000')
    .text('(TECHNICIAN\'S SIGNATURE)', left + halfWidth + 40, curY);

  // End Document
  doc.end();
}

