import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../providers/app_providers.dart';
import '../widgets/user_avatar.dart';
import 'login_screen.dart';

class ProfileView extends ConsumerStatefulWidget {
  const ProfileView({super.key});

  @override
  ConsumerState<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends ConsumerState<ProfileView> {
  final List<String> _avatarPresets = [
    'https://api.dicebear.com/7.x/bottts/png?seed=FrostTech1',
    'https://api.dicebear.com/7.x/bottts/png?seed=CoolAdmin',
    'https://api.dicebear.com/7.x/avataaars/png?seed=Karthik',
    'https://api.dicebear.com/7.x/avataaars/png?seed=Priya',
    'https://api.dicebear.com/7.x/avataaars/png?seed=Suresh',
    'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200',
    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200',
    'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=200',
  ];

  void _showChangeAvatarModal(UserModel user) {
    String? pendingAvatar = user.avatarUrl;
    Uint8List? localImageBytes;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;

          Future<void> pickFromSource(ImageSource source) async {
            try {
              final picker = ImagePicker();
              final picked = await picker.pickImage(
                source: source,
                maxWidth: 600,
                maxHeight: 600,
                imageQuality: 85,
              );
              if (picked != null) {
                final bytes = await picked.readAsBytes();
                final base64String = 'data:image/jpeg;base64,${base64Encode(bytes)}';
                setModalState(() {
                  localImageBytes = bytes;
                  pendingAvatar = base64String;
                });
              }
            } catch (e) {
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text('Could not load image: $e'), backgroundColor: Colors.red),
                );
              }
            }
          }

          return Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Theme.of(context).cardColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: EdgeInsets.only(
              top: 20,
              left: 20,
              right: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Set Profile Picture',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Browse and upload an image from your device',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // Live Preview of selected avatar
                Center(
                  child: Stack(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.primaryBlue, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryBlue.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: localImageBytes != null
                              ? Image.memory(localImageBytes!, fit: BoxFit.cover)
                              : UserAvatar(
                                  avatarUrl: pendingAvatar,
                                  name: user.name,
                                  radius: 48,
                                ),
                        ),
                      ),
                      if (pendingAvatar != null && pendingAvatar!.isNotEmpty)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: InkWell(
                            onTap: () {
                              setModalState(() {
                                localImageBytes = null;
                                pendingAvatar = '';
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Primary Buttons to choose from local device
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.photo_library_outlined, size: 18),
                        label: const Text('Browse Gallery', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: isSaving ? null : () => pickFromSource(ImageSource.gallery),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.camera_alt_outlined, size: 18),
                        label: const Text('Take Camera', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: isSaving ? null : () => pickFromSource(ImageSource.camera),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Quick avatar presets as alternative
                const Text(
                  'Or pick an avatar preset:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 54,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _avatarPresets.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, idx) {
                      final preset = _avatarPresets[idx];
                      final isSelected = pendingAvatar == preset;
                      return GestureDetector(
                        onTap: () {
                          setModalState(() {
                            localImageBytes = null;
                            pendingAvatar = preset;
                          });
                        },
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? AppTheme.primaryBlue : Colors.grey.shade300,
                              width: isSelected ? 3 : 1,
                            ),
                          ),
                          child: ClipOval(
                            child: Image.network(
                              preset,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Colors.grey),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),

                // Save or Remove buttons
                Row(
                  children: [
                    if (user.avatarUrl != null && user.avatarUrl!.isNotEmpty) ...[
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Color(0xFFFECDD3)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: isSaving
                            ? null
                            : () async {
                                setModalState(() => isSaving = true);
                                try {
                                  final repo = ref.read(apiRepositoryProvider);
                                  final updated = await repo.updateProfile(avatarUrl: '');
                                  ref.read(authStateProvider.notifier).setUser(updated);
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Profile picture removed!'), backgroundColor: AppTheme.accentEmerald),
                                    );
                                  }
                                } catch (e) {
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
                                    );
                                  }
                                } finally {
                                  if (ctx.mounted) setModalState(() => isSaving = false);
                                }
                              },
                        child: const Text('Remove Photo'),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: isSaving || pendingAvatar == user.avatarUrl
                            ? null
                            : () async {
                                setModalState(() => isSaving = true);
                                try {
                                  final repo = ref.read(apiRepositoryProvider);
                                  final updated = await repo.updateProfile(avatarUrl: pendingAvatar ?? '');
                                  ref.read(authStateProvider.notifier).setUser(updated);
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Profile picture updated successfully!'), backgroundColor: AppTheme.accentEmerald),
                                    );
                                  }
                                } catch (e) {
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(content: Text('Update failed: $e'), backgroundColor: Colors.red),
                                    );
                                  }
                                } finally {
                                  if (ctx.mounted) setModalState(() => isSaving = false);
                                }
                              },
                        child: isSaving
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Save Picture', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

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
            // User Avatar Card with Edit Option
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  GestureDetector(
                    onTap: () => _showChangeAvatarModal(user),
                    child: Container(
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
                      child: ClipOval(
                        child: UserAvatar(
                          avatarUrl: user.avatarUrl,
                          name: user.name,
                          radius: 46,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: GestureDetector(
                      onTap: () => _showChangeAvatarModal(user),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: const BoxDecoration(color: AppTheme.primaryBlue, shape: BoxShape.circle),
                          child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                        ),
                      ),
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
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.account_circle_outlined, color: AppTheme.primaryBlue, size: 20),
                    ),
                    title: const Text('Change Profile Picture', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('Avatar presets or photo URL', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    trailing: const Icon(Icons.chevron_right, size: 20, color: Color(0xFF94A3B8)),
                    onTap: () => _showChangeAvatarModal(user),
                  ),
                  const Divider(height: 1),
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
                  // Push LoginScreen and remove all previous routes first
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                  await ref.read(authStateProvider.notifier).logout();
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
