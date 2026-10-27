import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_branding.dart';
import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../providers/app_providers.dart';
import 'home_shell_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController(text: 'admin@frostpro.in');
  final _passwordController = TextEditingController(text: 'Demo@1234');
  bool _isLoading = false;
  String? _errorMessage;
  String _currentServerUrl = AppConstants.defaultApiUrl;

  @override
  void initState() {
    super.initState();
    _loadSavedServerUrl();
  }

  Future<void> _loadSavedServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(AppConstants.keyCustomApiUrl);
    if (saved != null && saved.isNotEmpty && mounted) {
      setState(() => _currentServerUrl = saved);
    }
  }

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(apiRepositoryProvider);
      final user = await repo.login(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      ref.read(authStateProvider.notifier).setUser(user);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeShellScreen()),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = ApiClient.formatErrorMessage(e);
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showServerConfigDialog() {
    final controller = TextEditingController(text: _currentServerUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.settings_ethernet, color: AppTheme.primaryBlue),
            SizedBox(width: 8),
            Text('Server Backend URL', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select or enter the URL where your Node.js backend is hosted:',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Backend API Endpoint',
                hintText: 'http://192.168.1.7:4000/api/v1',
              ),
            ),
            const SizedBox(height: 12),
            const Text('Quick Presets:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ActionChip(
                  label: const Text('Wi-Fi LAN IP (Phone over WiFi)', style: TextStyle(fontSize: 10)),
                  onPressed: () => controller.text = AppConstants.lanApiUrl,
                ),
                ActionChip(
                  label: const Text('127.0.0.1 (USB adb reverse)', style: TextStyle(fontSize: 10)),
                  onPressed: () => controller.text = 'http://127.0.0.1:4000/api/v1',
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final newUrl = controller.text.trim();
              if (newUrl.isNotEmpty) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString(AppConstants.keyCustomApiUrl, newUrl);
                setState(() => _currentServerUrl = newUrl);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Server endpoint set to: $newUrl')),
                  );
                }
              }
            },
            child: const Text('Save & Apply'),
          ),
        ],
      ),
    );
  }

  void _fillQuickRole(String email) {
    _emailController.text = email;
    _passwordController.text = 'Demo@1234';
  }

  void _showForgotPasswordDialog() {
    final emailCtrl = TextEditingController(text: _emailController.text.trim());
    final otpCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    bool otpSent = false;
    bool isSubmitting = false;
    String? dialogError;
    String? successMsg;
    String? demoOtp;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppTheme.primaryBlue.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.lock_reset_rounded, color: AppTheme.primaryBlue, size: 22),
              ),
              const SizedBox(width: 10),
              const Text('Reset Password', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (dialogError != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                    child: Text(dialogError!, style: TextStyle(color: Colors.red.shade800, fontSize: 12)),
                  ),
                  const SizedBox(height: 12),
                ],
                if (successMsg != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                    child: Text(successMsg!, style: TextStyle(color: Colors.green.shade800, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 12),
                ],
                if (!otpSent) ...[
                  const Text('Enter your registered email to receive an instant verification OTP:'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Account Email',
                      prefixIcon: Icon(Icons.email_outlined, size: 20),
                    ),
                  ),
                ] else ...[
                  Text('Verification OTP sent to ${emailCtrl.text.trim()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  if (demoOtp != null) ...[
                    const SizedBox(height: 4),
                    Text('Demo / Test OTP: $demoOtp', style: const TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: otpCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: const InputDecoration(
                      labelText: '6-Digit OTP',
                      prefixIcon: Icon(Icons.pin_rounded, size: 20),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: newPassCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'New Password (min 6 chars)',
                      prefixIcon: Icon(Icons.lock_outline, size: 20),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            if (!otpSent)
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final email = emailCtrl.text.trim();
                        if (email.isEmpty) {
                          setDlgState(() => dialogError = 'Please enter your email');
                          return;
                        }
                        setDlgState(() {
                          isSubmitting = true;
                          dialogError = null;
                        });
                        try {
                          final res = await ref.read(apiRepositoryProvider).forgotPassword(email);
                          final data = res['data'] ?? {};
                          setDlgState(() {
                            otpSent = true;
                            demoOtp = data['demoOtp']?.toString();
                            successMsg = 'OTP dispatched successfully!';
                          });
                        } catch (e) {
                          setDlgState(() => dialogError = ApiClient.formatErrorMessage(e));
                        } finally {
                          setDlgState(() => isSubmitting = false);
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Send Reset OTP'),
              )
            else
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final otp = otpCtrl.text.trim();
                        final newPass = newPassCtrl.text.trim();
                        if (otp.length != 6) {
                          setDlgState(() => dialogError = 'Enter a valid 6-digit OTP');
                          return;
                        }
                        if (newPass.length < 6) {
                          setDlgState(() => dialogError = 'Password must be at least 6 characters');
                          return;
                        }
                        setDlgState(() {
                          isSubmitting = true;
                          dialogError = null;
                        });
                        try {
                          await ref.read(apiRepositoryProvider).resetPassword(
                                email: emailCtrl.text.trim(),
                                otp: otp,
                                newPassword: newPass,
                              );
                          _passwordController.text = newPass;
                          _emailController.text = emailCtrl.text.trim();
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('🎉 Password updated successfully! Please sign in.'),
                                backgroundColor: Color(0xFF16A34A),
                              ),
                            );
                          }
                        } catch (e) {
                          setDlgState(() => dialogError = ApiClient.formatErrorMessage(e));
                        } finally {
                          setDlgState(() => isSubmitting = false);
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Confirm & Save Password'),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Dark slate hero
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                elevation: 8,
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Brand Logo Header
                      Center(
                        child: AppBranding.buildLogo(
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'FrostPro AC Operations',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Field Service Management Portal',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 28),

                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Email Field
                      const Text('Email Address', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          hintText: 'name@frostpro.in',
                          prefixIcon: Icon(Icons.email_outlined, size: 20),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Password Field
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Password', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          TextButton(
                            onPressed: _showForgotPasswordDialog,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('Forgot Password?', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryBlue)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          hintText: '••••••••',
                          prefixIcon: Icon(Icons.lock_outline, size: 20),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Sign in button
                      ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('Sign In to Workspace'),
                      ),
                      const SizedBox(height: 24),

                      // Quick role fill demo pills
                      const Text(
                        'Demo Quick Logins (1-Tap):',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          ActionChip(
                            label: const Text('Admin', style: TextStyle(fontSize: 11)),
                            avatar: const Icon(Icons.shield, size: 14),
                            onPressed: () => _fillQuickRole('admin@frostpro.in'),
                          ),
                          ActionChip(
                            label: const Text('Technician', style: TextStyle(fontSize: 11)),
                            avatar: const Icon(Icons.build, size: 14),
                            onPressed: () => _fillQuickRole('tech.karthik@frostpro.in'),
                          ),
                          ActionChip(
                            label: const Text('Booking Staff', style: TextStyle(fontSize: 11)),
                            avatar: const Icon(Icons.phone, size: 14),
                            onPressed: () => _fillQuickRole('staff@frostpro.in'),
                          ),
                          ActionChip(
                            label: const Text('Accountant', style: TextStyle(fontSize: 11)),
                            avatar: const Icon(Icons.receipt_long, size: 14),
                            onPressed: () => _fillQuickRole('accounts@frostpro.in'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: TextButton.icon(
                          onPressed: _showServerConfigDialog,
                          icon: const Icon(Icons.dns_outlined, size: 14, color: AppTheme.primaryBlue),
                          label: Text(
                            'Server: $_currentServerUrl',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), decoration: TextDecoration.underline),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
