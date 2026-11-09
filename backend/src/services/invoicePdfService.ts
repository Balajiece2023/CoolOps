import PDFDocument from 'pdfkit';
import { prisma } from '../prisma';
import { Response } from 'express';
import * as path from 'path';
import * as fs from 'fs';

// Helper: Convert number to Indian Currency Words
function numberToIndianWords(amount: number): string {
  const a = [
    '', 'One ', 'Two ', 'Three ', 'Four ', 'Five ', 'Six ', 'Seven ', 'Eight ', 'Nine ', 'Ten ',
    'Eleven ', 'Twelve ', 'Thirteen ', 'Fourteen ', 'Fifteen ', 'Sixteen ', 'Seventeen ', 'Eighteen ', 'Nineteen '
  ];
  const b = ['', '', 'Twenty ', 'Thirty ', 'Forty ', 'Fifty ', 'Sixty ', 'Seventy ', 'Eighty ', 'Ninety '];

  const rounded = Math.round(amount);
  if (rounded === 0) return 'Zero Rupees only';

  function inWords(n: number): string {
    let str = '';
    if (n > 99) {
      str += a[Math.floor(n / 100)] + 'Hundred ';
      n %= 100;
      if (n > 0) str += 'and ';
    }
    if (n > 19) {
      str += b[Math.floor(n / 10)] + a[n % 10];
    } else {
      str += a[n];
    }
    return str;
  }

  const crore = Math.floor(rounded / 10000000);
  const remCrore = rounded % 10000000;
  const lakh = Math.floor(remCrore / 100000);
  const remLakh = remCrore % 100000;
  const thousand = Math.floor(remLakh / 1000);
  const remThousand = remLakh % 1000;

  let result = '';
  if (crore > 0) result += inWords(crore) + 'Crore ';
  if (lakh > 0) result += inWords(lakh) + 'Lakh ';
  if (thousand > 0) result += inWords(thousand) + 'Thousand ';
  if (remThousand > 0) result += inWords(remThousand);

  return result.trim() + ' Rupees only';
}

function formatDate(date: Date | string): string {
  const d = new Date(date);
  const day = String(d.getDate()).padStart(2, '0');
  const month = String(d.getMonth() + 1).padStart(2, '0');
  const year = d.getFullYear();
  return `${day}-${month}-${year}`;
}

