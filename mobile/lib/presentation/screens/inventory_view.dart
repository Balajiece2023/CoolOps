import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../providers/app_providers.dart';

class InventoryView extends ConsumerStatefulWidget {
  const InventoryView({super.key});

  @override
  ConsumerState<InventoryView> createState() => _InventoryViewState();
}

class _InventoryViewState extends ConsumerState<InventoryView> {
  bool _lowStockOnly = false;

  @override
  Widget build(BuildContext context) {
    final partsAsync = ref.watch(inventoryPartsProvider(_lowStockOnly));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Warehouse Stock & Spares', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              FilterChip(
                label: const Text('Low Stock Alerts Only', style: TextStyle(fontSize: 12)),
                selected: _lowStockOnly,
                onSelected: (val) => setState(() => _lowStockOnly = val),
                selectedColor: AppTheme.accentRose.withOpacity(0.2),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => ref.refresh(inventoryPartsProvider(_lowStockOnly)),
            child: partsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error loading inventory: $err')),
              data: (parts) {
                if (parts.isEmpty) {
                  return const Center(child: Text('No inventory records found.'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: parts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final part = parts[index];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: part.isLowStock ? Colors.red.shade50 : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                part.isLowStock ? Icons.warning_amber_rounded : Icons.precision_manufacturing_outlined,
                                color: part.isLowStock ? Colors.red : AppTheme.primaryBlue,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(part.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  Text('SKU: ${part.sku} • Category: ${part.category}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                  if (part.supplier != null)
                                    Text('Supplier: ${part.supplier}', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('${part.currentStock} in stock', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: part.isLowStock ? Colors.red : const Color(0xFF0F172A))),
                                Text('₹${part.sellingPrice.toStringAsFixed(0)} / unit', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                if (part.isLowStock)
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(4)),
                                    child: const Text('REORDER', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.red)),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
