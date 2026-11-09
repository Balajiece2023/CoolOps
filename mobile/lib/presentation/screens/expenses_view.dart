import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../providers/app_providers.dart';

/// Day-to-Day Technician Expense Tracker & Admin Cash Float Management
class ExpensesView extends ConsumerStatefulWidget {
  const ExpensesView({super.key});

  @override
  ConsumerState<ExpensesView> createState() => _ExpensesViewState();
}

class _ExpensesViewState extends ConsumerState<ExpensesView> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _expenses = [];
  Map<String, dynamic> _summary = {};
  String _selectedCategory = 'ALL';
  String? _selectedTechId;
  List<Map<String, dynamic>> _technicians = [];

  final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(apiRepositoryProvider);
      final user = ref.read(authStateProvider);

      if (user?.role == UserRole.admin || user?.role == UserRole.accountant) {
        final techs = await repo.getAllTechnicians();
        setState(() => _technicians = techs);
      }

      final res = await repo.getExpenses(
        category: _selectedCategory == 'ALL' ? null : _selectedCategory,
        userId: _selectedTechId,
      );

      final items = (res['items'] as List?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
      final summary = Map<String, dynamic>.from(res['summary'] ?? {});

      if (mounted) {
        setState(() {
          _expenses = items;
          _summary = summary;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load expenses: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showAddExpenseDialog() {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String category = 'FUEL';
    DateTime selectedDate = DateTime.now();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.receipt_long_rounded, color: AppTheme.primaryBlue),
              SizedBox(width: 8),
              Text('Log Field Expense', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'Expense Category *'),
                  items: const [
                    DropdownMenuItem(value: 'FUEL', child: Text('⛽ Fuel / Petrol')),
                    DropdownMenuItem(value: 'FOOD', child: Text('🍱 Food & Refreshments')),
                    DropdownMenuItem(value: 'SPARES', child: Text('🛠️ Spares & Consumables (Tape, Screws)')),
                    DropdownMenuItem(value: 'PARKING', child: Text('🅿️ Parking & Tolls')),
                    DropdownMenuItem(value: 'TOOLS', child: Text('🧰 Tools & Maintenance')),
                    DropdownMenuItem(value: 'OTHER', child: Text('📦 Other Miscellaneous')),
                  ],
                  onChanged: (val) => setDialogState(() => category = val ?? 'FUEL'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Amount Spent (₹) *',
                    prefixText: '₹ ',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Description / Purpose *',
                    hintText: 'e.g. Petrol 2L for Anna Nagar travel',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(DateFormat('dd MMM yyyy').format(selectedDate), style: const TextStyle(fontSize: 13)),
                    const Spacer(),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: selectedDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 30)),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setDialogState(() => selectedDate = picked);
                        }
                      },
                      child: const Text('Change Date'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final amount = double.tryParse(amountCtrl.text.trim());
                      final desc = descCtrl.text.trim();
                      if (amount == null || amount <= 0 || desc.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Please enter a valid amount and description')),
                        );
                        return;
                      }

                      setDialogState(() => isSaving = true);
                      try {
                        await ref.read(apiRepositoryProvider).createExpense(
                              category: category,
                              amount: amount,
                              description: desc,
                              expenseDate: selectedDate.toIso8601String(),
                            );
                        if (ctx.mounted) Navigator.pop(ctx);
                        _loadData();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('✅ Expense logged successfully!'), backgroundColor: Color(0xFF16A34A)),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    },
              child: isSaving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save Expense'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAllocateFloatDialog() {
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController(text: 'Weekly float advance');
    String? targetUserId;
    bool isSaving = false;

    if (_technicians.isNotEmpty) {
      targetUserId = _technicians.first['user']?['id'];
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF16A34A)),
              SizedBox(width: 8),
              Text('Allocate Cash Float', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  value: targetUserId,
                  decoration: const InputDecoration(labelText: 'Select Technician *'),
                  items: _technicians.map((t) {
                    final u = t['user'] ?? {};
                    return DropdownMenuItem<String>(
                      value: u['id'],
                      child: Text('${u['name']} (${u['phone'] ?? 'Tech'})', overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (val) => setDialogState(() => targetUserId = val),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Float Amount Given (₹) *',
                    prefixText: '₹ ',
                    hintText: 'e.g. 2000',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Notes / Purpose',
                    hintText: 'e.g. Fuel & tools float for week',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
              onPressed: isSaving
                  ? null
                  : () async {
                      final amount = double.tryParse(amountCtrl.text.trim());
                      if (targetUserId == null || amount == null || amount <= 0) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Please select technician and enter valid float amount')),
                        );
                        return;
                      }

                      setDialogState(() => isSaving = true);
                      try {
                        await ref.read(apiRepositoryProvider).createExpense(
                              category: 'ADVANCE',
                              amount: amount,
                              description: notesCtrl.text.trim(),
                              targetUserId: targetUserId,
                            );
                        if (ctx.mounted) Navigator.pop(ctx);
                        _loadData();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('💵 Cash float credited to technician!'), backgroundColor: Color(0xFF16A34A)),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    },
              child: isSaving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Credit Float'),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String cat) {
    switch (cat.toUpperCase()) {
      case 'ADVANCE':
      case 'FLOAT':
        return Icons.account_balance_wallet_rounded;
      case 'FUEL':
        return Icons.local_gas_station_rounded;
      case 'FOOD':
        return Icons.restaurant_rounded;
      case 'SPARES':
        return Icons.build_rounded;
      case 'PARKING':
        return Icons.local_parking_rounded;
      case 'TOOLS':
        return Icons.home_repair_service_rounded;
      default:
        return Icons.receipt_rounded;
    }
  }

  Color _getCategoryColor(String cat) {
    switch (cat.toUpperCase()) {
      case 'ADVANCE':
      case 'FLOAT':
        return const Color(0xFF16A34A);
      case 'FUEL':
        return const Color(0xFFEA580C);
      case 'FOOD':
        return const Color(0xFFD97706);
      case 'SPARES':
        return AppTheme.primaryBlue;
      case 'PARKING':
        return const Color(0xFF0284C7);
      case 'TOOLS':
        return const Color(0xFF7C3AED);
      default:
        return const Color(0xFF64748B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider);
    final isAdmin = user?.role == UserRole.admin || user?.role == UserRole.accountant;

    final totalAdv = (_summary['totalAdvance'] as num?)?.toDouble() ?? 0.0;
    final totalSpent = (_summary['totalSpent'] as num?)?.toDouble() ?? 0.0;
    final remaining = (_summary['remainingBalance'] as num?)?.toDouble() ?? (totalAdv - totalSpent);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Expenses & Float Tracker', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loadData,
          ),
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.add_card_rounded, color: Color(0xFF16A34A)),
              tooltip: 'Allocate Float',
              onPressed: _showAllocateFloatDialog,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryBlue,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Log Expense', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        onPressed: _showAddExpenseDialog,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                children: [
                  // 1. Consolidated Float & Expense Card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: remaining >= 0
                            ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                            : [const Color(0xFF450A0A), const Color(0xFF1E293B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isAdmin ? 'COMPANY CASH FLOAT BALANCE' : 'MY ACTIVE WALLET FLOAT',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), letterSpacing: 0.5),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: remaining >= 0 ? const Color(0xFF16A34A).withOpacity(0.2) : const Color(0xFFDC2626).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: remaining >= 0 ? const Color(0xFF16A34A) : const Color(0xFFDC2626), width: 0.8),
                              ),
                              child: Text(
                                remaining >= 0 ? 'ACTIVE FLOAT' : 'FLOAT OVERDUE',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: remaining >= 0 ? const Color(0xFF4ADE80) : const Color(0xFFF87171)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _currencyFormat.format(remaining),
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: remaining >= 0 ? Colors.white : const Color(0xFFFCA5A5),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Divider(color: Color(0xFF334155), height: 1),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Advance Given', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                                  const SizedBox(height: 2),
                                  Text(
                                    _currencyFormat.format(totalAdv),
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF4ADE80)),
                                  ),
                                ],
                              ),
                            ),
                            Container(width: 1, height: 32, color: const Color(0xFF334155)),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Total Spent', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                                  const SizedBox(height: 2),
                                  Text(
                                    _currencyFormat.format(totalSpent),
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFFF87171)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. Admin Technician Filter (if Admin)
                  if (isAdmin && _technicians.isNotEmpty) ...[
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ChoiceChip(
                            label: const Text('All Technicians'),
                            selected: _selectedTechId == null,
                            onSelected: (_) {
                              setState(() => _selectedTechId = null);
                              _loadData();
                            },
                          ),
                          const SizedBox(width: 8),
                          ..._technicians.map((t) {
                            final u = t['user'] ?? {};
                            final isSel = _selectedTechId == u['id'];
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(u['name'] ?? 'Tech'),
                                selected: isSel,
                                onSelected: (_) {
                                  setState(() => _selectedTechId = u['id']);
                                  _loadData();
                                },
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // 3. Category Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('ALL', 'All Records'),
                        _buildFilterChip('FUEL', '⛽ Fuel'),
                        _buildFilterChip('FOOD', '🍱 Food'),
                        _buildFilterChip('SPARES', '🛠️ Spares'),
                        _buildFilterChip('PARKING', '🅿️ Parking'),
                        _buildFilterChip('TOOLS', '🧰 Tools'),
                        _buildFilterChip('ADVANCE', '🟢 Float Received'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 4. Section Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Expense & Float History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Text('${_expenses.length} entries', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // 5. Expense Entries List
                  if (_expenses.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(36),
                      alignment: Alignment.center,
                      child: Column(
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 10),
                          const Text('No expense records logged yet.', style: TextStyle(color: Color(0xFF64748B))),
                          const SizedBox(height: 4),
                          const Text('Tap "Log Expense" below to record field fuel, tea, or spares.', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                        ],
                      ),
                    )
                  else
                    ..._expenses.map((exp) {
                      final cat = (exp['category'] as String?) ?? 'OTHER';
                      final isAdv = cat == 'ADVANCE' || cat == 'FLOAT';
                      final amount = (exp['amount'] as num?)?.toDouble() ?? 0.0;
                      final desc = (exp['description'] as String?) ?? 'Expense';
                      final dateStr = (exp['expenseDate'] as String?) ?? exp['createdAt'] as String?;
                      final dt = dateStr != null ? DateTime.tryParse(dateStr)?.toLocal() : null;

                      final color = _getCategoryColor(cat);
                      final icon = _getCategoryIcon(cat);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: isAdv ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0)),
                        ),
                        color: isAdv ? const Color(0xFFF0FDF4) : Colors.white,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(icon, color: color, size: 20),
                          ),
                          title: Row(
                            children: [
                              Text(
                                isAdv ? 'Advance Float Received' : cat,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: isAdv ? const Color(0xFF15803D) : const Color(0xFF0F172A),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                isAdv ? '+${_currencyFormat.format(amount)}' : '-${_currencyFormat.format(amount)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: isAdv ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 3),
                              Text(desc, style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
                              const SizedBox(height: 2),
                              if (dt != null)
                                Text(
                                  DateFormat('dd MMM yyyy, hh:mm a').format(dt),
                                  style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                                ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFF94A3B8)),
                            tooltip: 'Delete entry',
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Delete Expense?'),
                                  content: const Text('Are you sure you want to remove this expense entry?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await ref.read(apiRepositoryProvider).deleteExpense(exp['id']);
                                _loadData();
                              }
                            },
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedCategory == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (sel) {
          setState(() => _selectedCategory = value);
          _loadData();
        },
      ),
    );
  }
}

