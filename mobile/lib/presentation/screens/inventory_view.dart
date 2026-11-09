import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../providers/app_providers.dart';

class InventoryView extends ConsumerStatefulWidget {
  const InventoryView({super.key});

  @override
  ConsumerState<InventoryView> createState() => _InventoryViewState();
}

class _InventoryViewState extends ConsumerState<InventoryView> {
  bool _lowStockOnly = false;

  void _showAddPartDialog() {
    final nameCtrl = TextEditingController();
    final skuCtrl = TextEditingController(text: 'PRT-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}');
    final categoryCtrl = TextEditingController(text: 'SPARE_PART');
    final stockCtrl = TextEditingController(text: '10');
    final minAlertCtrl = TextEditingController(text: '5');
    final unitPriceCtrl = TextEditingController(text: '250.00');
    final sellingPriceCtrl = TextEditingController(text: '450.00');
    final supplierCtrl = TextEditingController(text: 'Chennai AC Spares Hub');
    bool isSaving = false;
    String? errorMsg;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.accentEmerald.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.add_business_rounded, color: AppTheme.accentEmerald, size: 22),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Add New Inventory Part', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (errorMsg != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(errorMsg!, style: TextStyle(color: Colors.red.shade800, fontSize: 12)),
                    ),
                  ],
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Part / Spare Name *', hintText: 'e.g. 45uF Running Capacitor', prefixIcon: Icon(Icons.label_outline, size: 20)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: skuCtrl,
                          decoration: const InputDecoration(labelText: 'SKU Code *', hintText: 'e.g. CAP-45UF', prefixIcon: Icon(Icons.qr_code, size: 20)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: categoryCtrl,
                          decoration: const InputDecoration(labelText: 'Category *', hintText: 'e.g. ELECTRICAL', prefixIcon: Icon(Icons.category_outlined, size: 20)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: stockCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Initial Stock *', prefixIcon: Icon(Icons.inventory_2_outlined, size: 20)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: minAlertCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Min Alert Level *', prefixIcon: Icon(Icons.notifications_active_outlined, size: 20)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: unitPriceCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Cost Price (₹) *', prefixIcon: Icon(Icons.currency_rupee, size: 20)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: sellingPriceCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Selling Price (₹) *', prefixIcon: Icon(Icons.sell_outlined, size: 20)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: supplierCtrl,
                    decoration: const InputDecoration(labelText: 'Supplier / Vendor Name', hintText: 'e.g. Voltas Genuine Spares', prefixIcon: Icon(Icons.business_outlined, size: 20)),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentEmerald, foregroundColor: Colors.white),
              onPressed: isSaving
                  ? null
                  : () async {
                      final name = nameCtrl.text.trim();
                      final sku = skuCtrl.text.trim();
                      final category = categoryCtrl.text.trim();
                      final stock = int.tryParse(stockCtrl.text.trim());
                      final minAlert = int.tryParse(minAlertCtrl.text.trim());
                      final unitPrice = double.tryParse(unitPriceCtrl.text.trim());
                      final sellingPrice = double.tryParse(sellingPriceCtrl.text.trim());

                      if (name.isEmpty || sku.isEmpty || category.isEmpty || stock == null || minAlert == null || unitPrice == null || sellingPrice == null) {
                        setDlgState(() => errorMsg = 'Please fill all mandatory fields with valid numbers.');
                        return;
                      }

                      setDlgState(() {
                        isSaving = true;
                        errorMsg = null;
                      });

                      try {
                        final repo = ref.read(apiRepositoryProvider);
                        await repo.createInventoryPart(
                          sku: sku,
                          name: name,
                          category: category,
                          unitPrice: unitPrice,
                          sellingPrice: sellingPrice,
                          currentStock: stock,
                          minStockAlertLevel: minAlert,
                          supplierName: supplierCtrl.text.trim().isNotEmpty ? supplierCtrl.text.trim() : null,
                        );

                        ref.refresh(inventoryPartsProvider(_lowStockOnly));

                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('🎉 Item "$name" added to inventory successfully!'),
                              backgroundColor: AppTheme.accentEmerald,
                            ),
                          );
                        }
                      } catch (e) {
                        setDlgState(() {
                          isSaving = false;
                          errorMsg = 'Failed to add part: $e';
                        });
                      }
                    },
              child: isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Add Part to Stock'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditPartDialog(InventoryPartModel part) {
    final nameCtrl = TextEditingController(text: part.name);
    final skuCtrl = TextEditingController(text: part.sku);
    final categoryCtrl = TextEditingController(text: part.category);
    final stockCtrl = TextEditingController(text: part.currentStock.toString());
    final minAlertCtrl = TextEditingController(text: part.minAlert.toString());
    final unitPriceCtrl = TextEditingController(text: part.unitPrice.toStringAsFixed(2));
    final sellingPriceCtrl = TextEditingController(text: part.sellingPrice.toStringAsFixed(2));
    final supplierCtrl = TextEditingController(text: part.supplier ?? '');
    bool isSaving = false;
    String? errorMsg;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.edit_note_rounded, color: AppTheme.primaryBlue, size: 22),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Edit Inventory Item', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (errorMsg != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(errorMsg!, style: TextStyle(color: Colors.red.shade800, fontSize: 12)),
                    ),
                  ],
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Item Name *', prefixIcon: Icon(Icons.label_outline, size: 20)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: skuCtrl,
                          decoration: const InputDecoration(labelText: 'SKU Code *', prefixIcon: Icon(Icons.qr_code, size: 20)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: categoryCtrl,
                          decoration: const InputDecoration(labelText: 'Category *', prefixIcon: Icon(Icons.category_outlined, size: 20)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: stockCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Current Stock *', prefixIcon: Icon(Icons.inventory_2_outlined, size: 20)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: minAlertCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Min Alert Level *', prefixIcon: Icon(Icons.notifications_active_outlined, size: 20)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: unitPriceCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Cost Price (₹)', prefixIcon: Icon(Icons.currency_rupee, size: 20)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: sellingPriceCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Selling Price (₹) *', prefixIcon: Icon(Icons.sell_outlined, size: 20)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: supplierCtrl,
                    decoration: const InputDecoration(labelText: 'Supplier / Vendor', prefixIcon: Icon(Icons.business_outlined, size: 20)),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final name = nameCtrl.text.trim();
                      final sku = skuCtrl.text.trim();
                      final category = categoryCtrl.text.trim();
                      final stock = int.tryParse(stockCtrl.text.trim());
                      final minAlert = int.tryParse(minAlertCtrl.text.trim());
                      final unitPrice = double.tryParse(unitPriceCtrl.text.trim()) ?? 0.0;
                      final sellingPrice = double.tryParse(sellingPriceCtrl.text.trim());

                      if (name.isEmpty || sku.isEmpty || category.isEmpty || stock == null || minAlert == null || sellingPrice == null) {
                        setDlgState(() => errorMsg = 'Please fill in all mandatory fields with valid numbers.');
                        return;
                      }

                      setDlgState(() {
                        isSaving = true;
                        errorMsg = null;
                      });

                      try {
                        final repo = ref.read(apiRepositoryProvider);
                        await repo.updateInventoryPart(
                          id: part.id,
                          name: name,
                          sku: sku,
                          category: category,
                          currentStock: stock,
                          minStockAlertLevel: minAlert,
                          unitPrice: unitPrice,
                          sellingPrice: sellingPrice,
                          supplierName: supplierCtrl.text.trim().isNotEmpty ? supplierCtrl.text.trim() : null,
                        );

                        ref.refresh(inventoryPartsProvider(_lowStockOnly));

                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('✅ Inventory item "$name" updated successfully!'),
                              backgroundColor: AppTheme.accentEmerald,
                            ),
                          );
                        }
                      } catch (e) {
                        setDlgState(() {
                          isSaving = false;
                          errorMsg = 'Failed to update item: $e';
                        });
                      }
                    },
              child: isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeletePart(InventoryPartModel part) {
    bool isDeleting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.delete_forever, color: Colors.red, size: 22),
              ),
              const SizedBox(width: 10),
              const Text('Delete Inventory Part', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            ],
          ),
          content: Text(
            'Are you sure you want to delete or deactivate "${part.name}" (SKU: ${part.sku})?\n\nThis will remove it from active stock selections.',
            style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
          ),
          actions: [
            TextButton(
              onPressed: isDeleting ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: isDeleting
                  ? null
                  : () async {
                      setDlgState(() => isDeleting = true);
                      try {
                        final repo = ref.read(apiRepositoryProvider);
                        await repo.deleteInventoryPart(part.id);
                        ref.refresh(inventoryPartsProvider(_lowStockOnly));
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Item "${part.name}" deleted successfully.'),
                              backgroundColor: Colors.red.shade700,
                            ),
                          );
                        }
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('Deletion failed: $e'), backgroundColor: Colors.red),
                          );
                          Navigator.pop(ctx);
                        }
                      }
                    },
              child: isDeleting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Confirm Delete'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final partsAsync = ref.watch(inventoryPartsProvider(_lowStockOnly));
    final currentUser = ref.watch(authStateProvider);
    final isAdmin = currentUser?.role == UserRole.admin;

    return Scaffold(
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              backgroundColor: AppTheme.accentEmerald,
              icon: const Icon(Icons.add_shopping_cart_rounded, color: Colors.white),
              label: const Text('Add New Part', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: _showAddPartDialog,
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Warehouse Stock & Spares', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 2),
                          Text(
                            isAdmin ? 'Admin Edit & Stock Management Active' : 'Real-time Stock Levels',
                            style: TextStyle(
                              fontSize: 11,
                              color: isAdmin ? AppTheme.primaryBlue : const Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isAdmin)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentEmerald,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Part', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: _showAddPartDialog,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    FilterChip(
                      avatar: Icon(
                        _lowStockOnly ? Icons.warning_amber_rounded : Icons.inventory_2_outlined,
                        size: 14,
                        color: _lowStockOnly ? AppTheme.accentRose : const Color(0xFF64748B),
                      ),
                      label: const Text('Low Stock Alerts Only', style: TextStyle(fontSize: 11)),
                      selected: _lowStockOnly,
                      onSelected: (val) => setState(() => _lowStockOnly = val),
                      selectedColor: AppTheme.accentRose.withOpacity(0.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ],
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
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  itemCount: parts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final part = parts[index];
                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: part.isLowStock ? Colors.red.shade200 : Colors.transparent,
                          width: 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: part.isLowStock ? Colors.red.shade50 : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
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
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(part.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'SKU: ${part.sku} • Category: ${part.category}',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                  ),
                                  if (part.supplier != null && part.supplier!.isNotEmpty)
                                    Text('Supplier: ${part.supplier}', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${part.currentStock} in stock',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: part.isLowStock ? Colors.red : const Color(0xFF0F172A),
                                  ),
                                ),
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
                            if (isAdmin) ...[
                              const SizedBox(width: 8),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, size: 20, color: Color(0xFF64748B)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                onSelected: (action) {
                                  if (action == 'edit') {
                                    _showEditPartDialog(part);
                                  } else if (action == 'delete') {
                                    _confirmDeletePart(part);
                                  }
                                },
                                itemBuilder: (ctx) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit_outlined, size: 18, color: AppTheme.primaryBlue),
                                        SizedBox(width: 8),
                                        Text('Edit Item', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text('Delete Part', style: TextStyle(fontSize: 13, color: Colors.red, fontWeight: FontWeight.w500)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
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
    ),
  );
}
}
