import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_branding.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../providers/app_providers.dart';
import 'dashboard_view.dart';
import 'booking_requests_view.dart';
import 'technician_jobs_view.dart';
import 'technicians_attendance_view.dart';
import 'clients_360_view.dart';
import 'inventory_view.dart';
import 'billing_view.dart';
import 'profile_screen.dart';

class HomeShellScreen extends ConsumerStatefulWidget {
  const HomeShellScreen({super.key});

  @override
  ConsumerState<HomeShellScreen> createState() => _HomeShellScreenState();
}

class _HomeShellScreenState extends ConsumerState<HomeShellScreen> {
  int _selectedIndex = 0;

  void _showMoreMenuSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Row(
                children: [
                  Icon(Icons.apps_rounded, color: AppTheme.primaryBlue),
                  SizedBox(width: 8),
                  Text('Operations & Admin Center', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                ],
              ),
              const SizedBox(height: 16),
              _buildMoreTile(
                icon: Icons.people_alt_outlined,
                title: 'Clients 360 & Accounts',
                subtitle: 'Customer database, lifetime service value & history',
                color: AppTheme.primaryBlue,
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const Scaffold(body: Clients360View())));
                },
              ),
              const SizedBox(height: 10),
              _buildMoreTile(
                icon: Icons.badge_outlined,
                title: 'Technicians & Timesheets',
                subtitle: 'Roster management, GPS tracking radar & daily hours',
                color: AppTheme.accentEmerald,
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const TechniciansAttendanceView()));
                },
              ),
              const SizedBox(height: 10),
              _buildMoreTile(
                icon: Icons.inventory_2_outlined,
                title: 'Inventory & Parts Valuation',
                subtitle: 'Compressors, copper tubing, gas cans & live stock',
                color: AppTheme.accentAmber,
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const Scaffold(body: InventoryView())));
                },
              ),
              const SizedBox(height: 10),
              _buildMoreTile(
                icon: Icons.receipt_long_outlined,
                title: 'Invoices & Billing',
                subtitle: 'Payment records, tax invoices & collection ledgers',
                color: AppTheme.accentRose,
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const Scaffold(body: BillingView())));
                },
              ),
              const SizedBox(height: 10),
              _buildMoreTile(
                icon: Icons.person_outline,
                title: 'Account Settings & Preferences',
                subtitle: 'Profile details, appearance & password',
                color: const Color(0xFF64748B),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileView()));
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMoreTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.18)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider);
    final role = user?.role ?? UserRole.admin;

    // Filter streamlined 3-4 bottom bar pages
    final List<Widget> pages = [];
    final List<NavigationDestination> destinations = [];

    if (role == UserRole.admin) {
      pages.addAll([
        const DashboardView(),
        const BookingRequestsView(),
        const TechnicianJobsView(),
        const TechniciansAttendanceView(),
      ]);
      destinations.addAll(const [
        NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard_rounded), label: 'Overview'),
        NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month_rounded), label: 'Requests'),
        NavigationDestination(icon: Icon(Icons.build_outlined), selectedIcon: Icon(Icons.build_rounded), label: 'Field Jobs'),
        NavigationDestination(icon: Icon(Icons.badge_outlined), selectedIcon: Icon(Icons.badge_rounded), label: 'Roster & Radar'),
      ]);
    } else if (role == UserRole.technician) {
      pages.addAll([
        const TechnicianJobsView(),
        const InventoryView(),
      ]);
      destinations.addAll(const [
        NavigationDestination(icon: Icon(Icons.handyman_outlined), selectedIcon: Icon(Icons.handyman_rounded), label: 'My Assigned Jobs'),
        NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2_rounded), label: 'Parts Catalog'),
      ]);
    } else if (role == UserRole.bookingStaff) {
      pages.addAll([
        const DashboardView(),
        const BookingRequestsView(),
        const Clients360View(),
      ]);
      destinations.addAll(const [
        NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
        NavigationDestination(icon: Icon(Icons.phone_in_talk_outlined), selectedIcon: Icon(Icons.phone_in_talk_rounded), label: 'Bookings'),
        NavigationDestination(icon: Icon(Icons.people_alt_outlined), selectedIcon: Icon(Icons.people_alt_rounded), label: 'Clients'),
      ]);
    } else if (role == UserRole.accountant) {
      pages.addAll([
        const DashboardView(),
        const BillingView(),
        const InventoryView(),
      ]);
      destinations.addAll(const [
        NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard_rounded), label: 'Overview'),
        NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long_rounded), label: 'Billing'),
        NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2_rounded), label: 'Valuation'),
      ]);
    }

    final safeIndex = _selectedIndex >= pages.length ? 0 : _selectedIndex;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            AppBranding.buildLogo(
              width: 32,
              height: 32,
              fit: BoxFit.cover,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(AppBranding.appName, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: -0.2)),
                Text(
                  '${user?.name ?? 'User'} • ${user?.role.name.toUpperCase() ?? 'STAFF'}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (role == UserRole.admin)
            IconButton(
              tooltip: 'More Admin Modules',
              icon: const Icon(Icons.grid_view_rounded, color: AppTheme.primaryBlue),
              onPressed: () => _showMoreMenuSheet(context),
            ),
          IconButton(
            tooltip: 'Profile & Settings',
            icon: CircleAvatar(
              radius: 14,
              backgroundColor: AppTheme.primaryBlue.withOpacity(0.15),
              child: Text(
                (user?.name.isNotEmpty == true) ? user!.name[0].toUpperCase() : 'U',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
              ),
            ),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileView()));
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: pages[safeIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIndex,
        onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
        destinations: destinations,
      ),
    );
  }
}
