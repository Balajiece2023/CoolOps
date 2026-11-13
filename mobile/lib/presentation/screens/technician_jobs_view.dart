import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/location_service.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../providers/app_providers.dart';
import 'technician_live_tracking_screen.dart';
import 'technician_timesheet_view.dart';

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
      try {
        att = await repo.getTodayAttendance();
      } catch (_) {}

      if (mounted) {
        final activeSession = att?['activeSession'];
        final isClockedIn = activeSession != null;
        setState(() {
          _todayAttendance = att;
          // Technician active status is directly coupled to active clock-in shift
          _isOnline = isClockedIn;
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
      final position = await LocationService.getCurrentPosition();
      final double lat = position?.latitude ?? LocationService.defaultLatitude;
      final double lng = position?.longitude ?? LocationService.defaultLongitude;
      await repo.pingTechnicianLocation(latitude: lat, longitude: lng);
    } catch (_) {
      // Non-blocking ping failure
    }
  }

  Future<void> _toggleOnline(bool online) async {
    setState(() => _isStatusLoading = true);
    try {
      final repo = ref.read(apiRepositoryProvider);
      double? lat;
      double? lng;
      if (online) {
        final position = await LocationService.getCurrentPosition();
        lat = position?.latitude ?? LocationService.defaultLatitude;
        lng = position?.longitude ?? LocationService.defaultLongitude;
      }

      await repo.setTechnicianAvailability(
        isOnline: online,
        latitude: lat,
        longitude: lng,
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
            content: Text(online
                ? '🟢 You are now ONLINE & Visible on Live Radar (${lat?.toStringAsFixed(4)}, ${lng?.toStringAsFixed(4)})'
                : '🔴 You are now OFFLINE'),
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
    final activeSession = _todayAttendance?['activeSession'];

    try {
      if (activeSession == null) {
        // Clock In: Real mobile GPS capture and activate on field
        final position = await LocationService.getCurrentPosition();
        final double lat = position?.latitude ?? LocationService.defaultLatitude;
        final double lng = position?.longitude ?? LocationService.defaultLongitude;
        await repo.clockIn(latitude: lat, longitude: lng);
        await repo.setTechnicianAvailability(isOnline: true, latitude: lat, longitude: lng);
        setState(() => _isOnline = true);
        _startLocationTracking();
        await _fetchAttendanceAndStatus();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⏱️ Shift Clocked In! Real GPS captured (${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}) & Active on Field.'),
              backgroundColor: const Color(0xFF16A34A),
            ),
          );
        }
      } else {
        // Clock Out: Real mobile GPS exit capture and go offline
        final position = await LocationService.getCurrentPosition();
        final double? lat = position?.latitude;
        final double? lng = position?.longitude;
        await repo.clockOut(latitude: lat, longitude: lng);
        await repo.setTechnicianAvailability(isOnline: false, latitude: lat, longitude: lng);
        setState(() => _isOnline = false);
        _locationPingTimer?.cancel();
        await _fetchAttendanceAndStatus();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('🏁 Shift session ended. Consolidated timesheet updated & Offline.'), backgroundColor: Color(0xFF475569)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        String msg = e.toString();
        if (e is DioException) {
          msg = e.response?.data?['error']?['message'] ?? e.response?.data?['message'] ?? e.message ?? 'Attendance service error';
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Attendance error: $msg'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() => _isStatusLoading = false);
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
            // Status & Attendance Banner (Active on Field incorporated directly with Clock-in)
            Card(
              color: _isOnline ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: _isOnline ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Builder(
                  builder: (ctx) {
                    final activeSession = _todayAttendance?['activeSession'];
                    final sessions = (_todayAttendance?['sessions'] as List?) ?? [];
                    final consolidated = _todayAttendance?['consolidatedFormatted'] ?? '0h 0m';
                    final isClockedIn = activeSession != null;

                    String subtitleText = 'Not Clocked In Today';
                    if (isClockedIn) {
                      final inAt = activeSession['clockInAt'] as String?;
                      if (inAt != null) {
                        try {
                          final dt = DateTime.parse(inAt).toLocal();
                          final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
                          final ampm = dt.hour >= 12 ? 'PM' : 'AM';
                          final min = dt.minute.toString().padLeft(2, '0');
                          subtitleText = 'Shift Active: In at $hour:$min $ampm • Logged: $consolidated';
                        } catch (_) {
                          subtitleText = 'Shift Active • Logged: $consolidated';
                        }
                      }
                    } else if (sessions.isNotEmpty) {
                      subtitleText = 'Off Shift • Total Today: $consolidated (${sessions.length} shifts)';
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 7,
                              backgroundColor: isClockedIn ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isClockedIn ? 'Active on Field (GPS Tracked)' : 'Offline / Standby',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isClockedIn ? const Color(0xFF166534) : const Color(0xFF475569),
                              ),
                            ),
                            const Spacer(),
                            // Direct Link to Technician's Timesheet Tracker
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: const Icon(Icons.history, size: 15, color: AppTheme.primaryBlue),
                              label: const Text('My Timesheet', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryBlue)),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const TechnicianTimesheetView()),
                                );
                              },
                            ),
                          ],
                        ),
                        const Divider(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Text('Timesheet Attendance', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                      if (sessions.isNotEmpty) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(4)),
                                          child: Text('${sessions.length} Shift${sessions.length > 1 ? "s" : ""}', style: const TextStyle(fontSize: 10, color: AppTheme.primaryBlue, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    subtitleText,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isClockedIn ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                                foregroundColor: Colors.white,
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: _isStatusLoading
                                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : Icon(isClockedIn ? Icons.logout : Icons.login, size: 14),
                              label: Text(
                                isClockedIn
                                    ? 'Clock Out'
                                    : (sessions.isEmpty ? 'Clock In' : 'Clock In Again'),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              onPressed: _isStatusLoading ? null : _handleClockInOut,
                            ),
                          ],
                        ),
                      ],
                    );
                  },
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

  void _showJobOverview(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        height: MediaQuery.of(sheetCtx).size.height * 0.8,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(job.jobNumber, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                      const SizedBox(height: 4),
                      _JobStatusBadge(status: job.status),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(sheetCtx),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Prominent Call Customer Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.phone_in_talk, color: Colors.white, size: 22),
                  label: Text(
                    'Call Customer (${job.customerPhone})',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  onPressed: () async {
                    final uri = Uri.parse('tel:${job.customerPhone}');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    }
                  },
                ),
              ),
              const SizedBox(height: 16),

              const Text('Customer & Location', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryBlue)),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(Icons.person, color: Color(0xFF64748B)),
                title: Text(job.customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                subtitle: Text('Mobile: ${job.customerPhone}'),
                trailing: IconButton(
                  icon: const Icon(Icons.phone, color: Color(0xFF16A34A)),
                  onPressed: () => launchUrl(Uri.parse('tel:${job.customerPhone}')),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(Icons.location_on, color: Color(0xFF64748B)),
                title: Text(job.address),
                subtitle: const Text('Service Location'),
                trailing: TextButton.icon(
                  icon: const Icon(Icons.link, size: 16, color: Color(0xFFEA580C)),
                  label: Text(
                    job.latitude == null ? 'Set Location Link' : 'Update Link',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFEA580C)),
                  ),
                  onPressed: () {
                    Navigator.pop(sheetCtx);
                    _showSetJobLocationDialog(context, ref, job);
                  },
                ),
              ),
              const Divider(height: 24),

              const Text('Service & Appliance Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryBlue)),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(Icons.build_circle, color: Color(0xFF64748B)),
                title: Text(job.serviceName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: job.serviceDescription != null && job.serviceDescription!.isNotEmpty
                    ? Text('Admin Description: "${job.serviceDescription}"')
                    : const Text('Regular Service'),
              ),
              if (job.acDetails != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.ac_unit, color: Color(0xFF64748B)),
                  title: Text(job.acDetails!),
                  subtitle: Text('Scheduled: ${job.scheduledDate} (${job.timeSlot})'),
                ),
              const Divider(height: 24),

              const Text('Quick Operations', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryBlue)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.location_searching_rounded, color: Color(0xFF38BDF8), size: 16),
                      label: const Text('Live Map Tracking', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        Navigator.pop(sheetCtx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TechnicianLiveTrackingScreen(
                              jobId: job.id,
                              initialJobNumber: job.jobNumber,
                              initialCustomerName: job.customerName,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.receipt_long, size: 16),
                      label: const Text('Custom Bill', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        Navigator.pop(sheetCtx);
                        _handleCustomBill(context, ref, job);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0D9488),
                    side: const BorderSide(color: Color(0xFF0D9488)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.assignment_outlined, size: 16),
                  label: const Text('Open Field Service Report (FSR)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    Navigator.pop(sheetCtx);
                    _openFSRForJob(context, ref, job);
                  },
                ),
              ),
              if (job.status == 'IN_PROGRESS' || job.status == 'OTP_PENDING') ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: job.status == 'OTP_PENDING' ? const Color(0xFFEA580C) : AppTheme.accentEmerald,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: Icon(job.status == 'OTP_PENDING' ? Icons.lock_clock_outlined : Icons.verified_user_outlined, size: 16),
                    label: Text(
                      job.status == 'OTP_PENDING' ? 'Enter Customer OTP & Close Ticket' : 'Verify Customer OTP & Close Ticket',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      Navigator.pop(sheetCtx);
                      _showVerifyOtpDialog(context, ref, job);
                    },
                  ),
                ),
              ],
              if (ref.watch(authStateProvider)?.role == UserRole.admin && job.status != 'COMPLETED') ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEA580C),
                      side: const BorderSide(color: Color(0xFFEA580C)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                    label: const Text('Reassign to Another Technician', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.pop(sheetCtx);
                      _showReassignJobDialog(context, ref, job);
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showJobOverview(context, ref),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _showJobOverview(context, ref),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(job.jobNumber, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                        const SizedBox(width: 6),
                        IconButton(
                          icon: const Icon(Icons.phone, color: Color(0xFF16A34A), size: 18),
                          tooltip: 'Call Customer',
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(4),
                          onPressed: () => launchUrl(Uri.parse('tel:${job.customerPhone}')),
                        ),
                      ],
                    ),
                    _JobStatusBadge(status: job.status),
                  ],
                ),
                const SizedBox(height: 8),
                Text(job.serviceName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                if (job.serviceDescription != null && job.serviceDescription!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.assignment_outlined, size: 14, color: AppTheme.primaryBlue),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Admin Description: ${job.serviceDescription}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B), fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                InkWell(
                  onTap: () => launchUrl(Uri.parse('tel:${job.customerPhone}')),
                  child: Row(
                    children: [
                      const Icon(Icons.phone_in_talk, size: 14, color: Color(0xFF16A34A)),
                      const SizedBox(width: 4),
                      Text(
                        'Customer: ${job.customerName} (${job.customerPhone})',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF16A34A), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text('Address: ${job.address}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                if (job.acDetails != null)
                  Text('Unit: ${job.acDetails}', style: const TextStyle(fontSize: 12, color: Color(0xFF0D9488), fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text('Scheduled: ${job.scheduledDate} (${job.timeSlot})', style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.location_searching_rounded, color: Color(0xFF38BDF8), size: 16),
                    label: const Text('📍 Open Live Map Tracking', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TechnicianLiveTrackingScreen(
                            jobId: job.id,
                            initialJobNumber: job.jobNumber,
                            initialCustomerName: job.customerName,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            if (job.status == 'OTP_PENDING') ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFDBA74)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_clock_rounded, size: 18, color: Color(0xFFEA580C)),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'OTP verification pending for ticket closure. Tap "Enter OTP & Close" below.',
                        style: TextStyle(fontSize: 11, color: Color(0xFFC2410C), fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const Divider(height: 20),

            // Action Status Progression buttons & Custom Bill
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
                  if (job.status == 'IN_PROGRESS' || job.status == 'OTP_PENDING') ...[
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add_shopping_cart, size: 14),
                      label: const Text('Add Spare Part', style: TextStyle(fontSize: 11)),
                      onPressed: () => _showAddPartDialog(context, ref, job.id),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: job.status == 'OTP_PENDING' ? const Color(0xFFEA580C) : AppTheme.accentEmerald,
                      ),
                      icon: Icon(
                        job.status == 'OTP_PENDING' ? Icons.lock_clock_outlined : Icons.verified_user_outlined,
                        size: 14,
                      ),
                      label: Text(
                        job.status == 'OTP_PENDING' ? 'Enter OTP & Close' : 'Verify OTP & Close',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => _showVerifyOtpDialog(context, ref, job),
                    ),
                  ],
                  if (job.status == 'COMPLETED') ...[
                    OutlinedButton.icon(
                      icon: const Icon(Icons.receipt, size: 14),
                      label: const Text('Generate Invoice', style: TextStyle(fontSize: 11)),
                      onPressed: () => _handleGenerateInvoice(context, ref, job),
                    ),
                  ],
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.receipt_long, size: 14),
                    label: const Text('🧾 Custom Bill', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    onPressed: () => _handleCustomBill(context, ref, job),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0D9488),
                      side: const BorderSide(color: Color(0xFF0D9488)),
                    ),
                    icon: const Icon(Icons.assignment_outlined, size: 14),
                    label: const Text('📋 Field Report (FSR)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    onPressed: () => _openFSRForJob(context, ref, job),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: job.latitude == null ? const Color(0xFFEA580C) : const Color(0xFF0284C7),
                      side: BorderSide(color: job.latitude == null ? const Color(0xFFEA580C) : const Color(0xFF0284C7)),
                    ),
                    icon: Icon(job.latitude == null ? Icons.add_location_alt_outlined : Icons.link_rounded, size: 14),
                    label: Text(
                      job.latitude == null ? '📍 Set Location Link' : 'Location Link',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => _showSetJobLocationDialog(context, ref, job),
                  ),
                  if (ref.watch(authStateProvider)?.role == UserRole.admin && job.status != 'COMPLETED') ...[
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFEA580C),
                        side: const BorderSide(color: Color(0xFFEA580C)),
                      ),
                      icon: const Icon(Icons.swap_horiz_rounded, size: 14),
                      label: const Text('Reassign Tech', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      onPressed: () => _showReassignJobDialog(context, ref, job),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);
  }

  void _handleGenerateInvoice(BuildContext context, WidgetRef ref, ServiceJobModel job) async {
    try {
      final check = await ref.read(apiRepositoryProvider).checkJobInvoice(job.id);
      if (check['hasInvoice'] == true && check['invoice'] != null) {
        if (!context.mounted) return;
        _showDuplicateBillDialog(
          context,
          ref,
          job,
          check['invoice'],
          onRecreate: () async {
            await _executeGenerateInvoice(context, ref, job, replaceExisting: true);
          },
          onDuplicate: () async {
            await _executeGenerateInvoice(context, ref, job, allowDuplicate: true);
          },
        );
        return;
      }

      await _executeGenerateInvoice(context, ref, job);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invoice check error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _executeGenerateInvoice(BuildContext context, WidgetRef ref, ServiceJobModel job, {bool allowDuplicate = false, bool replaceExisting = false}) async {
    try {
      await ref.read(apiRepositoryProvider).generateInvoiceFromJob(
            jobId: job.id,
            allowDuplicate: allowDuplicate,
            replaceExisting: replaceExisting,
          );
      ref.refresh(serviceJobsProvider(null));
      ref.refresh(invoicesProvider);
      ref.refresh(dashboardStatsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice generated from completed job!'), backgroundColor: AppTheme.accentEmerald),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invoice error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _handleCustomBill(BuildContext context, WidgetRef ref, ServiceJobModel job) async {
    try {
      final check = await ref.read(apiRepositoryProvider).checkJobInvoice(job.id);
      if (check['hasInvoice'] == true && check['invoice'] != null) {
        if (!context.mounted) return;
        _showDuplicateBillDialog(
          context,
          ref,
          job,
          check['invoice'],
          onRecreate: () async {
            await ref.read(apiRepositoryProvider).deleteInvoice(check['invoice']['id']);
            ref.refresh(invoicesProvider);
            ref.refresh(serviceJobsProvider(null));
            if (context.mounted) {
              _showCustomBillDialog(context, ref, job);
            }
          },
          onDuplicate: () {
            _showCustomBillDialog(context, ref, job, allowDuplicate: true);
          },
        );
        return;
      }

      _showCustomBillDialog(context, ref, job);
    } catch (e) {
      if (context.mounted) {
        _showCustomBillDialog(context, ref, job);
      }
    }
  }

  void _showDuplicateBillDialog(
    BuildContext context,
    WidgetRef ref,
    ServiceJobModel job,
    Map<String, dynamic> existingInv, {
    required VoidCallback onRecreate,
    required VoidCallback onDuplicate,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFEA580C)),
            SizedBox(width: 8),
            Text('Bill Already Exists', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('An invoice (${existingInv['invoiceNumber']}) of ₹${existingInv['totalAmount']} has already been generated for ${job.customerName}.'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
              child: Text(
                'Status: ${existingInv['status']} • Paid: ₹${existingInv['paidAmount']}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primaryBlue),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Would you like to view the existing bill, delete and re-create a fresh bill, or allow an additional duplicate bill?',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          OutlinedButton.icon(
            icon: const Icon(Icons.picture_as_pdf, size: 14),
            label: const Text('View Bill'),
            onPressed: () {
              Navigator.pop(ctx);
              _openInvoicePdf(context, ref, existingInv['id']);
            },
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            icon: const Icon(Icons.delete_outline, size: 14),
            label: const Text('Delete Old & Re-create'),
            onPressed: () {
              Navigator.pop(ctx);
              onRecreate();
            },
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
            child: const Text('Allow Duplicate'),
            onPressed: () {
              Navigator.pop(ctx);
              onDuplicate();
            },
          ),
        ],
      ),
    );
  }

  void _openInvoicePdf(BuildContext context, WidgetRef ref, String invoiceId) async {
    try {
      final url = await ref.read(apiRepositoryProvider).getInvoicePdfUrl(invoiceId);
      final uri = Uri.parse(url);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open PDF: $url')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _openFSRForJob(BuildContext context, WidgetRef ref, ServiceJobModel job) {
    final reportNoCtrl = TextEditingController();
    String reportType = 'DO_AND_CHARGE_REPAIR';
    final custNameCtrl = TextEditingController(text: job.customerName);
    final custAddrCtrl = TextEditingController(text: job.address);
    final phoneCtrl = TextEditingController(text: job.customerPhone);
    final modelCtrl = TextEditingController(text: job.acDetails ?? 'Split AC');
    final indoorSlCtrl = TextEditingController();
    final outdoorSlCtrl = TextEditingController();
    final runningCurrentCtrl = TextEditingController(text: '14.5 A');
    final suctionPressureCtrl = TextEditingController(text: '65 PSI');
    final dischargePressureCtrl = TextEditingController(text: '250 PSI');
    final roomTempCtrl = TextEditingController(text: '22 °C');
    final voltageCtrl = TextEditingController(text: '230 V');
    final obsCtrl = TextEditingController(text: job.diagnosis ?? job.notes ?? job.serviceDescription ?? 'Service completed.');
    final sugCtrl = TextEditingController(text: 'Clean filters every 15 days.');
    final custSignCtrl = TextEditingController(text: job.customerName);
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => DraggableScrollableSheet(
          initialChildSize: 0.92,
          minChildSize: 0.6,
          maxChildSize: 0.96,
          builder: (_, scrollCtrl) => Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              top: 16,
              left: 20,
              right: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: ListView(
              controller: scrollCtrl,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(Icons.assignment_outlined, color: AppTheme.primaryBlue, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Field Service Report Entry', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text('For Job: ${job.jobNumber} • ${job.customerName}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),

                const Text('Report Classification *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: reportType,
                  decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                  items: const [
                    DropdownMenuItem(value: 'DO_AND_CHARGE_REPAIR', child: Text('Do & Charge Repair')),
                    DropdownMenuItem(value: 'WARRANTY', child: Text('Warranty Service')),
                    DropdownMenuItem(value: 'COMMISSIONING', child: Text('Commissioning')),
                    DropdownMenuItem(value: 'MAIN_CONTACT', child: Text('Main Contact (AMC)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => reportType = val);
                  },
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: reportNoCtrl,
                  decoration: const InputDecoration(labelText: 'Report Number (Optional, auto-generated if blank)', hintText: 'e.g. 1110', isDense: true, border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),

                TextField(controller: custNameCtrl, decoration: const InputDecoration(labelText: 'Customer Name *', isDense: true, border: OutlineInputBorder())),
                const SizedBox(height: 8),
                TextField(controller: custAddrCtrl, decoration: const InputDecoration(labelText: 'Customer Address *', isDense: true, border: OutlineInputBorder())),
                const SizedBox(height: 8),
                TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Contact Phone', isDense: true, border: OutlineInputBorder())),
                const SizedBox(height: 12),

                const Text('Equipment & Serial Numbers', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 6),
                TextField(controller: modelCtrl, decoration: const InputDecoration(labelText: 'Model / Tonnage', isDense: true, border: OutlineInputBorder())),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: TextField(controller: indoorSlCtrl, decoration: const InputDecoration(labelText: 'Indoor SL No.', isDense: true, border: OutlineInputBorder()))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: outdoorSlCtrl, decoration: const InputDecoration(labelText: 'Outdoor SL No.', isDense: true, border: OutlineInputBorder()))),
                  ],
                ),
                const SizedBox(height: 12),

                const Text('Observations / Work & Action Taken *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 6),
                TextField(
                  controller: obsCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Outdoor fan motor replaced. Gas pressure restored. Unit tested and working well.',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(controller: sugCtrl, decoration: const InputDecoration(labelText: 'Suggestion to Customer', isDense: true, border: OutlineInputBorder())),
                const SizedBox(height: 12),

                const Text('Technical Parameters', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(child: TextField(controller: runningCurrentCtrl, decoration: const InputDecoration(labelText: 'Current (A)', isDense: true, border: OutlineInputBorder()))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: voltageCtrl, decoration: const InputDecoration(labelText: 'Voltage', isDense: true, border: OutlineInputBorder()))),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: TextField(controller: suctionPressureCtrl, decoration: const InputDecoration(labelText: 'Suction Press.', isDense: true, border: OutlineInputBorder()))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: dischargePressureCtrl, decoration: const InputDecoration(labelText: 'Discharge Press.', isDense: true, border: OutlineInputBorder()))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: roomTempCtrl, decoration: const InputDecoration(labelText: 'Room Temp', isDense: true, border: OutlineInputBorder()))),
                  ],
                ),
                const SizedBox(height: 12),

                TextField(controller: custSignCtrl, decoration: const InputDecoration(labelText: 'Customer Sign / Contact Person', isDense: true, border: OutlineInputBorder())),
                const SizedBox(height: 18),

                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: isSaving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.check_circle_outline, size: 20),
                  label: Text(isSaving ? 'Submitting...' : 'Save & Generate Official Report PDF', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (custNameCtrl.text.trim().isEmpty || obsCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Please enter customer name and observations')));
                            return;
                          }
                          setDialogState(() => isSaving = true);
                          try {
                            final repo = ref.read(apiRepositoryProvider);
                            final created = await repo.createFieldServiceReport(
                              serviceJobId: job.id,
                              reportNumber: reportNoCtrl.text.trim().isNotEmpty ? reportNoCtrl.text.trim() : null,
                              reportType: reportType,
                              customerName: custNameCtrl.text.trim(),
                              customerAddress: custAddrCtrl.text.trim().isNotEmpty ? custAddrCtrl.text.trim() : job.address,
                              contactPhone: phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : job.customerPhone,
                              attendingDate: DateFormat('yyyy-MM-dd').format(DateTime.now()),
                              modelNumber: modelCtrl.text.trim().isNotEmpty ? modelCtrl.text.trim() : null,
                              indoorSerialNo: indoorSlCtrl.text.trim().isNotEmpty ? indoorSlCtrl.text.trim() : null,
                              outdoorSerialNo: outdoorSlCtrl.text.trim().isNotEmpty ? outdoorSlCtrl.text.trim() : null,
                              runningCurrent: runningCurrentCtrl.text.trim().isNotEmpty ? runningCurrentCtrl.text.trim() : null,
                              unitCurrents: runningCurrentCtrl.text.trim().isNotEmpty ? runningCurrentCtrl.text.trim() : null,
                              suctionPressure: suctionPressureCtrl.text.trim().isNotEmpty ? suctionPressureCtrl.text.trim() : null,
                              pressSuc: suctionPressureCtrl.text.trim().isNotEmpty ? suctionPressureCtrl.text.trim() : null,
                              dischargePressure: dischargePressureCtrl.text.trim().isNotEmpty ? dischargePressureCtrl.text.trim() : null,
                              pressDis: dischargePressureCtrl.text.trim().isNotEmpty ? dischargePressureCtrl.text.trim() : null,
                              roomTemperature: roomTempCtrl.text.trim().isNotEmpty ? roomTempCtrl.text.trim() : null,
                              roomTemp: roomTempCtrl.text.trim().isNotEmpty ? roomTempCtrl.text.trim() : null,
                              voltage: voltageCtrl.text.trim().isNotEmpty ? voltageCtrl.text.trim() : null,
                              voltageL1N: voltageCtrl.text.trim().isNotEmpty ? voltageCtrl.text.trim() : null,
                              observations: obsCtrl.text.trim(),
                              suggestions: sugCtrl.text.trim().isNotEmpty ? sugCtrl.text.trim() : null,
                              customerSignName: custSignCtrl.text.trim().isNotEmpty ? custSignCtrl.text.trim() : null,
                            );

                            Navigator.pop(ctx);
                            ref.refresh(fieldServiceReportsProvider(null));

                            if (context.mounted) {
                              showDialog(
                                context: context,
                                builder: (sCtx) => AlertDialog(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  title: const Row(
                                    children: [
                                      Icon(Icons.check_circle, color: Color(0xFF16A34A)),
                                      SizedBox(width: 8),
                                      Text('FSR Generated!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    ],
                                  ),
                                  content: Text('Field Service Report #${created.reportNumber} has been generated for ${job.customerName}.'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(sCtx), child: const Text('Close')),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
                                      icon: const Icon(Icons.picture_as_pdf, size: 16),
                                      label: const Text('Open Report PDF'),
                                      onPressed: () async {
                                        Navigator.pop(sCtx);
                                        final url = await repo.getFieldServiceReportPdfUrl(created.id);
                                        launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                                      },
                                    ),
                                  ],
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() => isSaving = false);
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                            }
                          }
                        },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCustomBillDialog(BuildContext context, WidgetRef ref, ServiceJobModel job, {bool allowDuplicate = false}) {
    final List<Map<String, dynamic>> items = [
      {'description': job.serviceName, 'quantity': 1, 'unitPrice': 650.0},
    ];
    final paidAmountCtrl = TextEditingController(text: '767'); // Default ₹650 + 18% GST = ₹767
    final notesCtrl = TextEditingController(text: 'On-site service completed for ${job.acDetails ?? 'AC Unit'}');
    String paymentMethod = 'UPI';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          double subtotal = 0;
          for (final it in items) {
            final qty = (it['quantity'] as num?)?.toInt() ?? 1;
            final price = (it['unitPrice'] as num?)?.toDouble() ?? 0.0;
            subtotal += (qty * price);
          }
          final gstAmount = (subtotal * 0.18);
          final grandTotal = subtotal + gstAmount;
          final paidAmount = double.tryParse(paidAmountCtrl.text.trim()) ?? 0.0;
          final balance = grandTotal - paidAmount;

          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              top: 20,
              left: 18,
              right: 18,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
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
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(Icons.receipt_long, color: AppTheme.primaryBlue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Generate Custom Invoice', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            Text('For ${job.customerName} (${job.jobNumber})', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  // Line Items Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Bill Line Items & Spares', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      TextButton.icon(
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Item', style: TextStyle(fontSize: 12)),
                        onPressed: () {
                          setDialogState(() {
                            items.add({'description': '', 'quantity': 1, 'unitPrice': 0.0});
                          });
                        },
                      ),
                    ],
                  ),
                  ...items.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final it = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  initialValue: it['description'] as String?,
                                  decoration: const InputDecoration(
                                    labelText: 'Item / Part Name',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (val) {
                                    it['description'] = val;
                                  },
                                ),
                              ),
                              if (items.length > 1)
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                  onPressed: () {
                                    setDialogState(() {
                                      items.removeAt(idx);
                                    });
                                  },
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  initialValue: (it['quantity'] ?? 1).toString(),
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Qty',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (val) {
                                    setDialogState(() {
                                      it['quantity'] = int.tryParse(val) ?? 1;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  initialValue: (it['unitPrice'] ?? 0.0).toString(),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(
                                    labelText: 'Unit Price (₹)',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (val) {
                                    setDialogState(() {
                                      it['unitPrice'] = double.tryParse(val) ?? 0.0;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  '₹${(((it['quantity'] as num?)?.toInt() ?? 1) * ((it['unitPrice'] as num?)?.toDouble() ?? 0.0)).toStringAsFixed(0)}',
                                  textAlign: TextAlign.end,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryBlue),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 6),

                  // Quick Spares Pre-fill helper
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.add_shopping_cart, size: 16),
                    label: const Text('Add Spare from Inventory Catalog', style: TextStyle(fontSize: 12)),
                    onPressed: () async {
                      final parts = await ref.read(apiRepositoryProvider).getInventoryParts();
                      if (ctx.mounted) {
                        showModalBottomSheet(
                          context: ctx,
                          builder: (partCtx) => ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: parts.length,
                            itemBuilder: (_, i) {
                              final p = parts[i];
                              return ListTile(
                                leading: const Icon(Icons.hardware, color: AppTheme.primaryBlue),
                                title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                subtitle: Text('Stock: ${p.currentStock} • Selling Price: ₹${p.sellingPrice.toStringAsFixed(0)}'),
                                trailing: const Icon(Icons.add_circle, color: AppTheme.accentEmerald),
                                onTap: () {
                                  Navigator.pop(partCtx);
                                  setDialogState(() {
                                    items.add({
                                      'description': p.name,
                                      'quantity': 1,
                                      'unitPrice': p.sellingPrice > 0 ? p.sellingPrice : (p.unitPrice * 1.25).roundToDouble(),
                                    });
                                  });
                                },
                              );
                            },
                          ),
                        );
                      }
                    },
                  ),
                  const Divider(height: 24),

                  // Financial Settlement calculation (including 18% GST breakdown)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Subtotal:', style: TextStyle(fontSize: 13, color: Color(0xFF475569))),
                            Text('₹${subtotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('GST (18% - CGST 9% + SGST 9%):', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                            Text('+ ₹${gstAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF0F766E))),
                          ],
                        ),
                        const Divider(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Grand Total (Incl. GST):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            Text('₹${grandTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryBlue)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: paidAmountCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Settlement Amount Received (₹)',
                                  hintText: 'e.g. 500',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.currency_rupee, size: 18),
                                ),
                                onChanged: (_) => setDialogState(() {}),
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () {
                                setDialogState(() {
                                  paidAmountCtrl.text = grandTotal.toStringAsFixed(0);
                                });
                              },
                              child: const Text('Full Pay'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              balance <= 0 ? 'Status: Fully Paid' : 'Remaining On-Hold Balance:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: balance <= 0 ? const Color(0xFF16A34A) : const Color(0xFFEA580C),
                              ),
                            ),
                            Text(
                              balance <= 0 ? '₹0 (Settled)' : '₹${balance.toStringAsFixed(2)} (Pending)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: balance <= 0 ? const Color(0xFF16A34A) : const Color(0xFFEA580C),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Payment mode
                  DropdownButtonFormField<String>(
                    value: paymentMethod,
                    decoration: const InputDecoration(
                      labelText: 'Payment Mode',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'UPI', child: Text('UPI / GPay / PhonePe')),
                      DropdownMenuItem(value: 'CASH', child: Text('Cash in Hand')),
                      DropdownMenuItem(value: 'BANK_TRANSFER', child: Text('Bank Transfer / NEFT')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => paymentMethod = val);
                    },
                  ),
                  const SizedBox(height: 10),

                  TextField(
                    controller: notesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Notes / Remarks (Optional)',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 18),

                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.check_circle_outline, size: 20),
                    label: const Text('Issue Custom Bill & Generate PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    onPressed: subtotal <= 0
                        ? null
                        : () async {
                            try {
                              final validItems = items
                                  .where((it) => (it['description'] as String?)?.trim().isNotEmpty == true)
                                  .map((it) => {
                                        'description': (it['description'] as String).trim(),
                                        'quantity': (it['quantity'] as num?)?.toInt() ?? 1,
                                        'unitPrice': (it['unitPrice'] as num?)?.toDouble() ?? 0.0,
                                      })
                                  .toList();

                              if (validItems.isEmpty) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(content: Text('Please enter at least one line item')),
                                );
                                return;
                              }

                              final inv = await ref.read(apiRepositoryProvider).createCustomInvoice(
                                    customerName: job.customerName,
                                    customerPhone: job.customerPhone,
                                    customerEmail: job.customerEmail,
                                    serviceJobId: job.id,
                                    items: validItems,
                                    paymentMethod: paymentMethod,
                                    upfrontSettlementAmount: paidAmount,
                                    notes: notesCtrl.text.trim(),
                                    allowDuplicate: allowDuplicate,
                                  );

                              Navigator.pop(ctx);
                              ref.refresh(serviceJobsProvider(null));
                              ref.refresh(invoicesProvider);
                              ref.refresh(dashboardStatsProvider);

                              final invId = inv['id']?.toString() ?? '';
                              final invNumber = inv['invoiceNumber']?.toString() ?? 'INV';
                              final sub = (inv['subtotal'] as num?)?.toDouble() ?? subtotal;
                              final tax = (inv['taxAmount'] as num?)?.toDouble() ?? gstAmount;
                              final total = (inv['totalAmount'] as num?)?.toDouble() ?? grandTotal;
                              final settled = (inv['paidAmount'] as num?)?.toDouble() ?? paidAmount;
                              final remBalance = (inv['remainingBalance'] as num?)?.toDouble() ?? (total - settled);

                              if (context.mounted) {
                                showDialog(
                                  context: context,
                                  builder: (successCtx) => AlertDialog(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    title: const Row(
                                      children: [
                                        Icon(Icons.check_circle, color: Color(0xFF16A34A)),
                                        SizedBox(width: 8),
                                        Text('Custom Bill Issued!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      ],
                                    ),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Invoice Number: $invNumber', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                                        const SizedBox(height: 6),
                                        Text('Subtotal: ₹${sub.toStringAsFixed(2)}'),
                                        Text('GST (18%): ₹${tax.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF0F766E), fontWeight: FontWeight.w500)),
                                        Text('Total Bill: ₹${total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 4),
                                        Text('Settled Amount: ₹${settled.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.w600)),
                                        if (remBalance > 0)
                                          Text('On-Hold Balance: ₹${remBalance.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFFEA580C), fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 12),
                                        const Text('This bill is tracked live in the Admin Consol Billing records.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                      ],
                                    ),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(successCtx), child: const Text('Close')),
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                        icon: const Icon(Icons.picture_as_pdf, size: 16),
                                        label: const Text('Open PDF Invoice'),
                                        onPressed: () {
                                          Navigator.pop(successCtx);
                                          _openInvoicePdf(context, ref, invId);
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              }
                            } catch (e) {
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text('Failed to create invoice: $e'), backgroundColor: Colors.red),
                                );
                              }
                            }
                          },
                  ),
                ],
              ),
            ),
          );
        },
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
    bool isOtpSent = job.status == 'OTP_PENDING';
    String? sentToPhone = job.customerPhone;
    bool isSendingOtp = false;
    bool showAlternateInput = false;

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
                  'Verify customer 6-digit OTP received via SMS to safely confirm service closure.',
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
                      icon: isSendingOtp
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.send_outlined, size: 16),
                      label: Text(
                        isSendingOtp
                            ? 'Sending OTP via OpenSMS...'
                            : (useAlternatePhone ? 'Send OTP to Alternate Mobile' : 'Send Closure OTP to Customer'),
                      ),
                      onPressed: isSendingOtp
                          ? null
                          : () async {
                              final alt = useAlternatePhone ? altPhoneController.text.trim() : null;
                              if (useAlternatePhone && (alt == null || alt.length < 10)) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(content: Text('Please enter a valid 10-digit alternate mobile number')),
                                );
                                return;
                              }

                              setDialogState(() => isSendingOtp = true);
                              try {
                                await ref.read(apiRepositoryProvider).requestClosureOtp(job.id, alternatePhone: alt);
                                final target = alt ?? job.customerPhone;
                                setDialogState(() {
                                  isOtpSent = true;
                                  isSendingOtp = false;
                                  sentToPhone = target;
                                });
                                ref.refresh(serviceJobsProvider(null));
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(
                                      content: Text('OTP sent to customer mobile ($target) via SMS'),
                                      backgroundColor: const Color(0xFF15803D),
                                    ),
                                  );
                                }
                              } catch (e) {
                                setDialogState(() => isSendingOtp = false);
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
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Color(0xFF15803D), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'OTP sent directly to customer: ${sentToPhone ?? job.customerPhone}',
                                style: const TextStyle(color: Color(0xFF15803D), fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'The customer will receive the 6-digit OTP directly on their phone via SMS. Please ask the customer for the code once AC service is tested and completed.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF334155), height: 1.3),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Resend / Change Number Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF0284C7),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: isSendingOtp
                            ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.refresh, size: 15),
                        label: Text(
                          isSendingOtp ? 'Sending...' : 'Resend OTP via SMS',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        onPressed: isSendingOtp
                            ? null
                            : () async {
                                setDialogState(() => isSendingOtp = true);
                                try {
                                  final alt = showAlternateInput ? altPhoneController.text.trim() : null;
                                  await ref.read(apiRepositoryProvider).requestClosureOtp(job.id, alternatePhone: alt);
                                  final target = alt ?? sentToPhone ?? job.customerPhone;
                                  setDialogState(() {
                                    isSendingOtp = false;
                                    sentToPhone = target;
                                  });
                                  ref.refresh(serviceJobsProvider(null));
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(
                                        content: Text('Fresh OTP resent to customer ($target) via SMS'),
                                        backgroundColor: const Color(0xFF15803D),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  setDialogState(() => isSendingOtp = false);
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(content: Text('Error resending OTP: $e'), backgroundColor: Colors.red),
                                    );
                                  }
                                }
                              },
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF475569),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: Icon(showAlternateInput ? Icons.close : Icons.phone_android, size: 14),
                        label: Text(showAlternateInput ? 'Cancel' : 'Change No.', style: const TextStyle(fontSize: 11)),
                        onPressed: () {
                          setDialogState(() {
                            showAlternateInput = !showAlternateInput;
                          });
                        },
                      ),
                    ],
                  ),

                  if (showAlternateInput) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: altPhoneController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'New / Alternate Mobile No.',
                              hintText: 'e.g. 9876543210',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryBlue,
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: isSendingOtp
                              ? null
                              : () async {
                                  final alt = altPhoneController.text.trim();
                                  if (alt.length < 10) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      const SnackBar(content: Text('Please enter a valid 10-digit number')),
                                    );
                                    return;
                                  }
                                  setDialogState(() => isSendingOtp = true);
                                  try {
                                    await ref.read(apiRepositoryProvider).requestClosureOtp(job.id, alternatePhone: alt);
                                    setDialogState(() {
                                      isSendingOtp = false;
                                      sentToPhone = alt;
                                      showAlternateInput = false;
                                    });
                                    ref.refresh(serviceJobsProvider(null));
                                    if (ctx.mounted) {
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(
                                          content: Text('OTP sent to new mobile ($alt) via SMS'),
                                          backgroundColor: const Color(0xFF15803D),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    setDialogState(() => isSendingOtp = false);
                                    if (ctx.mounted) {
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                                      );
                                    }
                                  }
                                },
                          child: const Text('Send', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],

                  const SizedBox(height: 10),
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

  void _showReassignJobDialog(BuildContext context, WidgetRef ref, ServiceJobModel job) async {
    final techs = await ref.read(apiRepositoryProvider).getAllTechnicians();
    if (!context.mounted) return;

    if (techs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active technicians found to reassign to.')),
      );
      return;
    }

    String? selectedTechId = techs.first['id']?.toString();
    final reasonController = TextEditingController(text: 'Admin reassignment');
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.swap_horiz_rounded, color: Color(0xFFEA580C)),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Reassign: ${job.jobNumber}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFDBA74)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Customer: ${job.customerName} (${job.customerPhone})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFC2410C))),
                      const SizedBox(height: 2),
                      Text('Address: ${job.address}', style: const TextStyle(fontSize: 11, color: Color(0xFF9A3412))),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Select New Technician *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryBlue)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: selectedTechId,
                  isExpanded: true,
                  decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                  items: techs.map((t) {
                    final name = t['name'] ?? t['user']?['name'] ?? 'Technician';
                    final phone = t['phone'] ?? t['user']?['phone'] ?? '';
                    final areas = (t['serviceAreas'] as List?)?.join(', ') ?? '';
                    return DropdownMenuItem<String>(
                      value: t['id']?.toString(),
                      child: Text(
                        '$name ($phone)${areas.isNotEmpty ? " • $areas" : ""}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) => setDialogState(() => selectedTechId = val),
                ),
                const SizedBox(height: 12),
                const Text('Reassignment Reason:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Current technician delayed / Schedule adjustment',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEA580C)),
              onPressed: (selectedTechId == null || isSubmitting)
                  ? null
                  : () async {
                      setDialogState(() => isSubmitting = true);
                      try {
                        final res = await ref.read(apiRepositoryProvider).reassignJob(
                              jobId: job.id,
                              newTechnicianId: selectedTechId!,
                              reason: reasonController.text.trim(),
                            );
                        if (ctx.mounted) Navigator.pop(ctx);
                        ref.refresh(serviceJobsProvider(null));
                        ref.refresh(dashboardStatsProvider);
                        if (context.mounted) {
                          final techName = res['newTechnicianName'] ?? 'Technician';
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('✅ Ticket ${job.jobNumber} successfully reassigned to $techName!'),
                              backgroundColor: const Color(0xFF16A34A),
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isSubmitting = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Reassignment failed: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Confirm Reassign', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showSetJobLocationDialog(BuildContext context, WidgetRef ref, ServiceJobModel job) {
    final linkController = TextEditingController(text: job.locationLink ?? '');
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.pin_drop, color: Color(0xFFEA580C)),
              SizedBox(width: 8),
              Expanded(
                child: Text('Customer Location Link', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Job: ${job.jobNumber} (${job.customerName})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFC2410C))),
                const SizedBox(height: 4),
                Text('Address: ${job.address}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                const SizedBox(height: 12),
                const Text('Paste Google Maps location link or coordinates from technician / WhatsApp:', style: TextStyle(fontSize: 12, color: Color(0xFF475569))),
                const SizedBox(height: 8),
                TextField(
                  controller: linkController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'e.g. https://maps.app.goo.gl/... or 11.9320, 79.8280',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Supports: Google Maps app share links, WhatsApp location links, or latitude, longitude coordinates.',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
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
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEA580C)),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final input = linkController.text.trim();
                      if (input.isEmpty) return;
                      setDialogState(() => isSubmitting = true);
                      try {
                        await ref.read(apiRepositoryProvider).updateJobCustomerLocation(
                              jobId: job.id,
                              locationLink: input,
                            );
                        if (ctx.mounted) Navigator.pop(ctx);
                        ref.refresh(serviceJobsProvider(null));
                        ref.refresh(dashboardStatsProvider);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('📍 Exact customer location saved successfully!'),
                              backgroundColor: Color(0xFF16A34A),
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isSubmitting = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text('Failed to update location: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Save & Update', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
      case 'OTP_PENDING':
        bg = Colors.orange.shade100;
        fg = Colors.orange.shade900;
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
