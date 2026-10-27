import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../providers/app_providers.dart';

class TechniciansAttendanceView extends ConsumerStatefulWidget {
  const TechniciansAttendanceView({super.key});

  @override
  ConsumerState<TechniciansAttendanceView> createState() => _TechniciansAttendanceViewState();
}

class _TechniciansAttendanceViewState extends ConsumerState<TechniciansAttendanceView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _technicians = [];
  List<Map<String, dynamic>> _attendanceLogs = [];
  List<Map<String, dynamic>> _liveLocations = [];
  bool _isLoading = true;
  String? _errorMessage;

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
      final logs = await repo.getAttendanceReport();
      final locations = await repo.getLiveTechnicianLocations();

      setState(() {
        _technicians = techs;
        _attendanceLogs = logs;
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
        // Live GPS Tactical Map Canvas Card
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            height: 240,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [const Color(0xFF141E18), const Color(0xFF0F1A13)]
                    : [const Color(0xFFF0FDF4), const Color(0xFFDCFCE7)],
              ),
              border: Border.all(color: isDark ? AppTheme.spotifyBorder : const Color(0xFFBBF7D0)),
            ),
            child: Stack(
              children: [
                // Radar grid lines
                Positioned.fill(
                  child: CustomPaint(
                    painter: _RadarGridPainter(isDark: isDark),
                  ),
                ),
                // Header badge
                Positioned(
                  top: 14,
                  left: 16,
                  right: 16,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isDark ? AppTheme.spotifyCard : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(color: Color(0xFF16A34A), shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${_liveLocations.length} Online Field Techs',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? AppTheme.textHighEmphasis : const Color(0xFF166534),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: (isDark ? AppTheme.spotifyGreen : AppTheme.primaryBlue).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'REALTIME GPS TRACKER',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppTheme.spotifyGreen : AppTheme.primaryBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Map markers for online technicians mapped to true coordinates
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (ctx, constraints) {
                      final w = constraints.maxWidth;
                      final h = constraints.maxHeight;
                      final centerX = w / 2;
                      final centerY = h / 2;

                      // Reference Central Hub: Chennai Center (13.0827° N, 80.2707° E)
                      const double hubLat = 13.0827;
                      const double hubLng = 80.2707;
                      // Max coordinate span (~15km radius) mapped to radar bounds
                      const double latSpan = 0.14;
                      const double lngSpan = 0.14;

                      return Stack(
                        children: [
                          // Central Operations Hub Pin
                          Positioned(
                            left: centerX - 24,
                            top: centerY + 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Chennai Hub',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppTheme.spotifyGreen : AppTheme.primaryBlue,
                                ),
                              ),
                            ),
                          ),
                          ..._liveLocations.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final tech = entry.value;
                            final user = tech['user'] ?? {};
                            final name = user['name'] ?? 'Tech';
                            
                            final rawLat = tech['currentLatitude'];
                            final rawLng = tech['currentLongitude'];
                            final double lat = (rawLat is num) ? rawLat.toDouble() : (13.0827 + ((idx * 0.02) - 0.02));
                            final double lng = (rawLng is num) ? rawLng.toDouble() : (80.2707 + ((idx * 0.025) - 0.02));

                            // Calculate projected offset relative to radar center
                            final dLng = (lng - hubLng) / lngSpan;
                            final dLat = (lat - hubLat) / latSpan;

                            // Clamp within visible radar bounds
                            final posX = (centerX + (dLng * (w * 0.42))).clamp(20.0, w - 80.0);
                            final posY = (centerY - (dLat * (h * 0.40))).clamp(38.0, h - 50.0);

                            return Positioned(
                              left: posX,
                              top: posY,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF16A34A),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF16A34A).withValues(alpha: 0.45),
                                          blurRadius: 8,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(Icons.two_wheeler_rounded, color: Colors.white, size: 14),
                                  ),
                                  const SizedBox(height: 3),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isDark ? AppTheme.spotifyBlack : Colors.white,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: isDark ? AppTheme.spotifyBorder : const Color(0xFFE2E8F0)),
                                      boxShadow: [
                                        BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 4),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF16A34A),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          name,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? AppTheme.textHighEmphasis : const Color(0xFF0F172A),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      );
                    },
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
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildAttendanceList() {
    if (_attendanceLogs.isEmpty) {
      return const Center(child: Text('No attendance or timesheet records yet.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _attendanceLogs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final log = _attendanceLogs[i];
        final tech = log['technician']?['user'] ?? {};
        final date = (log['date'] as String?)?.split('T')[0] ?? '';
        final clockIn = (log['clockInAt'] as String?)?.split('T')[1].split('.')[0] ?? '';
        final clockOut = log['clockOutAt'] != null ? (log['clockOutAt'] as String).split('T')[1].split('.')[0] : 'In Progress';
        final totalMins = log['totalMinutes'] ?? 0;
        final hoursStr = '${(totalMins / 60).floor()}h ${totalMins % 60}m';

        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(tech['name'] ?? 'Technician', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(date, style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primaryBlue, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.login_rounded, size: 14, color: Color(0xFF16A34A)),
                    const SizedBox(width: 4),
                    Text('In: $clockIn', style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 16),
                    const Icon(Icons.logout_rounded, size: 14, color: Color(0xFFDC2626)),
                    const SizedBox(width: 4),
                    Text('Out: $clockOut', style: const TextStyle(fontSize: 12)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(6)),
                      child: Text('Duration: $hoursStr', style: const TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold, fontSize: 11)),
                    ),
                  ],
                ),
                if (log['notes'] != null && (log['notes'] as String).isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('Notes: ${log['notes']}', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF64748B))),
                ],
              ],
            ),
          ),
        );
      },
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
