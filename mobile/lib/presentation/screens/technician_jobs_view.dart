import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../providers/app_providers.dart';

class TechnicianJobsView extends ConsumerStatefulWidget {
  const TechnicianJobsView({super.key});

  @override
  ConsumerState<TechnicianJobsView> createState() => _TechnicianJobsViewState();
}

class _TechnicianJobsViewState extends ConsumerState<TechnicianJobsView> {
  bool _isOnline = false;
  Map<String, dynamic>? _todayAttendance;
  bool _isStatusLoading = false;
  Timer? _locationPingTimer;

  @override
  void initState() {
    super.initState();
    _fetchAttendanceAndStatus();
  }

  @override
  void dispose() {
    _locationPingTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchAttendanceAndStatus() async {
    try {
      final repo = ref.read(apiRepositoryProvider);
      Map<String, dynamic>? att;
      UserModel? me;
      try {
        att = await repo.getTodayAttendance();
      } catch (_) {}
      try {
        me = await repo.getMe();
      } catch (_) {}

      if (mounted) {
        setState(() {
          _todayAttendance = att;
          // Synchronize with database state
          if (me != null) {
            _isOnline = me.isOnline;
          } else if (att != null) {
            _isOnline = att['clockOutAt'] == null;
          }
        });

        if (_isOnline) {
          _startLocationTracking();
        } else {
          _locationPingTimer?.cancel();
        }
      }
    } catch (_) {}
  }

  void _startLocationTracking() {
    _locationPingTimer?.cancel();
    // Immediate ping
    _pingGpsLocation();
    // Periodic ping every 30 seconds while technician is online
    _locationPingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_isOnline && mounted) {
        _pingGpsLocation();
      }
    });
  }

  Future<void> _pingGpsLocation() async {
    try {
      final repo = ref.read(apiRepositoryProvider);
      // Realistic coordinates around Chennai (13.0827, 80.2707) with minor variance for live simulation
      final double lat = 13.0827 + (DateTime.now().second % 10 - 5) * 0.0003;
      final double lng = 80.2707 + (DateTime.now().minute % 10 - 5) * 0.0003;
      await repo.pingTechnicianLocation(latitude: lat, longitude: lng);
    } catch (_) {
      // Non-blocking ping failure
    }
  }

  Future<void> _toggleOnline(bool online) async {
    setState(() => _isStatusLoading = true);
    try {
      final repo = ref.read(apiRepositoryProvider);
      const double lat = 13.0827;
      const double lng = 80.2707;

      await repo.setTechnicianAvailability(
        isOnline: online,
        latitude: online ? lat : null,
        longitude: online ? lng : null,
      );

      setState(() {
        _isOnline = online;
        _isStatusLoading = false;
      });

      if (online) {
        _startLocationTracking();
      } else {
        _locationPingTimer?.cancel();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(online ? '🟢 You are now ONLINE & Visible on Live Radar' : '🔴 You are now OFFLINE'),
            backgroundColor: online ? const Color(0xFF16A34A) : const Color(0xFF475569),
          ),
        );
      }
    } catch (e) {
      setState(() => _isStatusLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _handleClockInOut() async {
    setState(() => _isStatusLoading = true);
    final repo = ref.read(apiRepositoryProvider);

    try {
      if (_todayAttendance == null) {
        // Clock In
        final res = await repo.clockIn();
        setState(() {
          _todayAttendance = res;
          _isOnline = true;
          _isStatusLoading = false;
        });
        _startLocationTracking();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('⏱️ Shift Clocked In! Status set to Online.'), backgroundColor: Color(0xFF16A34A)),
          );
        }
      } else if (_todayAttendance!['clockOutAt'] == null) {
        // Clock Out
        final res = await repo.clockOut();
        _locationPingTimer?.cancel();
        setState(() {
          _todayAttendance = res;
          _isOnline = false;
          _isStatusLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('🏁 Shift Clocked Out! Good work today.'), backgroundColor: Color(0xFF475569)),
          );
        }
      }
    } catch (e) {
      setState(() => _isStatusLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Attendance error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final jobsAsync = ref.watch(serviceJobsProvider(null));
    final user = ref.watch(authStateProvider);
    final isTech = user?.role == UserRole.technician;

    return RefreshIndicator(
      onRefresh: () async {
        _fetchAttendanceAndStatus();
        return ref.refresh(serviceJobsProvider(null));
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (isTech) ...[
            // Status & Attendance Banner
            Card(
              color: _isOnline ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: _isOnline ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 8,
                          backgroundColor: _isOnline ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isOnline ? 'Active on Field (GPS Tracked)' : 'Offline / Standby',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: _isOnline ? const Color(0xFF166534) : const Color(0xFF475569),
                          ),
                        ),
                        const Spacer(),
                        _isStatusLoading
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                            : Switch(
                                value: _isOnline,
                                activeColor: const Color(0xFF16A34A),
                                onChanged: (val) => _toggleOnline(val),
                              ),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Timesheet Attendance', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                              Text(
                                _todayAttendance == null
                                    ? 'Not Clocked In Today'
                                    : _todayAttendance!['clockOutAt'] == null
                                        ? 'Clocked In at ${(_todayAttendance!['clockInAt'] as String).split('T')[1].substring(0, 5)}'
                                        : 'Shift Completed (${((_todayAttendance!['totalMinutes'] ?? 0) / 60).toStringAsFixed(1)}h)',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        if (_todayAttendance == null || _todayAttendance!['clockOutAt'] == null)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _todayAttendance == null ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                              visualDensity: VisualDensity.compact,
                            ),
                            icon: Icon(_todayAttendance == null ? Icons.login : Icons.logout, size: 14),
                            label: Text(_todayAttendance == null ? 'Clock In' : 'Clock Out', style: const TextStyle(fontSize: 12)),
                            onPressed: _isStatusLoading ? null : _handleClockInOut,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          jobsAsync.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
            error: (err, stack) => Center(child: Text('Error loading jobs: $err')),
            data: (jobs) {
              if (jobs.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Column(
                      children: [
                        Icon(Icons.assignment_outlined, size: 48, color: Color(0xFF94A3B8)),
                        SizedBox(height: 12),
                        Text('No service jobs assigned at the moment.', style: TextStyle(color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: jobs.map((job) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _JobCard(job: job),
                )).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _JobCard extends ConsumerWidget {
  final ServiceJobModel job;

  const _JobCard({required this.job});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(job.jobNumber, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                _JobStatusBadge(status: job.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(job.serviceName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text('Customer: ${job.customerName} (${job.customerPhone})', style: const TextStyle(fontSize: 13, color: Color(0xFF334155))),
            Text('Address: ${job.address}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            if (job.acDetails != null)
              Text('Unit: ${job.acDetails}', style: const TextStyle(fontSize: 12, color: Color(0xFF0D9488), fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('Scheduled: ${job.scheduledDate} (${job.timeSlot})', style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
            const Divider(height: 20),

            // Checklist & Progress
            if (job.checklist.isNotEmpty) ...[
              const Text('Service Checklist:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 4),
              ...job.checklist.take(3).map((item) => Row(
                    children: [
                      Checkbox(
                        value: item.isChecked,
                        visualDensity: VisualDensity.compact,
                        onChanged: (val) async {
                          await ref.read(apiRepositoryProvider).toggleChecklistItem(
                                jobId: job.id,
                                itemId: item.id,
                                isChecked: val ?? false,
                              );
                          ref.refresh(serviceJobsProvider(null));
                        },
                      ),
                      Expanded(
                        child: Text(
                          item.taskName,
                          style: TextStyle(
                            fontSize: 11,
                            decoration: item.isChecked ? TextDecoration.lineThrough : null,
                            color: item.isChecked ? Colors.grey : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  )),
              const SizedBox(height: 8),
            ],

            // Action Status Progression buttons
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (job.status == 'PENDING')
                    ElevatedButton.icon(
                      icon: const Icon(Icons.navigation_outlined, size: 14),
                      label: const Text('Start En-Route', style: TextStyle(fontSize: 11)),
                      onPressed: () => _updateStatus(context, ref, job.id, 'EN_ROUTE'),
                    ),
                  if (job.status == 'EN_ROUTE')
                    ElevatedButton.icon(
                      icon: const Icon(Icons.location_on_outlined, size: 14),
                      label: const Text('Mark Arrived', style: TextStyle(fontSize: 11)),
                      onPressed: () => _updateStatus(context, ref, job.id, 'ARRIVED'),
                    ),
                  if (job.status == 'ARRIVED')
                    ElevatedButton.icon(
                      icon: const Icon(Icons.play_arrow_outlined, size: 14),
                      label: const Text('Start Service', style: TextStyle(fontSize: 11)),
                      onPressed: () => _updateStatus(context, ref, job.id, 'IN_PROGRESS'),
                    ),
                  if (job.status == 'IN_PROGRESS') ...[
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add_shopping_cart, size: 14),
                      label: const Text('Add Spare Part', style: TextStyle(fontSize: 11)),
                      onPressed: () => _showAddPartDialog(context, ref, job.id),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentEmerald),
                      icon: const Icon(Icons.verified_user_outlined, size: 14),
                      label: const Text('Verify OTP & Close', style: TextStyle(fontSize: 11)),
                      onPressed: () => _showVerifyOtpDialog(context, ref, job),
                    ),
                  ],
                  if (job.status == 'COMPLETED')
                    OutlinedButton.icon(
                      icon: const Icon(Icons.receipt, size: 14),
                      label: const Text('Generate Invoice', style: TextStyle(fontSize: 11)),
                      onPressed: () async {
                        try {
                          await ref.read(apiRepositoryProvider).generateInvoiceFromJob(jobId: job.id);
                          ref.refresh(serviceJobsProvider(null));
                          ref.refresh(invoicesProvider);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Invoice generated from completed job!')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Invoice error: $e'), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _updateStatus(BuildContext context, WidgetRef ref, String jobId, String status) async {
    await ref.read(apiRepositoryProvider).updateJobStatus(jobId: jobId, status: status);
    ref.refresh(serviceJobsProvider(null));
    ref.refresh(dashboardStatsProvider);
  }

  void _showVerifyOtpDialog(BuildContext context, WidgetRef ref, ServiceJobModel job) {
    final otpController = TextEditingController();
    final diagController = TextEditingController(text: job.diagnosis ?? 'Cleaned filters, checked capacitor and pressure');
    final notesController = TextEditingController(text: job.notes ?? 'Airflow restored to optimal cooling');
    final altPhoneController = TextEditingController();
    bool useAlternatePhone = false;
    bool isOtpSent = false;
    String? demoOtp;
    String? sentToPhone;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.shield_outlined, color: AppTheme.accentEmerald),
              const SizedBox(width: 8),
              const Expanded(child: Text('Customer OTP Verification', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Customer: ${job.customerName}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text('Primary Phone: ${job.customerPhone}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                const SizedBox(height: 8),
                const Text(
                  'Request the 6-digit verification OTP to confirm service closure and customer satisfaction.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 10),
                if (!isOtpSent) ...[
                  Row(
                    children: [
                      Checkbox(
                        value: useAlternatePhone,
                        onChanged: (val) {
                          setDialogState(() {
                            useAlternatePhone = val ?? false;
                          });
                        },
                      ),
                      const Expanded(
                        child: Text(
                          'Send OTP to Alternate Mobile Number',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                  if (useAlternatePhone) ...[
                    const SizedBox(height: 4),
                    TextField(
                      controller: altPhoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Alternate Mobile Number',
                        hintText: 'e.g. 9876543210',
                        prefixIcon: Icon(Icons.phone_android_outlined, size: 20),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
                      icon: const Icon(Icons.send_outlined, size: 16),
                      label: Text(useAlternatePhone ? 'Send OTP to Alternate Mobile' : 'Send Closure OTP to Customer'),
                      onPressed: () async {
                        final alt = useAlternatePhone ? altPhoneController.text.trim() : null;
                        if (useAlternatePhone && (alt == null || alt.length < 10)) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Please enter a valid 10-digit alternate mobile number')),
                          );
                          return;
                        }

                        try {
                          final res = await ref.read(apiRepositoryProvider).requestClosureOtp(job.id, alternatePhone: alt);
                          setDialogState(() {
                            isOtpSent = true;
                            demoOtp = res['demoOtp'];
                            sentToPhone = alt ?? job.customerPhone;
                          });
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text('OTP sent successfully to ${alt ?? job.customerPhone}!')),
                            );
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text('Error sending OTP: $e'), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                    ),
                  )
                ]
                else ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('✅ OTP dispatched to customer', style: TextStyle(color: Color(0xFF15803D), fontWeight: FontWeight.bold, fontSize: 12)),
                        if (demoOtp != null)
                          Text('Demo OTP: $demoOtp', style: const TextStyle(color: Color(0xFF166534), fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: const InputDecoration(
                      labelText: 'Enter 6-Digit Customer OTP',
                      hintText: 'e.g. 582914',
                      prefixIcon: Icon(Icons.lock_clock_outlined),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(controller: diagController, decoration: const InputDecoration(labelText: 'Diagnosis & Work Done')),
                  const SizedBox(height: 8),
                  TextField(controller: notesController, decoration: const InputDecoration(labelText: 'Resolution Notes')),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            if (isOtpSent)
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentEmerald),
                onPressed: () async {
                  final otp = otpController.text.trim();
                  if (otp.length != 6) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Please enter a valid 6-digit OTP')),
                    );
                    return;
                  }

                  try {
                    await ref.read(apiRepositoryProvider).verifyClosureOtp(
                          jobId: job.id,
                          otp: otp,
                          diagnosis: diagController.text.trim(),
                          resolutionNotes: notesController.text.trim(),
                        );
                    if (ctx.mounted) Navigator.pop(ctx);
                    ref.refresh(serviceJobsProvider(null));
                    ref.refresh(dashboardStatsProvider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Ticket verified and closed successfully!')),
                      );
                    }
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('Verification failed: $e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
                child: const Text('Verify & Close Ticket'),
              ),
          ],
        ),
      ),
    );
  }

  void _showAddPartDialog(BuildContext context, WidgetRef ref, String jobId) async {
    final parts = await ref.read(apiRepositoryProvider).getInventoryParts();
    if (!context.mounted) return;

    String? selectedPartId = parts.isNotEmpty ? parts.first.id : null;
    final qtyController = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Consume Spare Part'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedPartId,
                isExpanded: true,
                items: parts.map((p) => DropdownMenuItem(value: p.id, child: Text('${p.name} (Stock: ${p.currentStock})', style: const TextStyle(fontSize: 12)))).toList(),
                onChanged: (val) => setDialogState(() => selectedPartId = val),
              ),
              const SizedBox(height: 12),
              TextField(controller: qtyController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity Consumed')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: selectedPartId == null
                  ? null
                  : () async {
                      try {
                        await ref.read(apiRepositoryProvider).consumePartForJob(
                              jobId: jobId,
                              partId: selectedPartId!,
                              quantity: int.tryParse(qtyController.text) ?? 1,
                            );
                        if (ctx.mounted) Navigator.pop(ctx);
                        ref.refresh(serviceJobsProvider(null));
                        ref.refresh(inventoryPartsProvider(null));
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Part error: $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
              child: const Text('Deduct Stock & Add to Job'),
            ),
          ],
        ),
      ),
    );
  }
}

class _JobStatusBadge extends StatelessWidget {
  final String status;
  const _JobStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (status) {
      case 'PENDING':
        bg = Colors.amber.shade100;
        fg = Colors.amber.shade900;
        break;
      case 'EN_ROUTE':
        bg = Colors.blue.shade100;
        fg = Colors.blue.shade900;
        break;
      case 'ARRIVED':
        bg = Colors.purple.shade100;
        fg = Colors.purple.shade900;
        break;
      case 'IN_PROGRESS':
        bg = Colors.teal.shade100;
        fg = Colors.teal.shade900;
        break;
      case 'COMPLETED':
        bg = Colors.green.shade100;
        fg = Colors.green.shade900;
        break;
      default:
        bg = Colors.grey.shade200;
        fg = Colors.grey.shade800;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(status.replaceAll('_', ' '), style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
