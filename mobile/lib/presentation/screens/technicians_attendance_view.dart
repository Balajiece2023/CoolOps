import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../providers/app_providers.dart';
import 'technician_live_tracking_screen.dart';

class TechniciansAttendanceView extends ConsumerStatefulWidget {
  const TechniciansAttendanceView({super.key});

  @override
  ConsumerState<TechniciansAttendanceView> createState() => _TechniciansAttendanceViewState();
}

class _TechniciansAttendanceViewState extends ConsumerState<TechniciansAttendanceView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _technicians = [];
  List<Map<String, dynamic>> _attendanceLogs = [];
  List<Map<String, dynamic>> _consolidatedAttendance = [];
  Map<String, dynamic>? _attendanceSummary;
  List<Map<String, dynamic>> _liveLocations = [];
  bool _isLoading = true;
  String? _errorMessage;
  DateTime _selectedTimesheetDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(apiRepositoryProvider);
      final techs = await repo.getAllTechnicians();
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedTimesheetDate);
      final report = await repo.getAttendanceReport(startDate: dateStr, endDate: dateStr);
      final locations = await repo.getLiveTechnicianLocations();

      final logs = (report['logs'] as List?)?.map((e) => e as Map<String, dynamic>).toList() ?? [];
      final consolidated = (report['consolidated'] as List?)?.map((e) => e as Map<String, dynamic>).toList() ?? [];
      final summary = report['summary'] as Map<String, dynamic>?;

      setState(() {
        _technicians = techs;
        _attendanceLogs = logs;
        _consolidatedAttendance = consolidated;
        _attendanceSummary = summary;
        _liveLocations = locations;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadAttendanceForDate(DateTime date) async {
    setState(() {
      _selectedTimesheetDate = date;
      _isLoading = true;
    });

    try {
      final repo = ref.read(apiRepositoryProvider);
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final report = await repo.getAttendanceReport(startDate: dateStr, endDate: dateStr);

      final logs = (report['logs'] as List?)?.map((e) => e as Map<String, dynamic>).toList() ?? [];
      final consolidated = (report['consolidated'] as List?)?.map((e) => e as Map<String, dynamic>).toList() ?? [];
      final summary = report['summary'] as Map<String, dynamic>?;

      setState(() {
        _attendanceLogs = logs;
        _consolidatedAttendance = consolidated;
        _attendanceSummary = summary;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  String _formatIsoTime(String? iso) {
    if (iso == null || iso.isEmpty) return 'Active Now';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      final min = dt.minute.toString().padLeft(2, '0');
      return '$hour:$min $ampm';
    } catch (_) {
      return iso;
    }
  }

  String _formatIsoDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }

  void _showAddTechnicianDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController(text: 'Demo@1234');
    final phoneCtrl = TextEditingController();
    final areaCtrl = TextEditingController(text: 'Chennai Central');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.person_add_outlined, color: AppTheme.primaryBlue),
            SizedBox(width: 8),
            Text('Add Field Technician', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full Name *')),
              const SizedBox(height: 10),
              TextField(controller: emailCtrl, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email Address *')),
              const SizedBox(height: 10),
              TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Mobile Number *')),
              const SizedBox(height: 10),
              TextField(controller: passCtrl, decoration: const InputDecoration(labelText: 'Default Password *')),
              const SizedBox(height: 10),
              TextField(controller: areaCtrl, decoration: const InputDecoration(labelText: 'Primary Zone / Area')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty || emailCtrl.text.isEmpty || phoneCtrl.text.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Please fill mandatory fields')));
                return;
              }

              try {
                await ref.read(apiRepositoryProvider).createTechnician(
                      name: nameCtrl.text.trim(),
                      email: emailCtrl.text.trim(),
                      password: passCtrl.text.trim(),
                      phone: phoneCtrl.text.trim(),
                      serviceAreas: [areaCtrl.text.trim().isNotEmpty ? areaCtrl.text.trim() : 'Chennai Central'],
                    );
                if (ctx.mounted) Navigator.pop(ctx);
                _loadData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Technician registered successfully!'), backgroundColor: AppTheme.accentEmerald));
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error adding technician: $e'), backgroundColor: Colors.red));
                }
              }
            },
            child: const Text('Add Technician'),
          ),
        ],
      ),
    );
  }

  void _showEditTechnicianDialog(Map<String, dynamic> tech) {
    final user = tech['user'] ?? {};
    final nameCtrl = TextEditingController(text: user['name'] ?? '');
    final phoneCtrl = TextEditingController(text: user['phone'] ?? '');
    final areas = (tech['serviceAreas'] as List?)?.join(', ') ?? 'Chennai Central';
    final areaCtrl = TextEditingController(text: areas);
    final maxJobsCtrl = TextEditingController(text: '${tech['maxDailyJobs'] ?? 4}');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.edit_note_rounded, color: AppTheme.primaryBlue),
            SizedBox(width: 8),
            Text('Edit Technician', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full Name *')),
              const SizedBox(height: 10),
              TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Mobile Number *')),
              const SizedBox(height: 10),
              TextField(controller: areaCtrl, decoration: const InputDecoration(labelText: 'Assigned Zones (comma-separated)')),
              const SizedBox(height: 10),
              TextField(controller: maxJobsCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Max Daily Jobs Capacity')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              try {
                final areaList = areaCtrl.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
                await ref.read(apiRepositoryProvider).updateTechnician(
                      technicianId: tech['id'],
                      name: nameCtrl.text.trim(),
                      phone: phoneCtrl.text.trim(),
                      serviceAreas: areaList.isNotEmpty ? areaList : null,
                      maxDailyJobs: int.tryParse(maxJobsCtrl.text.trim()),
                    );
                if (ctx.mounted) Navigator.pop(ctx);
                _loadData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Technician details saved!'), backgroundColor: AppTheme.accentEmerald),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Update failed: $e'), backgroundColor: Colors.red));
                }
              }
            },
            child: const Text('Save Details'),
          ),
        ],
      ),
    );
  }

  void _showDeleteTechnicianDialog(Map<String, dynamic> tech) {
    final user = tech['user'] ?? {};
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.person_remove_outlined, color: AppTheme.accentRose),
            SizedBox(width: 8),
            Text('Deactivate Technician', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          'Are you sure you want to deactivate ${user['name']} (${user['email']})?\n\nThey will be removed from future dispatching and set to inactive.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentRose),
            onPressed: () async {
              try {
                await ref.read(apiRepositoryProvider).deleteTechnician(tech['id']);
                if (ctx.mounted) Navigator.pop(ctx);
                _loadData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Technician deactivated.')));
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
                }
              }
            },
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
  }

  void _showTechnicianReportModal(Map<String, dynamic> tech) {
    final user = tech['user'] ?? {};
    final techId = tech['id'] as String;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FutureBuilder<Map<String, dynamic>>(
        future: ref.read(apiRepositoryProvider).getTechnicianReport(techId),
        builder: (ctx, snapshot) {
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return Container(
            height: MediaQuery.of(ctx).size.height * 0.88,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // Drag handle & Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: AppTheme.primaryBlue.withOpacity(0.12),
                                child: const Icon(Icons.assessment_outlined, color: AppTheme.primaryBlue, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user['name'] ?? 'Technician',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  Text(
                                    '${user['phone'] ?? ''} • Individual Performance Report',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                Expanded(
                  child: snapshot.connectionState == ConnectionState.waiting
                      ? const Center(child: CircularProgressIndicator())
                      : snapshot.hasError
                          ? Center(child: Text('Error loading report: ${snapshot.error}', style: const TextStyle(color: Colors.red)))
                          : _buildReportDetails(snapshot.data!, techId),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildReportDetails(Map<String, dynamic> data, String techId) {
    final metrics = (data['metrics'] as Map<String, dynamic>?) ?? {};
    final timesheets = (data['timesheetSummary']?['sessions'] as List?) ??
        (data['attendances'] as List?) ??
        (data['timesheets'] as List?) ??
        [];
    final recentJobs = (data['recentJobs'] as List?) ??
        (data['orderHistory'] as List?) ??
        [];
    final invoices = (data['invoices'] as List?) ?? [];

    final totalBookings = metrics['totalJobsAssigned'] ?? metrics['totalBookings'] ?? recentJobs.length;
    final completedJobs = metrics['completedJobs'] ?? 0;
    final loggedHours = metrics['totalTimesheetHours'] ?? metrics['totalHoursWorked'] ?? 0;
    final revenue = metrics['totalRevenueGenerated'] ?? metrics['revenueBilled'] ?? 0;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Key Performance Metric Cards Grid
              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      label: 'Total Bookings',
                      value: '$totalBookings',
                      icon: Icons.assignment_outlined,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricTile(
                      label: 'Completed Jobs',
                      value: '$completedJobs',
                      icon: Icons.check_circle_outline,
                      color: const Color(0xFF16A34A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      label: 'Logged Hours',
                      value: '${loggedHours}h',
                      icon: Icons.timer_outlined,
                      color: AppTheme.accentTeal,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricTile(
                      label: 'Revenue Billed',
                      value: '₹$revenue',
                      icon: Icons.currency_rupee,
                      color: AppTheme.accentAmber,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Timesheet Shift Breakdown
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Timesheet Shifts & Clock-in History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  Text('${timesheets.length} Sessions', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ],
              ),
              const SizedBox(height: 10),
              if (timesheets.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12)),
                  child: const Text('No clock-in shift intervals recorded yet.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                )
              else
                ...timesheets.take(5).map((s) {
                  final inTime = _formatIsoTime(s['clockInAt']);
                  final outTime = _formatIsoTime(s['clockOutAt']);
                  final date = _formatIsoDate(s['date'] ?? s['clockInAt']);
                  final mins = s['totalMinutes'] ?? 0;
                  final dur = '${(mins / 60).floor()}h ${mins % 60}m';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.schedule, size: 18, color: AppTheme.primaryBlue),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(date, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                Text('Clock In: $inTime  •  Out: $outTime', style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(6)),
                            child: Text(dur, style: const TextStyle(color: Color(0xFF15803D), fontWeight: FontWeight.bold, fontSize: 11)),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 24),

              // Recent Service Bookings & Orders History
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Recent Orders & Bookings History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  Text('${recentJobs.length} Orders', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ],
              ),
              const SizedBox(height: 10),
              if (recentJobs.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12)),
                  child: const Text('No recent service bookings found for technician.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                )
              else
                ...recentJobs.take(5).map((job) {
                  final status = job['status'] as String? ?? 'PENDING';
                  final booking = job['booking'] ?? {};
                  final customer = booking['customer'] ?? {};
                  final serviceName = booking['serviceType']?['name'] ?? 'AC Service';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(job['jobNumber'] ?? 'JOB', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryBlue)),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
                                      child: Text(status.replaceAll('_', ' '), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text('$serviceName • ${customer['name'] ?? 'Customer'}', style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
                                Text('Scheduled: ${job['scheduledDate'] ?? ''}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),

        // Download Detailed Report Action Bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            border: Border(top: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.redAccent, size: 20),
                  label: const Text('Download Detailed PDF Report', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  onPressed: () async {
                    try {
                      final pdfUrl = await ref.read(apiRepositoryProvider).getTechnicianReportPdfUrl(techId);
                      final uri = Uri.parse(pdfUrl);
                      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
                      if (!launched) {
                        await Clipboard.setData(ClipboardData(text: pdfUrl));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Report link copied to clipboard: $pdfUrl'),
                              backgroundColor: AppTheme.accentEmerald,
                            ),
                          );
                        }
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error downloading report: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile({required String label, required String value, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
              Icon(icon, color: color, size: 18),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Technicians & Operations', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryBlue,
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: AppTheme.primaryBlue,
          tabs: const [
            Tab(icon: Icon(Icons.people_alt_outlined), text: 'Roster'),
            Tab(icon: Icon(Icons.location_searching_rounded), text: 'Live Radar'),
            Tab(icon: Icon(Icons.timelapse_outlined), text: 'Timesheets'),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryBlue,
        icon: const Icon(Icons.add),
        label: const Text('Add Tech'),
        onPressed: _showAddTechnicianDialog,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text('Error: $_errorMessage', style: const TextStyle(color: Colors.red)))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTechniciansList(),
                    _buildLiveRadarList(),
                    _buildAttendanceList(),
                  ],
                ),
    );
  }

  Widget _buildTechniciansList() {
    if (_technicians.isEmpty) {
      return const Center(child: Text('No technicians found'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _technicians.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final tech = _technicians[i];
        final user = tech['user'] ?? {};
        final bool isOnline = tech['isOnline'] == true;
        final bool isActive = user['isActive'] == true;
        final areas = (tech['serviceAreas'] as List?)?.join(', ') ?? 'Chennai';

        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: isOnline ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                  child: Icon(
                    isOnline ? Icons.engineering : Icons.person_outline,
                    color: isOnline ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              user['name'] ?? 'Tech',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isOnline ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isOnline ? 'ONLINE' : 'OFFLINE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isOnline ? const Color(0xFF15803D) : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                          if (!isActive) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: const Color(0xFFFFE4E6), borderRadius: BorderRadius.circular(4)),
                              child: const Text('INACTIVE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('${user['phone'] ?? ''} • ${user['email'] ?? ''}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      Text('Zones: $areas', style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
                    ],
                  ),
                ),
                if (isActive) ...[
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.indigo, size: 20),
                    tooltip: 'Technician Dossier & Report',
                    onPressed: () => _showTechnicianReportModal(tech),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: AppTheme.primaryBlue, size: 20),
                    tooltip: 'Edit Details',
                    onPressed: () => _showEditTechnicianDialog(tech),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppTheme.accentRose, size: 20),
                    tooltip: 'Deactivate',
                    onPressed: () => _showDeleteTechnicianDialog(tech),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLiveRadarList() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_liveLocations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.radar_rounded, size: 64, color: isDark ? AppTheme.spotifyGreen : AppTheme.primaryBlue),
              const SizedBox(height: 12),
              const Text('No Technicians Currently Online', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 6),
              Text(
                'When field technicians toggle "Online" in their app, their live GPS coordinates and active service dispatch appear here in realtime.',
                textAlign: TextAlign.center,
                style: TextStyle(color: isDark ? AppTheme.textMediumEmphasis : const Color(0xFF64748B), fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Live GPS Tactical Map Card with OpenStreetMap
        Card(
          elevation: 2,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: SizedBox(
            height: 280,
            child: Stack(
              children: [
                Builder(
                  builder: (ctx) {
                    ll.LatLng centerPoint = const ll.LatLng(11.9416, 79.8083); // Puducherry default
                    if (_liveLocations.isNotEmpty) {
                      final first = _liveLocations.first;
                      final rawLat = first['currentLatitude'];
                      final rawLng = first['currentLongitude'];
                      final double lat = (rawLat is num) ? rawLat.toDouble() : 11.9416;
                      final double lng = (rawLng is num) ? rawLng.toDouble() : 79.8083;
                      centerPoint = ll.LatLng(lat, lng);
                    }

                    return FlutterMap(
                      options: MapOptions(
                        initialCenter: centerPoint,
                        initialZoom: 12.0,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.acservice.caringcooltech',
                        ),
                        MarkerLayer(
                          markers: _liveLocations.map((tech) {
                            final user = tech['user'] ?? {};
                            final name = user['name'] ?? 'Tech';
                            final rawLat = tech['currentLatitude'];
                            final rawLng = tech['currentLongitude'];
                            final double lat = (rawLat is num) ? rawLat.toDouble() : 11.9416;
                            final double lng = (rawLng is num) ? rawLng.toDouble() : 79.8083;

                            return Marker(
                              point: ll.LatLng(lat, lng),
                              width: 84,
                              height: 64,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0F172A),
                                      borderRadius: BorderRadius.circular(6),
                                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                                    ),
                                    child: Text(
                                      name,
                                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF16A34A),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                      boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4)],
                                    ),
                                    child: const Icon(Icons.two_wheeler, color: Colors.white, size: 16),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    );
                  },
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(color: Color(0xFF16A34A), shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${_liveLocations.length} Online Field Techs',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF166534)),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withOpacity(0.9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'OPENSTREETMAP LIVE GPS',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        ..._liveLocations.map((item) {
          final user = item['user'] ?? {};
          final lat = item['currentLatitude'];
          final lng = item['currentLongitude'];
          final jobs = (item['serviceJobs'] as List?) ?? [];
          final hasActiveJob = jobs.isNotEmpty;
          final areas = (item['serviceAreas'] as List?)?.join(', ') ?? '';

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.spotifySurface : const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.gps_fixed_rounded,
                          color: isDark ? AppTheme.spotifyGreen : const Color(0xFF16A34A),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user['name'] ?? 'Technician',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${user['phone'] ?? ''} • $areas',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppTheme.textMediumEmphasis : const Color(0xFF64748B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: (isDark ? AppTheme.spotifyGreen : const Color(0xFF16A34A)).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: isDark ? AppTheme.spotifyGreen : const Color(0xFF16A34A),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'ONLINE',
                              style: TextStyle(
                                color: isDark ? AppTheme.spotifyGreen : const Color(0xFF15803D),
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.spotifyBlack : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? AppTheme.spotifyBorder : const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.my_location_rounded,
                          size: 16,
                          color: isDark ? AppTheme.spotifyGreen : AppTheme.primaryBlue,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'GPS Coords: ${lat ?? '13.0827'}, ${lng ?? '80.2707'} (Chennai Hub)',
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppTheme.textHighEmphasis : const Color(0xFF1E293B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hasActiveJob) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: (isDark ? AppTheme.spotifyGreen : AppTheme.accentTeal).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Active Dispatch: ${jobs[0]['booking']?['serviceType']?['name'] ?? 'HVAC Service'} (${jobs[0]['booking']?['customer']?['name'] ?? ''})',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppTheme.spotifyGreen : AppTheme.accentTeal,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.location_searching_rounded, color: Color(0xFF38BDF8), size: 16),
                      label: const Text('📍 Open Live Map Tracking', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        final activeJobId = hasActiveJob ? (jobs[0]['id'] ?? 'demo-job-id') : 'demo-job-id';
                        final jobNumber = hasActiveJob ? (jobs[0]['jobNumber'] ?? 'JOB-ACTIVE') : 'JOB-CHENNAI';
                        final custName = hasActiveJob ? (jobs[0]['booking']?['customer']?['name'] ?? 'Customer') : 'Customer Location';
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TechnicianLiveTrackingScreen(
                              jobId: activeJobId,
                              initialJobNumber: jobNumber,
                              initialCustomerName: custName,
                              initialTechName: user['name'] ?? 'Technician',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildAttendanceList() {
    final now = DateTime.now();
    final isToday = _selectedTimesheetDate.year == now.year &&
        _selectedTimesheetDate.month == now.month &&
        _selectedTimesheetDate.day == now.day;

    final summary = _attendanceSummary ?? {};
    final totalMins = summary['totalLoggedMinutes'] as int? ?? 0;
    final totalHoursStr = '${(totalMins / 60).floor()}h ${totalMins % 60}m';
    final activeTechsCount = summary['totalTechniciansActive'] ?? _consolidatedAttendance.where((t) => t['activeSession'] != null).length;
    final completedSessionsCount = summary['totalCompletedSessions'] ?? _attendanceLogs.where((l) => l['clockOutAt'] != null).length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Date Selector Bar
        Card(
          margin: const EdgeInsets.only(bottom: 14),
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  tooltip: 'Previous Day',
                  onPressed: () {
                    final prev = _selectedTimesheetDate.subtract(const Duration(days: 1));
                    _loadAttendanceForDate(prev);
                  },
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedTimesheetDate,
                      firstDate: DateTime(2025),
                      lastDate: DateTime.now().add(const Duration(days: 30)),
                    );
                    if (picked != null) {
                      _loadAttendanceForDate(picked);
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_month, color: AppTheme.primaryBlue, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('EEE, dd MMM yyyy').format(_selectedTimesheetDate),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        if (isToday) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(4)),
                            child: const Text('Today', style: TextStyle(color: Color(0xFF166534), fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  tooltip: 'Next Day',
                  onPressed: () {
                    final next = _selectedTimesheetDate.add(const Duration(days: 1));
                    _loadAttendanceForDate(next);
                  },
                ),
              ],
            ),
          ),
        ),

        if (_consolidatedAttendance.isEmpty && _attendanceLogs.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.access_time_rounded, size: 56, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text('No Timesheets on ${DateFormat('dd MMM yyyy').format(_selectedTimesheetDate)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 6),
                  const Text(
                    'No clock-in shift intervals were recorded by technicians for this date. Select another date above to view past shift histories.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                  ),
                ],
              ),
            ),
          )
        else ...[
          // Consolidated Timesheet Operations Header Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Field Shift Consolidation', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: const Color(0xFF16A34A).withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                        child: const Text('REALTIME GPS', style: TextStyle(color: Color(0xFF4ADE80), fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Active on Field', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                            const SizedBox(height: 2),
                            Text('$activeTechsCount Techs', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Completed Shifts', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                            const SizedBox(height: 2),
                            Text('$completedSessionsCount Shifts', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Total Logged Time', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                            const SizedBox(height: 2),
                            Text(totalHoursStr, style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 18)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // List of Consolidated Technician Cards
          if (_consolidatedAttendance.isNotEmpty)
            ..._consolidatedAttendance.map((techRecord) {
              final user = techRecord['user'] ?? {};
              final techName = user['name'] ?? techRecord['technicianName'] ?? 'Technician';
              final techPhone = user['phone'] ?? techRecord['phone'] ?? '';
              final techId = techRecord['technicianId'] as String? ?? '';
              final totalMinutes = techRecord['totalMinutes'] as int? ?? 0;
              final consStr = techRecord['consolidatedFormatted'] ?? '${(totalMinutes / 60).floor()}h ${totalMinutes % 60}m';
              final activeSession = techRecord['activeSession'];
              final sessions = (techRecord['sessions'] as List?) ?? [];
              final bool isWorkingNow = activeSession != null;

              final techObj = _technicians.firstWhere(
                (t) => t['id'] == techId,
                orElse: () => {
                  'id': techId,
                  'user': {'name': techName, 'phone': techPhone}
                },
              );

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Technician Header Row
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: isWorkingNow ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                            child: Icon(
                              isWorkingNow ? Icons.engineering : Icons.person_outline,
                              color: isWorkingNow ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(techName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                Text(techPhone, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isWorkingNow ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: isWorkingNow ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0)),
                            ),
                            child: Text(
                              isWorkingNow ? '🟢 ACTIVE (GPS ON)' : 'COMPLETED',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isWorkingNow ? const Color(0xFF15803D) : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Consolidated Duration Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.timer_outlined, size: 16, color: AppTheme.primaryBlue),
                                const SizedBox(width: 6),
                                Text('Consolidated Time: $consStr', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue, fontSize: 12)),
                              ],
                            ),
                            Text('${sessions.length} Shift Session${sessions.length > 1 ? "s" : ""}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Individual Shift Intervals breakdown
                      if (sessions.isNotEmpty) ...[
                        const Text('Shift Intervals & GPS Stamps (IST):', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                        const SizedBox(height: 6),
                        ...sessions.map((s) {
                          final inTime = _formatIsoTime(s['clockInAt']);
                          final outTime = _formatIsoTime(s['clockOutAt']);
                          final mins = (s['totalMinutes'] ?? s['durationMinutes']) as num? ?? 0;
                          final shiftDur = s['clockOutAt'] == null ? 'In Progress' : '${(mins / 60).floor()}h ${mins.toInt() % 60}m';
                          final lat = s['clockInLatitude'] as num?;
                          final lng = s['clockInLongitude'] as num?;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.login, size: 14, color: Color(0xFF16A34A)),
                                const SizedBox(width: 4),
                                Text('In: $inTime', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                                const SizedBox(width: 12),
                                const Icon(Icons.logout, size: 14, color: Color(0xFFDC2626)),
                                const SizedBox(width: 4),
                                Text('Out: $outTime', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                                const Spacer(),
                                Text(shiftDur, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                if (lat != null && lng != null) ...[
                                  const SizedBox(width: 6),
                                  const Icon(Icons.location_on, size: 12, color: AppTheme.primaryBlue),
                                ],
                              ],
                            ),
                          );
                        }),
                      ],
                      const SizedBox(height: 10),

                      // Action buttons: Overview details + PDF Download
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryBlue,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              icon: const Icon(Icons.assessment_outlined, size: 16),
                              label: const Text('View Overview', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              onPressed: () => _showTechnicianReportModal(techObj),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFCBD5E1)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.redAccent, size: 16),
                              label: const Text('Download PDF', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                              onPressed: () => _showTechnicianReportModal(techObj),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            })
          else
            ..._attendanceLogs.map((log) {
              final tech = log['technician']?['user'] ?? {};
              final date = _formatIsoDate(log['date'] ?? log['clockInAt']);
              final clockIn = _formatIsoTime(log['clockInAt']);
              final clockOut = _formatIsoTime(log['clockOutAt']);
              final totalMins = log['totalMinutes'] ?? 0;
              final hoursStr = '${(totalMins / 60).floor()}h ${totalMins % 60}m';

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tech['name'] ?? 'Technician', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text('$date • In: $clockIn  Out: $clockOut', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          ],
                        ),
                      ),
                      Text(hoursStr, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue, fontSize: 12)),
                    ],
                  ),
                ),
              );
            }),
        ],
      ],
    );
  }
}

class _RadarGridPainter extends CustomPainter {
  final bool isDark;
  _RadarGridPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.shortestSide * 0.48;

    final ringPaint = Paint()
      ..color = (isDark ? AppTheme.spotifyGreen : AppTheme.primaryBlue).withValues(alpha: isDark ? 0.12 : 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final crossPaint = Paint()
      ..color = (isDark ? AppTheme.spotifyGreen : AppTheme.primaryBlue).withValues(alpha: isDark ? 0.08 : 0.05)
      ..strokeWidth = 1.0;

    // Draw concentric rings
    canvas.drawCircle(center, maxRadius * 0.33, ringPaint);
    canvas.drawCircle(center, maxRadius * 0.66, ringPaint);
    canvas.drawCircle(center, maxRadius, ringPaint);

    // Crosshairs
    canvas.drawLine(Offset(center.dx, center.dy - maxRadius), Offset(center.dx, center.dy + maxRadius), crossPaint);
    canvas.drawLine(Offset(center.dx - maxRadius, center.dy), Offset(center.dx + maxRadius, center.dy), crossPaint);

    // Central hub dot
    final centerDotPaint = Paint()
      ..color = (isDark ? AppTheme.spotifyGreen : AppTheme.primaryBlue).withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 4, centerDotPaint);
  }

  @override
  bool shouldRepaint(covariant _RadarGridPainter oldDelegate) => oldDelegate.isDark != isDark;
}
