import PDFDocument from 'pdfkit';
import { prisma } from '../prisma';
import { Response } from 'express';

export async function generateInvoicePdf(invoiceId: string, res: Response) {
  const invoice = await prisma.invoice.findUnique({
    where: { id: invoiceId },
    include: {
      customer: true,
      items: true,
      payments: true,
      serviceJob: {
        include: {
          booking: { include: { serviceType: true } }
        }
      }
    }
  });

  if (!invoice) {
    throw new Error('Invoice not found');
  }

  const doc = new PDFDocument({ margin: 40, size: 'A4' });

  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader('Content-Disposition', `attachment; filename="${invoice.invoiceNumber}.pdf"`);

  doc.pipe(res);

  // Header
  doc.fontSize(22).fillColor('#0284C7').text('FrostPro AC Solutions Pvt Ltd', 40, 40);
  doc.fontSize(10).fillColor('#64748B').text('104 Anna Salai, Guindy, Chennai, Tamil Nadu - 600032', 40, 68);
  doc.text('Phone: +91 98400 12345 | Email: billing@frostpro.in | GSTIN: 33AAAAA0000A1Z5', 40, 82);

  doc.strokeColor('#CBD5E1').lineWidth(1).moveTo(40, 105).lineTo(555, 105).stroke();

  // Invoice Details
  doc.fontSize(16).fillColor('#0F172A').text('TAX INVOICE', 40, 120);
  doc.fontSize(10).fillColor('#334155');
  doc.text(`Invoice No: ${invoice.invoiceNumber}`, 40, 142);
  doc.text(`Invoice Date: ${new Date(invoice.createdAt).toLocaleDateString()}`, 40, 156);
  doc.text(`Due Date: ${new Date(invoice.dueDate).toLocaleDateString()}`, 40, 170);
  doc.text(`Status: ${invoice.status}`, 40, 184);

  // Billed To
  doc.fontSize(12).fillColor('#0F172A').text('Billed To:', 320, 120);
  doc.fontSize(10).fillColor('#334155');
  doc.text(`Customer: ${invoice.customer.name}`, 320, 142);
  doc.text(`Phone: ${invoice.customer.phone}`, 320, 156);
  if (invoice.customer.email) doc.text(`Email: ${invoice.customer.email}`, 320, 170);

  // Items Table Header
  let y = 220;
  doc.rect(40, y, 515, 24).fill('#F1F5F9');
  doc.fontSize(10).fillColor('#0F172A');
  doc.text('#', 50, y + 7);
  doc.text('Description', 80, y + 7);
  doc.text('Qty', 350, y + 7);
  doc.text('Unit Price', 410, y + 7);
  doc.text('Total', 490, y + 7);

  y += 28;
  // Items Rows
  invoice.items.forEach((item, index) => {
    doc.fillColor('#334155');
    doc.text(String(index + 1), 50, y);
    doc.text(item.description, 80, y, { width: 250 });
    doc.text(String(item.quantity), 350, y);
    doc.text(`₹${item.unitPrice.toFixed(2)}`, 410, y);
    doc.text(`₹${item.totalPrice.toFixed(2)}`, 490, y);
    y += 22;
  });

  doc.strokeColor('#E2E8F0').lineWidth(0.5).moveTo(40, y + 5).lineTo(555, y + 5).stroke();
  y += 15;

  // Calculation Summary
  doc.fontSize(10).fillColor('#475569');
  doc.text(`Subtotal:`, 380, y);
  doc.text(`₹${invoice.subtotal.toFixed(2)}`, 490, y);
  y += 18;

  if (invoice.discount > 0) {
    doc.text(`Discount:`, 380, y);
    doc.text(`- ₹${invoice.discount.toFixed(2)}`, 490, y);
    y += 18;
  }

  doc.text(`GST (${invoice.taxRate}%):`, 380, y);
  doc.text(`₹${invoice.taxAmount.toFixed(2)}`, 490, y);
  y += 18;

  doc.fontSize(12).fillColor('#0F172A').text(`Total Amount:`, 380, y);
  doc.text(`₹${invoice.totalAmount.toFixed(2)}`, 490, y);
  y += 22;

  doc.fontSize(10).fillColor('#16A34A').text(`Paid Amount:`, 380, y);
  doc.text(`₹${invoice.paidAmount.toFixed(2)}`, 490, y);
  y += 18;

  const balance = Math.max(0, invoice.totalAmount - invoice.paidAmount);
  doc.fontSize(11).fillColor(balance > 0 ? '#DC2626' : '#16A34A').text(`Balance Due:`, 380, y);
  doc.text(`₹${balance.toFixed(2)}`, 490, y);

  // Footer notes
  doc.fontSize(9).fillColor('#94A3B8').text('This is a computer generated invoice and requires no physical signature.', 40, 750, { align: 'center', width: 515 });

  doc.end();
}
