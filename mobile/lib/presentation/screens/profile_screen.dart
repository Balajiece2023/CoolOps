import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../providers/app_providers.dart';
import 'login_screen.dart';

class ProfileView extends ConsumerStatefulWidget {
  const ProfileView({super.key});

  @override
  ConsumerState<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends ConsumerState<ProfileView> {
  void _showEditProfileDialog(UserModel user) {
    final nameCtrl = TextEditingController(text: user.name);
    final phoneCtrl = TextEditingController(text: user.phone ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.edit_outlined, color: AppTheme.primaryBlue),
            SizedBox(width: 8),
            Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Display Name *', prefixIcon: Icon(Icons.person_outline, size: 20)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Mobile Phone *', prefixIcon: Icon(Icons.phone_outlined, size: 20)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              try {
                final repo = ref.read(apiRepositoryProvider);
                final updated = await repo.updateProfile(
                  name: nameCtrl.text.trim(),
                  phone: phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
                );
                ref.read(authStateProvider.notifier).setUser(updated);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: AppTheme.accentEmerald),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Update failed: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider);
    final isDark = ref.watch(isDarkModeProvider);

    if (user == null) {
      return const Center(child: Text('No active profile session'));
    }

    final roleName = user.role.name.toUpperCase();
    Color roleBadgeColor = AppTheme.primaryBlue;
    if (user.role == UserRole.admin) roleBadgeColor = AppTheme.accentRose;
    if (user.role == UserRole.technician) roleBadgeColor = AppTheme.accentEmerald;
    if (user.role == UserRole.accountant) roleBadgeColor = AppTheme.accentAmber;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile & Workspace', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Profile',
            onPressed: () => _showEditProfileDialog(user),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          children: [
            // User Avatar Card
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [AppTheme.primaryBlue, AppTheme.primaryLight],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryBlue.withOpacity(0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                        style: const TextStyle(fontSize: 38, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: roleBadgeColor, shape: BoxShape.circle),
                      child: const Icon(Icons.verified, size: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              user.name,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: roleBadgeColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: roleBadgeColor.withOpacity(0.3)),
              ),
              child: Text(
                roleName,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: roleBadgeColor, letterSpacing: 0.8),
              ),
            ),
            const SizedBox(height: 28),

            // Profile Info Group
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildInfoRow(
                      icon: Icons.email_outlined,
                      label: 'Email Address',
                      value: user.email,
                    ),
                    const Divider(height: 20),
                    _buildInfoRow(
                      icon: Icons.phone_outlined,
                      label: 'Contact Number',
                      value: user.phone ?? 'Not registered',
                    ),
                    const Divider(height: 20),
                    _buildInfoRow(
                      icon: Icons.badge_outlined,
                      label: 'System User ID',
                      value: user.id.substring(0, 12) + '...',
                    ),
                    if (user.technicianId != null) ...[
                      const Divider(height: 20),
                      _buildInfoRow(
                        icon: Icons.handyman_outlined,
                        label: 'Technician Profile ID',
                        value: user.technicianId!.substring(0, 12) + '...',
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // App Settings & Preferences Card
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Dark Mode Appearance', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text(isDark ? 'Sleek midnight dark theme active' : 'Clean crisp light theme active', style: const TextStyle(fontSize: 12)),
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded, color: AppTheme.primaryBlue, size: 20),
                    ),
                    value: isDark,
                    onChanged: (val) {
                      ref.read(isDarkModeProvider.notifier).setDark(val);
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.info_outline, color: AppTheme.neutral500, size: 20),
                    ),
                    title: const Text('App Version & Build', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    trailing: const Text('v1.0.0 (Build 42)', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Log Out Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.accentRose,
                  side: const BorderSide(color: Color(0xFFFECDD3)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.logout_rounded, size: 20),
                label: const Text('Sign Out of Workspace', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () async {
                  await ref.read(authStateProvider.notifier).logout();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({required IconData icon, required String label, required String value}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppTheme.primaryBlue, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}
