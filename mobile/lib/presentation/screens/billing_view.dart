import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../providers/app_providers.dart';

class BillingView extends ConsumerStatefulWidget {
  const BillingView({super.key});

  @override
  ConsumerState<BillingView> createState() => _BillingViewState();
}

class _BillingViewState extends ConsumerState<BillingView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedBillFilter = 'ALL'; // ALL, ON_HOLD, PARTIAL, SETTLED
  String _selectedExpenseCategory = 'ALL';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider);
    final canManageFinancials = user?.role == UserRole.admin || user?.role == UserRole.accountant;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2)),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: TabBar(
              controller: _tabController,
              labelColor: AppTheme.primaryBlue,
              unselectedLabelColor: const Color(0xFF64748B),
              indicatorColor: AppTheme.primaryBlue,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              tabs: const [
                Tab(icon: Icon(Icons.analytics_outlined, size: 20), text: 'Consol Overview'),
                Tab(icon: Icon(Icons.receipt_long_outlined, size: 20), text: 'Bills & Settlement'),
                Tab(icon: Icon(Icons.account_balance_wallet_outlined, size: 20), text: 'Expense Tracker'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildConsolOverviewTab(canManageFinancials),
          _buildBillsTab(canManageFinancials),
          _buildExpensesTab(canManageFinancials),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 1: CONSOLIDATED FINANCIAL DASHBOARD ("CONSOL" PAGE)
  // =========================================================================
  Widget _buildConsolOverviewTab(bool canManage) {
    final consolAsync = ref.watch(consolBillingProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.refresh(consolBillingProvider);
        ref.refresh(invoicesProvider);
        ref.refresh(expensesProvider(null));
      },
      child: consolAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text('Error loading financial consolidation: $err', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => ref.refresh(consolBillingProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (data) {
          final summary = data['summary'] as Map<String, dynamic>? ?? {};
          final categorised = data['categorisedIncome'] as Map<String, dynamic>? ?? {};
          final fully = categorised['fullySettled'] as Map<String, dynamic>? ?? {};
          final partial = categorised['partiallySettled'] as Map<String, dynamic>? ?? {};
          final onHold = categorised['completelyOnHold'] as Map<String, dynamic>? ?? {};
          final expensesByCat = (data['expensesByCategory'] as List? ?? []).cast<Map<String, dynamic>>();
          final recentSettlements = (data['recentSettlements'] as List? ?? []).cast<Map<String, dynamic>>();

          final totalIncome = (summary['totalIncome'] as num?)?.toDouble() ?? 0.0;
          final received = (summary['receivedAmount'] as num?)?.toDouble() ?? 0.0;
          final onHoldAmount = (summary['onHoldAmount'] as num?)?.toDouble() ?? 0.0;
          final expenses = (summary['totalExpenses'] as num?)?.toDouble() ?? 0.0;
          final netCash = (summary['netCashFlow'] as num?)?.toDouble() ?? 0.0;
          final rate = summary['settlementRate'] ?? 0;

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Header Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.accentEmerald.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.payments_rounded, color: AppTheme.accentEmerald, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Consolidated Financial Ledger',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            Text(
                              'Real-time tracking of received income vs on-hold settlements',
                              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.accentEmerald,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$rate% Settled',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Primary Financial Metrics Grid
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        title: 'Total Billed Income',
                        amount: totalIncome,
                        icon: Icons.receipt_long,
                        accentColor: AppTheme.primaryBlue,
                        subtext: '${summary['invoicesCount'] ?? 0} invoices issued',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        title: 'Received / Settled',
                        amount: received,
                        icon: Icons.check_circle_outline,
                        accentColor: AppTheme.accentEmerald,
                        subtext: 'Cash in hand & bank',
                        isHighlight: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        title: 'On-Hold Remaining',
                        amount: onHoldAmount,
                        icon: Icons.hourglass_top_rounded,
                        accentColor: AppTheme.accentAmber,
                        subtext: 'Pending client settlements',
                        isWarning: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        title: 'Total Expenses',
                        amount: expenses,
                        icon: Icons.trending_down_rounded,
                        accentColor: AppTheme.accentRose,
                        subtext: '${summary['expensesCount'] ?? 0} logged entries',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Net Cash Flow Banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: netCash >= 0 ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                    border: Border.all(
                      color: netCash >= 0 ? const Color(0xFF86EFAC) : const Color(0xFFFECACA),
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        netCash >= 0 ? Icons.savings_outlined : Icons.warning_amber_rounded,
                        color: netCash >= 0 ? AppTheme.accentEmerald : AppTheme.accentRose,
                        size: 28,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Net Cash Flow (Received - Expenses)',
                              style: TextStyle(
                                fontSize: 12,
                                color: netCash >= 0 ? const Color(0xFF166534) : const Color(0xFF991B1B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '₹${netCash.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: netCash >= 0 ? const Color(0xFF14532D) : const Color(0xFF7F1D1D),
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.primaryBlue,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        ),
                        icon: const Icon(Icons.arrow_forward, size: 16),
                        label: const Text('View Bills', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: () => _tabController.animateTo(1),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Income Categorization: Received vs On-Hold Breakdown
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.pie_chart_outline_rounded, size: 20, color: AppTheme.primaryBlue),
                            SizedBox(width: 8),
                            Text(
                              'Settlement Status Breakdown',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Categorization of total billing by settlement completion',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 16),

                        // Progress bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            height: 12,
                            child: Row(
                              children: [
                                if (totalIncome > 0 && received > 0)
                                  Expanded(
                                    flex: (received / totalIncome * 100).round().clamp(1, 100),
                                    child: Container(color: AppTheme.accentEmerald),
                                  ),
                                if (totalIncome > 0 && onHoldAmount > 0)
                                  Expanded(
                                    flex: (onHoldAmount / totalIncome * 100).round().clamp(1, 100),
                                    child: Container(color: AppTheme.accentAmber),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // 3 Breakdown Rows
                        _buildCategoryBreakdownRow(
                          title: 'Fully Settled Invoices',
                          badgeText: '${fully['count'] ?? 0} bills',
                          badgeColor: Colors.green.shade100,
                          badgeTextColor: Colors.green.shade900,
                          valueText: '₹${((fully['amount'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)}',
                          statusSubtitle: 'Paid in full',
                          icon: Icons.check_circle,
                          iconColor: AppTheme.accentEmerald,
                        ),
                        const Divider(height: 20),
                        _buildCategoryBreakdownRow(
                          title: 'Partially Settled Invoices',
                          badgeText: '${partial['count'] ?? 0} bills',
                          badgeColor: Colors.amber.shade100,
                          badgeTextColor: Colors.amber.shade900,
                          valueText: 'Recv: ₹${((partial['received'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)}',
                          statusSubtitle: 'Remaining On-Hold: ₹${((partial['onHoldRemaining'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)}',
                          icon: Icons.timelapse,
                          iconColor: AppTheme.accentAmber,
                        ),
                        const Divider(height: 20),
                        _buildCategoryBreakdownRow(
                          title: 'Completely On-Hold Invoices',
                          badgeText: '${onHold['count'] ?? 0} bills',
                          badgeColor: Colors.blue.shade100,
                          badgeTextColor: Colors.blue.shade900,
                          valueText: '₹${((onHold['amount'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)}',
                          statusSubtitle: 'Zero settlement received yet',
                          icon: Icons.pending_actions,
                          iconColor: AppTheme.primaryBlue,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Expense Breakdown by Category
                if (expensesByCat.isNotEmpty) ...[
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.category_outlined, size: 20, color: AppTheme.accentRose),
                                  SizedBox(width: 8),
                                  Text('Expense Distribution', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              TextButton(
                                onPressed: () => _tabController.animateTo(2),
                                child: const Text('Manage Expenses', style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ...expensesByCat.map((c) {
                            final catName = c['category'] ?? 'OTHER';
                            final total = (c['totalAmount'] as num?)?.toDouble() ?? 0.0;
                            final pct = c['percentage'] ?? 0;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(catName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                      Text('₹${total.toStringAsFixed(2)} ($pct%)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.accentRose)),
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: (pct / 100).clamp(0.0, 1.0),
                                      backgroundColor: Colors.grey.shade100,
                                      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accentRose),
                                      minHeight: 6,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Recent Settlements Activity
                if (recentSettlements.isNotEmpty) ...[
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.history_rounded, size: 20, color: AppTheme.accentEmerald),
                              SizedBox(width: 8),
                              Text('Recent Settlement Payments', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ...recentSettlements.map((s) {
                            final rct = s['receiptNumber'] ?? '';
                            final amt = (s['amount'] as num?)?.toDouble() ?? 0.0;
                            final method = s['paymentMethod'] ?? 'UPI';
                            final inv = s['invoice'] as Map<String, dynamic>? ?? {};
                            final invNum = inv['invoiceNumber'] ?? '';
                            final cust = inv['customer'] as Map<String, dynamic>? ?? {};
                            final custName = cust['name'] ?? 'Client';
                            final date = s['paymentDate'] != null ? s['paymentDate'].toString().split('T')[0] : '';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppTheme.accentEmerald.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.check, color: AppTheme.accentEmerald, size: 16),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('$custName ($invNum)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                        Text('$rct • $method • $date', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '+₹${amt.toStringAsFixed(2)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.accentEmerald),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required double amount,
    required IconData icon,
    required Color accentColor,
    required String subtext,
    bool isHighlight = false,
    bool isWarning = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isWarning ? AppTheme.accentAmber.withOpacity(0.4) : Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: accentColor),
              ),
              if (isWarning)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(4)),
                  child: const Text('ON HOLD', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.brown)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '₹${amount.toStringAsFixed(2)}',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: accentColor),
            ),
          ),
          const SizedBox(height: 4),
          Text(subtext, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }

  Widget _buildCategoryBreakdownRow({
    required String title,
    required String badgeText,
    required Color badgeColor,
    required Color badgeTextColor,
    required String valueText,
    required String statusSubtitle,
    required IconData icon,
    required Color iconColor,
  }) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(6)),
                    child: Text(badgeText, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeTextColor)),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(statusSubtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
            ],
          ),
        ),
        Text(valueText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }

  // =========================================================================
  // TAB 2: INVOICES & SETTLEMENTS (TRACKING SINGLE / MULTI-SETTLEMENTS & ON-HOLD)
  // =========================================================================
  Widget _buildBillsTab(bool canManage) {
    final invoicesAsync = ref.watch(invoicesProvider);

    return Column(
      children: [
        // Filter bar & Custom Bill Button
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          color: Colors.white,
          child: Column(
            children: [
              Row(
                children: [
                  const Text('Filter Bills:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('ALL', 'All'),
                          _buildFilterChip('ON_HOLD', 'On-Hold Balance'),
                          _buildFilterChip('PARTIAL', 'Partially Settled'),
                          _buildFilterChip('SETTLED', 'Fully Settled'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (canManage) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.add_circle_outline, size: 18),
                        label: const Text('+ Create Custom Bill', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        onPressed: () => _showCreateCustomBillDialog(),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),

        // List of Invoices
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.refresh(invoicesProvider);
              ref.refresh(consolBillingProvider);
            },
            child: invoicesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error loading invoices: $err')),
              data: (invoices) {
                final filtered = invoices.where((inv) {
                  if (_selectedBillFilter == 'ON_HOLD') {
                    return inv.balanceDue > 0;
                  } else if (_selectedBillFilter == 'PARTIAL') {
                    return inv.isPartiallyPaid;
                  } else if (_selectedBillFilter == 'SETTLED') {
                    return inv.isPaid;
                  }
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.receipt_outlined, size: 54, color: Color(0xFF94A3B8)),
                          SizedBox(height: 12),
                          Text('No bills found matching this filter.', style: TextStyle(color: Color(0xFF64748B), fontSize: 14)),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final inv = filtered[index];
                    return _buildDetailedInvoiceCard(inv, canManage);
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedBillFilter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => setState(() => _selectedBillFilter = key),
        backgroundColor: const Color(0xFFF1F5F9),
        selectedColor: AppTheme.primaryBlue.withOpacity(0.15),
        labelStyle: TextStyle(
          color: isSelected ? AppTheme.primaryBlue : const Color(0xFF475569),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 11,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildDetailedInvoiceCard(InvoiceModel inv, bool canManage) {
    final remainingSettlement = inv.balanceDue;
    final isFullyPaid = inv.isPaid;
    final isPartial = inv.isPartiallyPaid;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFullyPaid
              ? Colors.green.shade200
              : isPartial
                  ? Colors.amber.shade300
                  : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Invoice # and Status Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.receipt, size: 16, color: AppTheme.primaryBlue),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      inv.invoiceNumber,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryBlue),
                    ),
                  ],
                ),
                _buildSettlementStatusBadge(inv),
              ],
            ),
            const SizedBox(height: 10),

            // Customer details
            Text(inv.customerName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(Icons.phone_outlined, size: 13, color: Color(0xFF64748B)),
                const SizedBox(width: 4),
                Text(inv.customerPhone, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                if (inv.dueDate.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  const Icon(Icons.calendar_today_outlined, size: 13, color: Color(0xFF64748B)),
                  const SizedBox(width: 4),
                  Text('Due: ${inv.dueDate}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ],
              ],
            ),
            const Divider(height: 20),

            // Financial Breakdown: Total vs Settled vs On-Hold Remaining
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Bill', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      const SizedBox(height: 2),
                      Text('₹${inv.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Settled', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      const SizedBox(height: 2),
                      Text(
                        '₹${inv.paidAmount.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.accentEmerald),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('On-Hold Remaining', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(
                        '₹${remainingSettlement.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: remainingSettlement > 0 ? AppTheme.accentRose : AppTheme.accentEmerald,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Action Buttons: Settle & Download PDF
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // PDF Invoice Button
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF334155),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 16, color: Colors.red),
                      label: const Text('PDF Bill', style: TextStyle(fontSize: 12)),
                      onPressed: () => _openInvoicePdf(inv.id),
                    ),
                    if (canManage) ...[
                      const SizedBox(width: 6),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                        tooltip: 'Delete Bill',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _confirmDeleteInvoice(inv),
                      ),
                    ],
                  ],
                ),

                // Record Settlement Button (Single or partial)
                if (canManage && remainingSettlement > 0) ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentEmerald,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.price_check, size: 18),
                    label: const Text('Record Settlement', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () => _showRecordSettlementDialog(inv),
                  ),
                ] else if (isFullyPaid) ...[
                  const Row(
                    children: [
                      Icon(Icons.check_circle, size: 16, color: AppTheme.accentEmerald),
                      SizedBox(width: 4),
                      Text('Settled in Full', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.accentEmerald)),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettlementStatusBadge(InvoiceModel inv) {
    Color bg;
    Color fg;
    String label;

    if (inv.isPaid) {
      bg = Colors.green.shade100;
      fg = Colors.green.shade900;
      label = 'FULLY SETTLED';
    } else if (inv.isPartiallyPaid) {
      bg = Colors.amber.shade100;
      fg = Colors.amber.shade900;
      label = 'PARTIALLY SETTLED';
    } else {
      bg = Colors.blue.shade100;
      fg = Colors.blue.shade900;
      label = 'ON-HOLD';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  // =========================================================================
  // TAB 3: EXPENSE TRACKER (LOGGING FUEL, SPARES, TOOLS, REFRESHMENTS, ETC.)
  // =========================================================================
  Widget _buildExpensesTab(bool canManage) {
    final expensesAsync = ref.watch(expensesProvider(_selectedExpenseCategory == 'ALL' ? null : _selectedExpenseCategory));

    return Column(
      children: [
        // Top Bar: Category Chips & Log Expense Button
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          color: Colors.white,
          child: Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildExpenseCategoryChip('ALL', 'All Expenses'),
                    _buildExpenseCategoryChip('FUEL', 'Fuel / Petrol'),
                    _buildExpenseCategoryChip('SPARES', 'Spare Parts'),
                    _buildExpenseCategoryChip('TOOLS', 'Tools & Kits'),
                    _buildExpenseCategoryChip('REFRESHMENT', 'Food & Snacks'),
                    _buildExpenseCategoryChip('MAINTENANCE', 'Vehicle Maint.'),
                    _buildExpenseCategoryChip('TRANSPORT', 'Transport'),
                    _buildExpenseCategoryChip('OFFICE', 'Office / Rent'),
                  ],
                ),
              ),
              if (canManage) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentRose,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.add_circle_outline, size: 18),
                        label: const Text('+ Log Business Expense', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        onPressed: () => _showAddExpenseDialog(),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),

        // List of Expenses
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.refresh(expensesProvider(_selectedExpenseCategory == 'ALL' ? null : _selectedExpenseCategory));
              ref.refresh(consolBillingProvider);
            },
            child: expensesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error loading expenses: $err')),
              data: (expenses) {
                if (expenses.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.account_balance_wallet_outlined, size: 54, color: Color(0xFF94A3B8)),
                          SizedBox(height: 12),
                          Text('No expenses recorded for this category.', style: TextStyle(color: Color(0xFF64748B), fontSize: 14)),
                        ],
                      ),
                    ),
                  );
                }

                // Calculate total for visible list
                double totalVisible = 0;
                for (var e in expenses) {
                  totalVisible += (e['amount'] as num?)?.toDouble() ?? 0.0;
                }

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Expense Total Banner
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${expenses.length} Expenses Recorded',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade900, fontSize: 13),
                          ),
                          Text(
                            'Total: ₹${totalVisible.toStringAsFixed(2)}',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade900, fontSize: 15),
                          ),
                        ],
                      ),
                    ),

                    ...expenses.map((exp) => _buildExpenseCard(exp, canManage)),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExpenseCategoryChip(String catKey, String label) {
    final isSelected = _selectedExpenseCategory == catKey;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => setState(() => _selectedExpenseCategory = catKey),
        backgroundColor: const Color(0xFFF1F5F9),
        selectedColor: AppTheme.accentRose.withOpacity(0.15),
        labelStyle: TextStyle(
          color: isSelected ? AppTheme.accentRose : const Color(0xFF475569),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 11,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildExpenseCard(Map<String, dynamic> exp, bool canManage) {
    final id = exp['id'] ?? '';
    final category = (exp['category'] ?? 'OTHER').toString().toUpperCase();
    final amount = (exp['amount'] as num?)?.toDouble() ?? 0.0;
    final description = exp['description'] ?? 'No description';
    final rawDate = exp['expenseDate'];
    final dateStr = rawDate != null ? rawDate.toString().split('T')[0] : '';

    IconData catIcon;
    Color catColor;

    switch (category) {
      case 'FUEL':
        catIcon = Icons.local_gas_station_rounded;
        catColor = Colors.orange;
        break;
      case 'SPARES':
        catIcon = Icons.build_circle_rounded;
        catColor = AppTheme.primaryBlue;
        break;
      case 'TOOLS':
        catIcon = Icons.handyman_rounded;
        catColor = Colors.purple;
        break;
      case 'REFRESHMENT':
        catIcon = Icons.fastfood_rounded;
        catColor = Colors.teal;
        break;
      case 'MAINTENANCE':
        catIcon = Icons.car_repair_rounded;
        catColor = Colors.indigo;
        break;
      case 'TRANSPORT':
        catIcon = Icons.directions_bike_rounded;
        catColor = Colors.deepOrange;
        break;
      case 'OFFICE':
        catIcon = Icons.apartment_rounded;
        catColor = Colors.blueGrey;
        break;
      default:
        catIcon = Icons.receipt_long_rounded;
        catColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: catColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(catIcon, color: catColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: catColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                      child: Text(category, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: catColor)),
                    ),
                    const SizedBox(width: 8),
                    Text(dateStr, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
                const SizedBox(height: 4),
                Text(description, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('-₹${amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.accentRose)),
              if (canManage) ...[
                const SizedBox(height: 4),
                InkWell(
                  onTap: () => _confirmDeleteExpense(id, description),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(Icons.delete_outline, size: 18, color: Color(0xFF94A3B8)),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // DIALOGS & ACTIONS
  // =========================================================================

  // 1. Record Settlement (Single or Partial settlement tracking)
  void _showRecordSettlementDialog(InvoiceModel inv) {
    final remaining = inv.balanceDue;
    final amountCtrl = TextEditingController(text: remaining.toStringAsFixed(0));
    final refCtrl = TextEditingController(text: 'UPI-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');
    final notesCtrl = TextEditingController();
    String selectedMethod = 'UPI';
    bool isSaving = false;
    String? errorMsg;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final currentInputAmount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
          final calculatedRemaining = (remaining - currentInputAmount).clamp(0.0, double.infinity);
          final isFullPayment = currentInputAmount >= remaining;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.accentEmerald.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.price_check, color: AppTheme.accentEmerald, size: 24),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Record Settlement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
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
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                        child: Text(errorMsg!, style: TextStyle(color: Colors.red.shade800, fontSize: 12)),
                      ),
                    ],

                    // Info Box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Invoice: ${inv.invoiceNumber} • Customer: ${inv.customerName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Total Billed: ₹${inv.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
                              Text('Current On-Hold: ₹${remaining.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.accentRose)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Quick buttons: "Settle In Full" vs "Custom"
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.accentEmerald,
                              side: const BorderSide(color: AppTheme.accentEmerald),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            onPressed: () {
                              amountCtrl.text = remaining.toStringAsFixed(0);
                              setDlgState(() {});
                            },
                            child: const Text('Settle Full Amount', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setDlgState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Settlement Amount (₹) *',
                        prefixIcon: Icon(Icons.currency_rupee, size: 20),
                      ),
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      value: selectedMethod,
                      decoration: const InputDecoration(
                        labelText: 'Payment Method *',
                        prefixIcon: Icon(Icons.account_balance_wallet_outlined, size: 20),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'UPI', child: Text('UPI (GPay / PhonePe / Paytm)')),
                        DropdownMenuItem(value: 'CASH', child: Text('Cash in Hand')),
                        DropdownMenuItem(value: 'CARD', child: Text('Credit / Debit Card (POS)')),
                        DropdownMenuItem(value: 'BANK_TRANSFER', child: Text('Bank Transfer (NEFT / IMPS)')),
                      ],
                      onChanged: (val) => setDlgState(() => selectedMethod = val ?? 'UPI'),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: refCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Transaction Ref / UTR / Receipt No.',
                        prefixIcon: Icon(Icons.tag, size: 20),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                        prefixIcon: Icon(Icons.note_alt_outlined, size: 20),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Calculated Settlement Outcome preview
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isFullPayment ? Colors.green.shade50 : Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isFullPayment ? Colors.green.shade200 : Colors.amber.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isFullPayment ? '🎉 Full Settlement (Zero remaining on-hold)' : '⏳ Partial Settlement',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: isFullPayment ? Colors.green.shade900 : Colors.brown,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Remaining balance on-hold after payment: ₹${calculatedRemaining.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: calculatedRemaining > 0 ? AppTheme.accentRose : AppTheme.accentEmerald,
                            ),
                          ),
                        ],
                      ),
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
                        final amt = double.tryParse(amountCtrl.text.trim());
                        if (amt == null || amt <= 0) {
                          setDlgState(() => errorMsg = 'Please enter a valid positive settlement amount.');
                          return;
                        }

                        setDlgState(() {
                          isSaving = true;
                          errorMsg = null;
                        });

                        try {
                          final repo = ref.read(apiRepositoryProvider);
                          await repo.recordSettlement(
                            invoiceId: inv.id,
                            amount: amt,
                            paymentMethod: selectedMethod,
                            referenceNumber: refCtrl.text.trim().isNotEmpty ? refCtrl.text.trim() : null,
                            notes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
                          );

                          ref.refresh(invoicesProvider);
                          ref.refresh(consolBillingProvider);
                          ref.refresh(dashboardStatsProvider);

                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(isFullPayment ? '🎉 Bill settled in full!' : 'Settlement of ₹${amt.toStringAsFixed(0)} recorded.'),
                                backgroundColor: AppTheme.accentEmerald,
                              ),
                            );
                          }
                        } catch (e) {
                          setDlgState(() {
                            isSaving = false;
                            errorMsg = 'Failed to record settlement: $e';
                          });
                        }
                      },
                child: isSaving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Confirm Settlement'),
              ),
            ],
          );
        },
      ),
    );
  }

  // 2. Create Custom Bill / Invoice Dialog
  void _showCreateCustomBillDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final discountCtrl = TextEditingController(text: '0');
    final taxRateCtrl = TextEditingController(text: '18');
    final upfrontPaymentCtrl = TextEditingController(text: '0');
    final refCtrl = TextEditingController();
    String paymentMethod = 'UPI';

    // Default line items
    final List<Map<String, TextEditingController>> lineItemCtrls = [
      {
        'desc': TextEditingController(text: 'AC Comprehensive Service & Chemical Cleaning'),
        'qty': TextEditingController(text: '1'),
        'price': TextEditingController(text: '1499'),
      }
    ];

    bool isSaving = false;
    String? errorMsg;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          // Calculate live preview totals
          double subtotal = 0;
          for (var item in lineItemCtrls) {
            final qty = int.tryParse(item['qty']!.text.trim()) ?? 0;
            final price = double.tryParse(item['price']!.text.trim()) ?? 0.0;
            subtotal += qty * price;
          }

          final discount = double.tryParse(discountCtrl.text.trim()) ?? 0.0;
          final discountedSubtotal = (subtotal - discount).clamp(0.0, double.infinity);
          final taxRate = double.tryParse(taxRateCtrl.text.trim()) ?? 18.0;
          final taxAmount = (discountedSubtotal * taxRate / 100);
          final totalBill = discountedSubtotal + taxAmount;
          final upfront = double.tryParse(upfrontPaymentCtrl.text.trim()) ?? 0.0;
          final remainingOnHold = (totalBill - upfront).clamp(0.0, double.infinity);

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.add_shopping_cart, color: AppTheme.primaryBlue, size: 22),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Generate Custom Bill', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (errorMsg != null) ...[
                      Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                        child: Text(errorMsg!, style: TextStyle(color: Colors.red.shade800, fontSize: 12)),
                      ),
                    ],

                    const Text('Customer Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryBlue)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Customer Name *', prefixIcon: Icon(Icons.person_outline, size: 20)),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: phoneCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(labelText: 'Phone Number *', prefixIcon: Icon(Icons.phone_outlined, size: 20)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(labelText: 'Email (optional)', prefixIcon: Icon(Icons.email_outlined, size: 20)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: addressCtrl,
                      decoration: const InputDecoration(labelText: 'Service Address / Location', prefixIcon: Icon(Icons.location_on_outlined, size: 20)),
                    ),
                    const SizedBox(height: 16),

                    // Line Items
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Bill Line Items', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryBlue)),
                        TextButton.icon(
                          onPressed: () {
                            setDlgState(() {
                              lineItemCtrls.add({
                                'desc': TextEditingController(),
                                'qty': TextEditingController(text: '1'),
                                'price': TextEditingController(text: '0'),
                              });
                            });
                          },
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add Item', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    ...lineItemCtrls.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final item = entry.value;

                      return Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: item['desc'],
                                    onChanged: (_) => setDlgState(() {}),
                                    decoration: InputDecoration(
                                      labelText: 'Item #${idx + 1} Description *',
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                    ),
                                  ),
                                ),
                                if (lineItemCtrls.length > 1)
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                                    onPressed: () {
                                      setDlgState(() {
                                        lineItemCtrls.removeAt(idx);
                                      });
                                    },
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: item['qty'],
                                    keyboardType: TextInputType.number,
                                    onChanged: (_) => setDlgState(() {}),
                                    decoration: const InputDecoration(
                                      labelText: 'Qty',
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 2,
                                  child: TextField(
                                    controller: item['price'],
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    onChanged: (_) => setDlgState(() {}),
                                    decoration: const InputDecoration(
                                      labelText: 'Unit Price (₹)',
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 12),

                    // Discount & Tax Row
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: discountCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (_) => setDlgState(() {}),
                            decoration: const InputDecoration(labelText: 'Discount (₹)', prefixIcon: Icon(Icons.discount_outlined, size: 18)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: taxRateCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (_) => setDlgState(() {}),
                            decoration: const InputDecoration(labelText: 'GST Tax %', prefixIcon: Icon(Icons.percent, size: 18)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Upfront Settlement Section
                    const Text('Upfront Settlement / Advance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.accentEmerald)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: upfrontPaymentCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (_) => setDlgState(() {}),
                            decoration: const InputDecoration(labelText: 'Settled Now (₹)', prefixIcon: Icon(Icons.price_check, size: 18)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: paymentMethod,
                            decoration: const InputDecoration(labelText: 'Payment Mode'),
                            items: const [
                              DropdownMenuItem(value: 'UPI', child: Text('UPI')),
                              DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                              DropdownMenuItem(value: 'CARD', child: Text('Card')),
                              DropdownMenuItem(value: 'BANK_TRANSFER', child: Text('Bank')),
                            ],
                            onChanged: (val) => setDlgState(() => paymentMethod = val ?? 'UPI'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: refCtrl,
                      decoration: const InputDecoration(labelText: 'Payment Ref / Receipt # (if paid upfront)', prefixIcon: Icon(Icons.tag, size: 18)),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(labelText: 'Notes / Terms & Conditions', prefixIcon: Icon(Icons.notes, size: 18)),
                    ),
                    const SizedBox(height: 16),

                    // Live Bill Summary Box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Subtotal:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                              Text('₹${subtotal.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Discount:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                              Text('-₹${discount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.amber, fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Tax ($taxRate%):', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                              Text('₹${taxAmount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                            ],
                          ),
                          const Divider(color: Colors.white24, height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total Bill Amount:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                              Text('₹${totalBill.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Upfront Settled:', style: TextStyle(color: AppTheme.accentEmerald, fontSize: 12, fontWeight: FontWeight.bold)),
                              Text('₹${upfront.toStringAsFixed(2)}', style: const TextStyle(color: AppTheme.accentEmerald, fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Initial On-Hold Balance:', style: TextStyle(color: AppTheme.accentRose, fontSize: 12, fontWeight: FontWeight.bold)),
                              Text('₹${remainingOnHold.toStringAsFixed(2)}', style: const TextStyle(color: AppTheme.accentRose, fontSize: 13, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
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
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue, foregroundColor: Colors.white),
                onPressed: isSaving
                    ? null
                    : () async {
                        final name = nameCtrl.text.trim();
                        final phone = phoneCtrl.text.trim();

                        if (name.isEmpty || phone.isEmpty) {
                          setDlgState(() => errorMsg = 'Customer Name and Phone Number are required.');
                          return;
                        }

                        final validItems = <Map<String, dynamic>>[];
                        for (var item in lineItemCtrls) {
                          final desc = item['desc']!.text.trim();
                          final qty = int.tryParse(item['qty']!.text.trim()) ?? 1;
                          final price = double.tryParse(item['price']!.text.trim()) ?? 0.0;
                          if (desc.isNotEmpty && price >= 0) {
                            validItems.add({
                              'description': desc,
                              'quantity': qty,
                              'unitPrice': price,
                            });
                          }
                        }

                        if (validItems.isEmpty) {
                          setDlgState(() => errorMsg = 'Please add at least one line item with description and price.');
                          return;
                        }

                        setDlgState(() {
                          isSaving = true;
                          errorMsg = null;
                        });

                        try {
                          final repo = ref.read(apiRepositoryProvider);
                          await repo.createCustomInvoice(
                            customerName: name,
                            customerPhone: phone,
                            customerEmail: emailCtrl.text.trim().isNotEmpty ? emailCtrl.text.trim() : null,
                            customerAddress: addressCtrl.text.trim().isNotEmpty ? addressCtrl.text.trim() : null,
                            items: validItems,
                            discount: discount,
                            taxRate: taxRate,
                            notes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
                            upfrontSettlementAmount: upfront > 0 ? upfront : null,
                            paymentMethod: upfront > 0 ? paymentMethod : null,
                            referenceNumber: (upfront > 0 && refCtrl.text.trim().isNotEmpty) ? refCtrl.text.trim() : null,
                          );

                          ref.refresh(invoicesProvider);
                          ref.refresh(consolBillingProvider);
                          ref.refresh(dashboardStatsProvider);

                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('🎉 Custom Bill created successfully!'),
                                backgroundColor: AppTheme.accentEmerald,
                              ),
                            );
                          }
                        } catch (e) {
                          setDlgState(() {
                            isSaving = false;
                            errorMsg = 'Failed to create bill: $e';
                          });
                        }
                      },
                child: isSaving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Create Bill'),
              ),
            ],
          );
        },
      ),
    );
  }

  // 3. Log Expense Dialog
  void _showAddExpenseDialog() {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String category = 'FUEL';
    DateTime selectedDate = DateTime.now();
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
                  color: AppTheme.accentRose.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.receipt_long, color: AppTheme.accentRose, size: 22),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Log Business Expense', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
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
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                      child: Text(errorMsg!, style: TextStyle(color: Colors.red.shade800, fontSize: 12)),
                    ),
                  ],

                  DropdownButtonFormField<String>(
                    value: category,
                    decoration: const InputDecoration(labelText: 'Expense Category *', prefixIcon: Icon(Icons.category_outlined)),
                    items: const [
                      DropdownMenuItem(value: 'FUEL', child: Text('Fuel / Petrol for Travel')),
                      DropdownMenuItem(value: 'SPARES', child: Text('Spare Parts & Consumables')),
                      DropdownMenuItem(value: 'TOOLS', child: Text('Tools & Hardware Equipment')),
                      DropdownMenuItem(value: 'REFRESHMENT', child: Text('Food & Team Refreshment')),
                      DropdownMenuItem(value: 'MAINTENANCE', child: Text('Vehicle Service & Maintenance')),
                      DropdownMenuItem(value: 'TRANSPORT', child: Text('Local Courier & Transport')),
                      DropdownMenuItem(value: 'OFFICE', child: Text('Office / Shop Expenses')),
                      DropdownMenuItem(value: 'OTHER', child: Text('Other Miscellaneous')),
                    ],
                    onChanged: (val) => setDlgState(() => category = val ?? 'FUEL'),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Amount (₹) *', prefixIcon: Icon(Icons.currency_rupee)),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(labelText: 'Description / Purpose *', prefixIcon: Icon(Icons.description_outlined)),
                  ),
                  const SizedBox(height: 12),

                  // Date picker tile
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    leading: const Icon(Icons.calendar_month, color: AppTheme.primaryBlue),
                    title: const Text('Expense Date', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    subtitle: Text(DateFormat('yyyy-MM-dd').format(selectedDate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    trailing: TextButton(
                      child: const Text('Change'),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2024),
                          lastDate: DateTime.now().add(const Duration(days: 1)),
                        );
                        if (picked != null) {
                          setDlgState(() => selectedDate = picked);
                        }
                      },
                    ),
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
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentRose, foregroundColor: Colors.white),
              onPressed: isSaving
                  ? null
                  : () async {
                      final amt = double.tryParse(amountCtrl.text.trim());
                      final desc = descCtrl.text.trim();

                      if (amt == null || amt <= 0 || desc.isEmpty) {
                        setDlgState(() => errorMsg = 'Please enter a valid amount and description.');
                        return;
                      }

                      setDlgState(() {
                        isSaving = true;
                        errorMsg = null;
                      });

                      try {
                        final repo = ref.read(apiRepositoryProvider);
                        await repo.createExpense(
                          category: category,
                          amount: amt,
                          description: desc,
                          expenseDate: selectedDate.toIso8601String(),
                        );

                        ref.refresh(expensesProvider(_selectedExpenseCategory == 'ALL' ? null : _selectedExpenseCategory));
                        ref.refresh(consolBillingProvider);

                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Expense of ₹${amt.toStringAsFixed(0)} logged successfully!'),
                              backgroundColor: AppTheme.accentRose,
                            ),
                          );
                        }
                      } catch (e) {
                        setDlgState(() {
                          isSaving = false;
                          errorMsg = 'Failed to log expense: $e';
                        });
                      }
                    },
              child: isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save Expense'),
            ),
          ],
        ),
      ),
    );
  }

  // 4. Delete Expense Confirmation
  void _confirmDeleteExpense(String id, String desc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense Entry?'),
        content: Text('Are you sure you want to remove this expense: "$desc"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(apiRepositoryProvider).deleteExpense(id);
                ref.refresh(expensesProvider(_selectedExpenseCategory == 'ALL' ? null : _selectedExpenseCategory));
                ref.refresh(consolBillingProvider);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Expense entry deleted.'), backgroundColor: Colors.red),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete expense: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // 5. Download & Open PDF Bill
  Future<void> _openInvoicePdf(String invoiceId) async {
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                SizedBox(width: 12),
                Text('Preparing CCT Tax Invoice PDF...'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }

      final url = await ref.read(apiRepositoryProvider).getInvoicePdfUrl(invoiceId);
      final uri = Uri.parse(url);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open PDF: $url')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error downloading PDF: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // 6. Delete Invoice (Admin/Accountant)
  Future<void> _confirmDeleteInvoice(InvoiceModel inv) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Bill?'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete invoice ${inv.invoiceNumber} for ${inv.customerName}?\n\n'
          'Total: ₹${inv.totalAmount.toStringAsFixed(2)}\n\n'
          'This will permanently remove the bill, line items, and settlement records so a fresh bill can be generated.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Bill'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final repo = ref.read(apiRepositoryProvider);
        await repo.deleteInvoice(inv.id);
        ref.invalidate(invoicesProvider);
        ref.invalidate(consolBillingProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Invoice ${inv.invoiceNumber} deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete invoice: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
}
