import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../providers/app_providers.dart';

class UserManagementView extends ConsumerStatefulWidget {
  const UserManagementView({super.key});

  @override
  ConsumerState<UserManagementView> createState() => _UserManagementViewState();
}

class _UserManagementViewState extends ConsumerState<UserManagementView> {
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedRoleFilter = 'ALL';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(apiRepositoryProvider);
      final users = await repo.getAllUsers();
      if (mounted) {
        setState(() {
          _users = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _showAddUserDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController(text: 'Demo@1234');
    final phoneCtrl = TextEditingController();
    final areaCtrl = TextEditingController(text: 'Chennai Central');
    String chosenRole = 'TECHNICIAN';
    bool isSubmitting = false;
    String? dialogError;

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
                child: const Icon(Icons.person_add_alt_1_rounded, color: AppTheme.primaryBlue, size: 22),
              ),
              const SizedBox(width: 10),
              const Text('Add Organization User', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (dialogError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(dialogError!, style: TextStyle(color: Colors.red.shade800, fontSize: 12)),
                    ),
                  ],
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Full Name *', prefixIcon: Icon(Icons.person_outline, size: 20)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Company Email *', prefixIcon: Icon(Icons.email_outlined, size: 20)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: phoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(labelText: 'Phone Number *', prefixIcon: Icon(Icons.phone_outlined, size: 20)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: passwordCtrl,
                          decoration: const InputDecoration(labelText: 'Default Password *', prefixIcon: Icon(Icons.lock_outline, size: 20)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: chosenRole,
                    decoration: const InputDecoration(labelText: 'Workspace Role *', prefixIcon: Icon(Icons.badge_outlined, size: 20)),
                    items: const [
                      DropdownMenuItem(value: 'ADMIN', child: Text('Administrator (Full Control)')),
                      DropdownMenuItem(value: 'TECHNICIAN', child: Text('Field Service Technician')),
                      DropdownMenuItem(value: 'BOOKING_STAFF', child: Text('Booking & Customer Staff')),
                      DropdownMenuItem(value: 'ACCOUNTANT', child: Text('Financial Accountant')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDlgState(() => chosenRole = val);
                    },
                  ),
                  if (chosenRole == 'TECHNICIAN') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: areaCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Service Areas (Comma separated)',
                        hintText: 'e.g. Velachery, OMR, Guindy',
                        prefixIcon: Icon(Icons.map_outlined, size: 20),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final name = nameCtrl.text.trim();
                      final email = emailCtrl.text.trim();
                      final phone = phoneCtrl.text.trim();
                      final pass = passwordCtrl.text.trim();

                      if (name.isEmpty || email.isEmpty || phone.isEmpty || pass.isEmpty) {
                        setDlgState(() => dialogError = 'Please fill in all mandatory fields.');
                        return;
                      }

                      setDlgState(() {
                        isSubmitting = true;
                        dialogError = null;
                      });

                      try {
                        final repo = ref.read(apiRepositoryProvider);
                        List<String>? areas;
                        if (chosenRole == 'TECHNICIAN' && areaCtrl.text.trim().isNotEmpty) {
                          areas = areaCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                        }

                        await repo.createUser(
                          name: name,
                          email: email,
                          password: pass,
                          role: chosenRole,
                          phone: phone,
                          serviceAreas: areas,
                          skills: chosenRole == 'TECHNICIAN' ? ['Split AC', 'Inverter AC', 'Gas Charging'] : null,
                          maxDailyJobs: chosenRole == 'TECHNICIAN' ? 6 : null,
                        );

                        if (ctx.mounted) Navigator.pop(ctx);
                        _loadUsers();

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('✅ User "$name" added with role $chosenRole!'), backgroundColor: AppTheme.accentEmerald),
                          );
                        }
                      } catch (e) {
                        setDlgState(() {
                          isSubmitting = false;
                          dialogError = 'Creation failed: $e';
                        });
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Create User'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteUser(Map<String, dynamic> user) {
    final currentAdmin = ref.read(authStateProvider);
    if (currentAdmin != null && currentAdmin.id == user['id']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ You cannot delete your own active administrator account!'), backgroundColor: Colors.orange),
      );
      return;
    }

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
                child: const Icon(Icons.person_remove_rounded, color: Colors.red, size: 22),
              ),
              const SizedBox(width: 10),
              const Text('Remove User', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            ],
          ),
          content: Text(
            'Are you sure you want to deactivate and delete user "${user['name']}" (${user['email']})?\n\nThey will no longer be able to log in to the workspace.',
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
                        await repo.deleteUser(user['id']);
                        if (ctx.mounted) Navigator.pop(ctx);
                        _loadUsers();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('User "${user['name']}" removed.'), backgroundColor: Colors.red.shade700),
                          );
                        }
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.red),
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

  Color _getRoleBadgeColor(String role) {
    switch (role.toUpperCase()) {
      case 'ADMIN':
        return AppTheme.accentRose;
      case 'TECHNICIAN':
        return AppTheme.accentEmerald;
      case 'BOOKING_STAFF':
        return AppTheme.primaryBlue;
      case 'ACCOUNTANT':
        return AppTheme.accentAmber;
      default:
        return const Color(0xFF64748B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredUsers = _users.where((u) {
      final role = (u['role'] as String? ?? '').toUpperCase();
      if (_selectedRoleFilter != 'ALL' && role != _selectedRoleFilter) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final name = (u['name'] as String? ?? '').toLowerCase();
        final email = (u['email'] as String? ?? '').toLowerCase();
        final phone = (u['phone'] as String? ?? '').toLowerCase();
        return name.contains(q) || email.contains(q) || phone.contains(q);
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin User Management', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadUsers),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryBlue,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Add User'),
        onPressed: _showAddUserDialog,
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by name, email or phone...',
                prefixIcon: const Icon(Icons.search, size: 20),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                filled: true,
                fillColor: Theme.of(context).cardColor,
              ),
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
            ),
          ),

          // Role Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _buildRoleFilterChip('ALL', 'All Users (${_users.length})'),
                const SizedBox(width: 8),
                _buildRoleFilterChip('ADMIN', 'Admins'),
                const SizedBox(width: 8),
                _buildRoleFilterChip('TECHNICIAN', 'Technicians'),
                const SizedBox(width: 8),
                _buildRoleFilterChip('BOOKING_STAFF', 'Booking Staff'),
                const SizedBox(width: 8),
                _buildRoleFilterChip('ACCOUNTANT', 'Accountants'),
              ],
            ),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(child: Text('Error: $_errorMessage', style: const TextStyle(color: Colors.red)))
                    : filteredUsers.isEmpty
                        ? const Center(child: Text('No users match current filters.'))
                        : RefreshIndicator(
                            onRefresh: _loadUsers,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: filteredUsers.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (ctx, i) {
                                final user = filteredUsers[i];
                                final role = (user['role'] as String? ?? 'STAFF').toUpperCase();
                                final roleColor = _getRoleBadgeColor(role);
                                final bool isActive = user['isActive'] == true;
                                final avatarUrl = user['avatarUrl'] as String?;

                                return Card(
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Row(
                                      children: [
                                        // Avatar
                                        CircleAvatar(
                                          radius: 22,
                                          backgroundColor: roleColor.withOpacity(0.12),
                                          backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                                          child: avatarUrl == null || avatarUrl.isEmpty
                                              ? Text(
                                                  (user['name'] as String? ?? 'U').substring(0, 1).toUpperCase(),
                                                  style: TextStyle(fontWeight: FontWeight.bold, color: roleColor, fontSize: 16),
                                                )
                                              : null,
                                        ),
                                        const SizedBox(width: 14),

                                        // Details
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      user['name'] ?? 'User',
                                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: roleColor.withOpacity(0.12),
                                                      borderRadius: BorderRadius.circular(4),
                                                      border: Border.all(color: roleColor.withOpacity(0.3)),
                                                    ),
                                                    child: Text(
                                                      role.replaceAll('_', ' '),
                                                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: roleColor),
                                                    ),
                                                  ),
                                                  if (!isActive) ...[
                                                    const SizedBox(width: 4),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(4)),
                                                      child: const Text('DEACTIVATED', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.red)),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                user['email'] ?? '',
                                                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                              ),
                                              if (user['phone'] != null && (user['phone'] as String).isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  '📞 ${user['phone']}',
                                                  style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),

                                        // Actions
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                          tooltip: 'Delete User',
                                          onPressed: () => _confirmDeleteUser(user),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleFilterChip(String roleKey, String label) {
    final isSelected = _selectedRoleFilter == roleKey;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      selectedColor: AppTheme.primaryBlue.withOpacity(0.15),
      onSelected: (val) {
        if (val) setState(() => _selectedRoleFilter = roleKey);
      },
    );
  }
}
