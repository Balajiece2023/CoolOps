import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../providers/app_providers.dart';

class BillingView extends ConsumerWidget {
  const BillingView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoicesAsync = ref.watch(invoicesProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.refresh(invoicesProvider),
      child: invoicesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error loading billing: $err')),
        data: (invoices) {
          if (invoices.isEmpty) {
            return const Center(child: Text('No invoices recorded yet.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: invoices.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final inv = invoices[index];
              return _InvoiceCard(invoice: inv);
            },
          );
        },
      ),
    );
  }
}

class _InvoiceCard extends ConsumerWidget {
  final InvoiceModel invoice;

  const _InvoiceCard({required this.invoice});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUnpaid = invoice.status != 'PAID';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(invoice.invoiceNumber, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                _InvoiceStatusBadge(status: invoice.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(invoice.customerName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text('Contact: ${invoice.customerPhone} • Due: ${invoice.dueDate}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Amount', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    Text('₹${invoice.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Paid Amount', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    Text('₹${invoice.paidAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.accentEmerald)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Balance Due', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    Text('₹${invoice.balanceDue.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: invoice.balanceDue > 0 ? AppTheme.accentRose : AppTheme.accentEmerald)),
                  ],
                ),
              ],
            ),
            if (isUnpaid) ...[
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.payment, size: 14),
                  label: const Text('Record Payment', style: TextStyle(fontSize: 12)),
                  onPressed: () => _showRecordPaymentDialog(context, ref, invoice),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showRecordPaymentDialog(BuildContext context, WidgetRef ref, InvoiceModel inv) {
    final amountController = TextEditingController(text: inv.balanceDue.toStringAsFixed(0));
    final refController = TextEditingController(text: 'UPI-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');
    String selectedMethod = 'UPI';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Record Payment: ${inv.invoiceNumber}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Customer: ${inv.customerName}'),
              Text('Outstanding Balance: ₹${inv.balanceDue.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
              const SizedBox(height: 12),
              TextField(controller: amountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount (₹)')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedMethod,
                decoration: const InputDecoration(labelText: 'Payment Method'),
                items: const [
                  DropdownMenuItem(value: 'UPI', child: Text('UPI / GooglePay / PhonePe')),
                  DropdownMenuItem(value: 'CASH', child: Text('Cash Payment')),
                  DropdownMenuItem(value: 'CARD', child: Text('Credit / Debit Card')),
                  DropdownMenuItem(value: 'BANK_TRANSFER', child: Text('NEFT / IMPS')),
                ],
                onChanged: (val) => setDialogState(() => selectedMethod = val ?? 'UPI'),
              ),
              const SizedBox(height: 12),
              TextField(controller: refController, decoration: const InputDecoration(labelText: 'Transaction Reference / Receipt ID')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                try {
                  await ref.read(apiRepositoryProvider).recordPayment(
                        invoiceId: inv.id,
                        amount: double.tryParse(amountController.text) ?? inv.balanceDue,
                        paymentMethod: selectedMethod,
                        referenceNumber: refController.text.trim(),
                      );
                  if (ctx.mounted) Navigator.pop(ctx);
                  ref.refresh(invoicesProvider);
                  ref.refresh(dashboardStatsProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Payment recorded and ledger updated!')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Payment error: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Save Payment'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InvoiceStatusBadge extends StatelessWidget {
  final String status;
  const _InvoiceStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (status) {
      case 'PAID':
        bg = Colors.green.shade100;
        fg = Colors.green.shade900;
        break;
      case 'PARTIALLY_PAID':
        bg = Colors.amber.shade100;
        fg = Colors.amber.shade900;
        break;
      case 'ISSUED':
        bg = Colors.blue.shade100;
        fg = Colors.blue.shade900;
        break;
      default:
        bg = Colors.grey.shade200;
        fg = Colors.grey.shade800;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(status.replaceAll('_', ' '), style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
