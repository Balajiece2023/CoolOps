import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../providers/app_providers.dart';

class DashboardView extends ConsumerWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.refresh(dashboardStatsProvider),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Hero Brand Banner
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.4)),
                  ),
                  child: const Icon(Icons.ac_unit, color: Color(0xFF38BDF8), size: 30),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FrostPro AC Solutions',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Field Service Management & Dispatch',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Text(
            'Operational Overview',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 12),

          statsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (err, stack) => Card(
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Error loading dashboard: $err', style: TextStyle(color: Colors.red.shade900)),
              ),
            ),
            data: (stats) {
              return Column(
                children: [
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.4,
                    children: [
                      _StatCard(
                        title: 'Pending Requests',
                        value: '${stats['pendingRequestsCount'] ?? 0}',
                        subtitle: 'Awaiting Admin Approval',
                        icon: Icons.hourglass_top_rounded,
                        color: AppTheme.accentAmber,
                      ),
                      _StatCard(
                        title: "Today's Bookings",
                        value: '${stats['todayBookingsCount'] ?? 0}',
                        subtitle: 'Confirmed & Scheduled',
                        icon: Icons.event_available_rounded,
                        color: AppTheme.primaryBlue,
                      ),
                      _StatCard(
                        title: 'Active Field Jobs',
                        value: '${stats['ongoingJobsCount'] ?? 0}',
                        subtitle: 'Technicians on-site',
                        icon: Icons.engineering_rounded,
                        color: AppTheme.accentTeal,
                      ),
                      _StatCard(
                        title: 'Low Stock Parts',
                        value: '${stats['lowStockCount'] ?? 0}',
                        subtitle: 'Below safety threshold',
                        icon: Icons.warning_amber_rounded,
                        color: AppTheme.accentRose,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Financial Performance Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.account_balance_wallet_outlined, color: AppTheme.primaryBlue),
                              SizedBox(width: 8),
                              Text('Financial Collections', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(child: _FinancialPill(label: 'Total Invoiced', amount: (stats['totalBilled'] as num?)?.toDouble() ?? 0.0, color: const Color(0xFF0F172A))),
                              Expanded(child: _FinancialPill(label: 'Collected', amount: (stats['totalCollected'] as num?)?.toDouble() ?? 0.0, color: AppTheme.accentEmerald)),
                              Expanded(child: _FinancialPill(label: 'Outstanding', amount: (stats['totalOverdue'] as num?)?.toDouble() ?? 0.0, color: AppTheme.accentRose)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                Icon(icon, color: color, size: 20),
              ],
            ),
            Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color)),
            Text(subtitle, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
          ],
        ),
      ),
    );
  }
}

class _FinancialPill extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;

  const _FinancialPill({required this.label, required this.amount, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        const SizedBox(height: 4),
        Text('₹${amount.toStringAsFixed(0)}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}