export async function generateInvoicePdf(invoiceId: string, res: Response) {
  const invoice = await prisma.invoice.findUnique({
    where: { id: invoiceId },
    include: {
      customer: {
        include: { addresses: true }
      },
      items: true,
      payments: true,
      serviceJob: {
        include: {
          booking: {
            include: { serviceType: true, address: true }
          }
        }
      }
    }
  });

  if (!invoice) {
    throw new Error('Invoice not found');
  }

  const doc = new PDFDocument({ margin: 30, size: 'A4' });

  // Register font supporting Indian Rupee symbol (₹) if available
  let normalFont = 'Helvetica';
  let boldFont = 'Helvetica-Bold';
  const arialPath = 'C:\\Windows\\Fonts\\arial.ttf';
  const arialBoldPath = 'C:\\Windows\\Fonts\\arialbd.ttf';
  let hasRupeeGlyph = false;

  if (fs.existsSync(arialPath) && fs.existsSync(arialBoldPath)) {
    try {
      doc.registerFont('CustomArial', arialPath);
      doc.registerFont('CustomArial-Bold', arialBoldPath);
      normalFont = 'CustomArial';
      boldFont = 'CustomArial-Bold';
      hasRupeeGlyph = true;
    } catch (_) {}
  }

  const curr = hasRupeeGlyph ? '₹' : 'Rs.';

  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader('Content-Disposition', `attachment; filename="${invoice.invoiceNumber}.pdf"`);

  doc.pipe(res);

  const x0 = 35;
  const x1 = 560;
  const tableWidth = x1 - x0; // 525

  // 1. Centered Top Title: Tax Invoice
  doc.font(boldFont).fontSize(14).fillColor('#1E293B')
     .text('Tax Invoice', x0, 32, { width: tableWidth, align: 'center' });

  let curY = 52;

  // 2. Main Company Header Box (Outer Border)
  const headerBoxHeight = 68;
  doc.rect(x0, curY, tableWidth, headerBoxHeight).strokeColor('#64748B').lineWidth(0.8).stroke();

  // Find CCT Logo Path
  const candidates = [
    path.resolve(process.cwd(), 'assets/cct_logo.jpg'),
    path.resolve(process.cwd(), 'assets/cct_logo.png'),
    path.resolve(__dirname, '../../../assets/cct_logo.jpg'),
    path.resolve(__dirname, '../../assets/cct_logo.jpg'),
    path.resolve(__dirname, '../assets/cct_logo.jpg'),
    path.resolve(__dirname, '../../dist/assets/cct_logo.jpg')
  ];
  const activeLogo = candidates.find(p => fs.existsSync(p));

  if (activeLogo) {
    try {
      doc.image(activeLogo, x0 + 10, curY + 6, { fit: [68, 56], align: 'center', valign: 'center' });
    } catch (_) {
      doc.font(boldFont).fontSize(20).fillColor('#1E75BB').text('CCT', x0 + 15, curY + 20);
    }
  } else {
    doc.font(boldFont).fontSize(20).fillColor('#1E75BB').text('CCT', x0 + 15, curY + 20);
  }

  // Company Details (aligned beside logo)
  const compX = x0 + 88;
  doc.font(boldFont).fontSize(12).fillColor('#0F172A').text('CARING COOL TECH', compX, curY + 8);
  doc.font(normalFont).fontSize(7.5).fillColor('#334155');
  doc.text('GR FL NO.1NETHA NAGAR VALARAMPET PUDUCHERRY-605 004', compX, curY + 24);
  doc.text('Phone: 9677686561              Email: caringcooltech@gmail.com', compX, curY + 36);
  doc.text('GSTIN: 34BYEPA2853E1ZX   State: 34-Puducherry', compX, curY + 48);

  curY += headerBoxHeight;

  // 3. Bill To & Invoice Details Boxes (Side-by-side with vertical separator)
  const billBoxHeight = 82;
  const splitX = x0 + 265; // middle separator

  doc.rect(x0, curY, tableWidth, billBoxHeight).strokeColor('#64748B').lineWidth(0.8).stroke();
  doc.moveTo(splitX, curY).lineTo(splitX, curY + billBoxHeight).stroke();

  // Left: Bill To
  let custAddress = 'PUDUCHERRY';
  if (invoice.customer.addresses && invoice.customer.addresses.length > 0) {
    const a = invoice.customer.addresses[0];
    custAddress = `${a.addressLine || ''}, ${a.area || ''}`.trim().replace(/^,|,$/g, '');
  } else if (invoice.serviceJob?.booking?.address) {
    const a = invoice.serviceJob.booking.address;
    custAddress = `${a.addressLine || ''}, ${a.area || ''}`.trim().replace(/^,|,$/g, '');
  }

  doc.font(boldFont).fontSize(8).fillColor('#0F172A').text('Bill To:', x0 + 8, curY + 6);
  doc.font(boldFont).fontSize(8.5).fillColor('#0F172A').text(invoice.customer.name.toUpperCase(), x0 + 8, curY + 18, { width: 245 });
  doc.font(normalFont).fontSize(7.5).fillColor('#334155').text(custAddress, x0 + 8, curY + 31, { width: 245 });
  doc.text(`Contact No: ${invoice.customer.phone}`, x0 + 8, curY + 52);
  doc.text('State: 34-Puducherry', x0 + 8, curY + 63);

  // Right: Invoice Details
  const invNumDisplay = invoice.invoiceNumber.replace(/^INV-/, '');
  doc.font(boldFont).fontSize(8).fillColor('#0F172A').text('Invoice Details:', splitX + 8, curY + 6);
  doc.font(normalFont).fontSize(8).fillColor('#334155');
  doc.text(`No: ${invNumDisplay}`, splitX + 8, curY + 18);
  doc.text(`Date: ${formatDate(invoice.createdAt)}`, splitX + 8, curY + 30);
  doc.text('Place of Supply: 34-Puducherry', splitX + 8, curY + 42);

  curY += billBoxHeight;

  // 4. Items Table
  const cols = [
    { x: x0, w: 24, align: 'center', label: '#' },
    { x: x0 + 24, w: 190, align: 'left', label: 'Item Name' },
    { x: x0 + 214, w: 55, align: 'center', label: 'HSN/ SAC' },
    { x: x0 + 269, w: 40, align: 'center', label: 'Quantity' },
    { x: x0 + 309, w: 70, align: 'right', label: `Price/ Unit (${curr})` },
    { x: x0 + 379, w: 76, align: 'right', label: `GST(${curr})` },
    { x: x0 + 455, w: 70, align: 'right', label: `Amount(${curr})` },
  ];

  // Table Header
  const tableHeaderHeight = 20;
  doc.rect(x0, curY, tableWidth, tableHeaderHeight).strokeColor('#64748B').lineWidth(0.8).stroke();
  for (let i = 1; i < cols.length; i++) {
    doc.moveTo(cols[i].x, curY).lineTo(cols[i].x, curY + tableHeaderHeight).stroke();
  }

  doc.font(boldFont).fontSize(7.5).fillColor('#0F172A');
  for (const c of cols) {
    const pad = c.align === 'right' ? -4 : (c.align === 'left' ? 4 : 0);
    doc.text(c.label, c.x + pad, curY + 5, { width: c.w, align: c.align as any });
  }

  curY += tableHeaderHeight;

  // Table Body Rows
  let totalQty = 0;
  const defaultTaxRate = invoice.taxRate || 18.0;

  invoice.items.forEach((item, idx) => {
    const itemTax = (item.totalPrice * defaultTaxRate) / 100;
    const itemGross = item.totalPrice + itemTax;
    totalQty += item.quantity;

    const rowHeight = 24;
    doc.rect(x0, curY, tableWidth, rowHeight).strokeColor('#64748B').lineWidth(0.6).stroke();
    for (let i = 1; i < cols.length; i++) {
      doc.moveTo(cols[i].x, curY).lineTo(cols[i].x, curY + rowHeight).stroke();
    }

    doc.font(normalFont).fontSize(7.5).fillColor('#0F172A');
    doc.text(String(idx + 1), cols[0].x, curY + 7, { width: cols[0].w, align: 'center' });
    doc.text(item.description, cols[1].x + 4, curY + 7, { width: cols[1].w - 8, align: 'left' });
    doc.text('995463', cols[2].x, curY + 7, { width: cols[2].w, align: 'center' });
    doc.text(String(item.quantity), cols[3].x, curY + 7, { width: cols[3].w, align: 'center' });
    doc.text(`${curr} ${item.unitPrice.toFixed(2)}`, cols[4].x - 4, curY + 7, { width: cols[4].w, align: 'right' });
    doc.text(`${curr} ${itemTax.toFixed(2)}\n(${defaultTaxRate.toFixed(1)}%)`, cols[5].x - 4, curY + 3, { width: cols[5].w, align: 'right' });
    doc.text(`${curr} ${itemGross.toFixed(2)}`, cols[6].x - 4, curY + 7, { width: cols[6].w, align: 'right' });

    curY += rowHeight;
  });

  // Table Total Row
  const totalRowHeight = 18;
  doc.rect(x0, curY, tableWidth, totalRowHeight).strokeColor('#64748B').lineWidth(0.8).stroke();
  for (let i = 1; i < cols.length; i++) {
    doc.moveTo(cols[i].x, curY).lineTo(cols[i].x, curY + totalRowHeight).stroke();
  }

  doc.font(boldFont).fontSize(8).fillColor('#0F172A');
  doc.text('Total', cols[1].x + 4, curY + 5, { width: cols[1].w - 8, align: 'left' });
  doc.text(String(totalQty), cols[3].x, curY + 5, { width: cols[3].w, align: 'center' });
  doc.text(`${curr} ${invoice.taxAmount.toFixed(2)}`, cols[5].x - 4, curY + 5, { width: cols[5].w, align: 'right' });
  doc.text(`${curr} ${invoice.totalAmount.toFixed(2)}`, cols[6].x - 4, curY + 5, { width: cols[6].w, align: 'right' });

  curY += totalRowHeight;

  // 5. Tax Summary (Left) & Financial Summary / Balance (Right)
  const summaryBoxHeight = 90;
  const taxSummaryWidth = 285;
  const rightBoxX = x0 + taxSummaryWidth;
  const rightBoxWidth = tableWidth - taxSummaryWidth; // 240

  doc.rect(x0, curY, tableWidth, summaryBoxHeight).strokeColor('#64748B').lineWidth(0.8).stroke();
  doc.moveTo(rightBoxX, curY).lineTo(rightBoxX, curY + summaryBoxHeight).stroke();

  // --- Left: Tax Summary Subtable ---
  doc.font(boldFont).fontSize(7.5).fillColor('#0F172A').text('Tax Summary:', x0 + 6, curY + 4);

  const tcurY = curY + 16;
  const tHeaderH = 16;
  const tCol1 = x0;          // HSN (48)
  const tCol2 = x0 + 48;     // Taxable Amt (60)
  const tCol3 = x0 + 108;    // CGST Rate (32)
  const tCol4 = x0 + 140;    // CGST Amt (42)
  const tCol5 = x0 + 182;    // SGST Rate (32)
  const tCol6 = x0 + 214;    // SGST Amt (42)

  doc.rect(x0, tcurY, taxSummaryWidth, tHeaderH).strokeColor('#94A3B8').lineWidth(0.5).stroke();
  [tCol2, tCol3, tCol4, tCol5, tCol6].forEach(x => {
    doc.moveTo(x, tcurY).lineTo(x, tcurY + tHeaderH).stroke();
  });

  doc.font(boldFont).fontSize(6.5).fillColor('#0F172A');
  doc.text('HSN/ SAC', tCol1, tcurY + 4, { width: 48, align: 'center' });
  doc.text(`Taxable (${curr})`, tCol2, tcurY + 4, { width: 60, align: 'center' });
  doc.text('CGST %', tCol3, tcurY + 4, { width: 32, align: 'center' });
  doc.text(`CGST (${curr})`, tCol4, tcurY + 4, { width: 42, align: 'center' });
  doc.text('SGST %', tCol5, tcurY + 4, { width: 32, align: 'center' });
  doc.text(`SGST (${curr})`, tCol6, tcurY + 4, { width: 42, align: 'center' });
  doc.text(`Tax (${curr})`, tCol6 + 42, tcurY + 4, { width: rightBoxX - (tCol6 + 42), align: 'center' });

  const cgstRate = (defaultTaxRate / 2).toFixed(1);
  const sgstRate = (defaultTaxRate / 2).toFixed(1);
  const halfTax = invoice.taxAmount / 2;
  const taxableAmt = invoice.subtotal - invoice.discount;

  const tRowH = 18;
  const trY = tcurY + tHeaderH;
  doc.rect(x0, trY, taxSummaryWidth, tRowH).strokeColor('#94A3B8').lineWidth(0.5).stroke();
  [tCol2, tCol3, tCol4, tCol5, tCol6].forEach(x => {
    doc.moveTo(x, trY).lineTo(x, trY + tRowH).stroke();
  });

  doc.font(normalFont).fontSize(6.5).fillColor('#0F172A');
  doc.text('995463', tCol1, trY + 5, { width: 48, align: 'center' });
  doc.text(`${curr} ${taxableAmt.toFixed(2)}`, tCol2 - 2, trY + 5, { width: 60, align: 'right' });
  doc.text(`${cgstRate}`, tCol3, trY + 5, { width: 32, align: 'center' });
  doc.text(`${curr} ${halfTax.toFixed(2)}`, tCol4 - 2, trY + 5, { width: 42, align: 'right' });
  doc.text(`${sgstRate}`, tCol5, trY + 5, { width: 32, align: 'center' });
  doc.text(`${curr} ${halfTax.toFixed(2)}`, tCol6 - 2, trY + 5, { width: 42, align: 'right' });
  doc.text(`${curr} ${invoice.taxAmount.toFixed(2)}`, tCol6 + 40, trY + 5, { width: rightBoxX - (tCol6 + 42), align: 'right' });

  // Total Tax Row
  const trTotalY = trY + tRowH;
  doc.rect(x0, trTotalY, taxSummaryWidth, tRowH).strokeColor('#94A3B8').lineWidth(0.5).stroke();
  [tCol2, tCol4, tCol6].forEach(x => {
    doc.moveTo(x, trTotalY).lineTo(x, trTotalY + tRowH).stroke();
  });
  doc.font(boldFont).fontSize(6.5).fillColor('#0F172A');
  doc.text('TOTAL', tCol1, trTotalY + 5, { width: 48, align: 'center' });
  doc.text(`${curr} ${taxableAmt.toFixed(2)}`, tCol2 - 2, trTotalY + 5, { width: 60, align: 'right' });
  doc.text(`${curr} ${halfTax.toFixed(2)}`, tCol4 - 2, trTotalY + 5, { width: 42, align: 'right' });
  doc.text(`${curr} ${halfTax.toFixed(2)}`, tCol6 - 2, trTotalY + 5, { width: 42, align: 'right' });
  doc.text(`${curr} ${invoice.taxAmount.toFixed(2)}`, tCol6 + 40, trTotalY + 5, { width: rightBoxX - (tCol6 + 42), align: 'right' });

  // --- Right: Sub Total, GST, Total, Words, Received, Balance ---
  let ry = curY + 6;
  doc.font(boldFont).fontSize(7.5).fillColor('#0F172A');
  doc.text('Sub Total', rightBoxX + 10, ry);
  doc.text(':', rightBoxX + 80, ry);
  doc.text(`${curr} ${invoice.subtotal.toFixed(2)}`, rightBoxX + 90, ry, { width: 140, align: 'right' });

  ry += 13;
  doc.text('GST (18%)', rightBoxX + 10, ry);
  doc.text(':', rightBoxX + 80, ry);
  doc.text(`${curr} ${invoice.taxAmount.toFixed(2)}`, rightBoxX + 90, ry, { width: 140, align: 'right' });

  ry += 13;
  doc.text('Total (Incl. GST)', rightBoxX + 10, ry);
  doc.text(':', rightBoxX + 80, ry);
  doc.text(`${curr} ${invoice.totalAmount.toFixed(2)}`, rightBoxX + 90, ry, { width: 140, align: 'right' });

  ry += 13;
  doc.font(boldFont).fontSize(7).text('Invoice Amount In Words :', rightBoxX + 10, ry);
  ry += 9;
  doc.font(normalFont).fontSize(7).fillColor('#334155').text(numberToIndianWords(invoice.totalAmount), rightBoxX + 10, ry, { width: rightBoxWidth - 20 });

  ry += 16;
  doc.font(boldFont).fontSize(7.5).fillColor('#0F172A');
  doc.text('Received', rightBoxX + 10, ry);
  doc.text(':', rightBoxX + 80, ry);
  doc.text(`${curr} ${invoice.paidAmount.toFixed(2)}`, rightBoxX + 90, ry, { width: 140, align: 'right' });

  ry += 13;
  const balanceDue = Math.max(0, invoice.totalAmount - invoice.paidAmount);
  doc.text('Balance', rightBoxX + 10, ry);
  doc.text(':', rightBoxX + 80, ry);
  doc.text(`${curr} ${balanceDue.toFixed(2)}`, rightBoxX + 90, ry, { width: 140, align: 'right' });

  curY += summaryBoxHeight;

  // 6. Terms And Conditions Box
  const termsBoxHeight = 32;
  doc.rect(x0, curY, tableWidth, termsBoxHeight).strokeColor('#64748B').lineWidth(0.8).stroke();
  doc.font(boldFont).fontSize(7.5).fillColor('#0F172A').text('Terms And Conditions:', x0 + 8, curY + 5);
  doc.font(normalFont).fontSize(7.5).fillColor('#334155').text('Thank you for doing business with us.', x0 + 8, curY + 17);

  curY += termsBoxHeight;

  // 7. Bank Details & Signature Section
  const footerBoxHeight = 84;
  doc.rect(x0, curY, tableWidth, footerBoxHeight).strokeColor('#64748B').lineWidth(0.8).stroke();
  doc.moveTo(splitX, curY).lineTo(splitX, curY + footerBoxHeight).stroke();

  // Left: Bank Details
  doc.font(boldFont).fontSize(8).fillColor('#0F172A').text('Bank Details:', x0 + 8, curY + 6);
  doc.font(normalFont).fontSize(7.5).fillColor('#334155');
  doc.text('Name: CITY UNION BANK 93 VILLIANUR ROAD,REDDIARPALAYAM', x0 + 8, curY + 19);
  doc.text('Account No.: 510909010146288', x0 + 8, curY + 32);
  doc.text('IFSC code: CIUB0000421', x0 + 8, curY + 45);
  doc.text('Account Holder\'s Name: CARING COOL TECH', x0 + 8, curY + 58);

  // Right: Authorized Signatory Stamp Box
  doc.font(boldFont).fontSize(8).fillColor('#0F172A').text('For CARING COOL TECH:', splitX + 8, curY + 6);

  // Blue Stamp Box
  const stampX = splitX + 60;
  const stampY = curY + 18;
  const stampW = 120;
  const stampH = 40;

  doc.rect(stampX, stampY, stampW, stampH).strokeColor('#1E75BB').lineWidth(1.2).stroke();
  doc.font(boldFont).fontSize(7.5).fillColor('#1E75BB')
     .text('For CARING COOL TECH', stampX, stampY + 4, { width: stampW, align: 'center' });

  // Stylized simulated signature curves
  doc.strokeColor('#1E75BB').lineWidth(1.2);
  doc.moveTo(stampX + 24, stampY + 22)
     .bezierCurveTo(stampX + 40, stampY + 12, stampX + 55, stampY + 30, stampX + 75, stampY + 18)
     .stroke();
  doc.moveTo(stampX + 50, stampY + 24)
     .bezierCurveTo(stampX + 65, stampY + 28, stampX + 85, stampY + 14, stampX + 96, stampY + 22)
     .stroke();

  doc.font(normalFont).fontSize(6).fillColor('#1E75BB')
     .text('Proprietor', stampX, stampY + 28, { width: stampW, align: 'right' });

  doc.font(normalFont).fontSize(7.5).fillColor('#334155')
     .text('Authorized Signatory', splitX + 8, curY + 66, { width: tableWidth - 265 - 16, align: 'center' });

  doc.end();
}
