import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../providers/app_providers.dart';

class TechnicianTimesheetView extends ConsumerStatefulWidget {
  const TechnicianTimesheetView({super.key});

  @override
  ConsumerState<TechnicianTimesheetView> createState() => _TechnicianTimesheetViewState();
}

class _TechnicianTimesheetViewState extends ConsumerState<TechnicianTimesheetView> {
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _sessions = [];
  Map<String, dynamic>? _summary;
  int _totalMinutes = 0;
  bool _isActiveNow = false;

  @override
  void initState() {
    super.initState();
    _loadTimesheet();
  }

  Future<void> _loadTimesheet() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(apiRepositoryProvider);
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final report = await repo.getAttendanceReport(startDate: dateStr, endDate: dateStr);

      final logs = (report['logs'] as List?)?.map((e) => e as Map<String, dynamic>).toList() ?? [];
      final consolidated = (report['consolidated'] as List?)?.map((e) => e as Map<String, dynamic>).toList() ?? [];
      final summary = report['summary'] as Map<String, dynamic>?;

      int totalMins = 0;
      bool active = false;

      if (consolidated.isNotEmpty) {
        final c = consolidated.first;
        totalMins = (c['totalMinutes'] as num?)?.toInt() ?? 0;
        active = c['activeSession'] != null;
      } else {
        for (final l in logs) {
          totalMins += (l['totalMinutes'] as num?)?.toInt() ?? 0;
          if (l['clockInAt'] != null && l['clockOutAt'] == null) {
            active = true;
          }
        }
      }

      setState(() {
        _sessions = logs;
        _summary = summary;
        _totalMinutes = totalMins;
        _isActiveNow = active;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 90)),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadTimesheet();
    }
  }

  String _formatTime(String? isoString) {
    if (isoString == null) return '--:--';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return DateFormat('hh:mm a').format(dt);
    } catch (_) {
      return isoString;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isToday = DateUtils.isSameDay(_selectedDate, DateTime.now());
    final hours = _totalMinutes ~/ 60;
    final mins = _totalMinutes % 60;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Timesheet Tracker', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadTimesheet,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadTimesheet,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Date Selector Bar
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () {
                        setState(() {
                          _selectedDate = _selectedDate.subtract(const Duration(days: 1));
                        });
                        _loadTimesheet();
                      },
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.calendar_today, size: 16, color: AppTheme.primaryBlue),
                                  const SizedBox(width: 8),
                                  Text(
                                    DateFormat('EEEE, dd MMM yyyy').format(_selectedDate),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ],
                              ),
                              if (isToday)
                                const Text(
                                  '(Today)',
                                  style: TextStyle(fontSize: 11, color: AppTheme.primaryBlue, fontWeight: FontWeight.w600),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: isToday
                          ? null
                          : () {
                              setState(() {
                                _selectedDate = _selectedDate.add(const Duration(days: 1));
                              });
                              _loadTimesheet();
                            },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Summary Metrics Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isActiveNow
                      ? [const Color(0xFF16A34A), const Color(0xFF15803D)]
                      : [AppTheme.primaryBlue, const Color(0xFF1E40AF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: _isActiveNow ? Colors.lightGreenAccent : Colors.white70,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isActiveNow ? 'Currently Active on Field' : 'Day Completed / Off Shift',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_sessions.length} Shift Session${_sessions.length == 1 ? '' : 's'}',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Total Hours Logged', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    '${hours}h ${mins}m',
                    style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'All shifts record real-time GPS locations and auto-sync with company payroll records.',
                    style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Shifts Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Shift Intervals & Locations', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text('${_sessions.length} recorded', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              ],
            ),
            const SizedBox(height: 10),

            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_errorMessage != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 36),
                      const SizedBox(height: 8),
                      Text('Failed to load: $_errorMessage', textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _loadTimesheet, child: const Text('Retry')),
                    ],
                  ),
                ),
              )
            else if (_sessions.isEmpty)
              Card(
                elevation: 0,
                color: const Color(0xFFF8FAFC),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                  child: Column(
                    children: [
                      Icon(Icons.schedule, size: 40, color: Color(0xFF94A3B8)),
                      SizedBox(height: 10),
                      Text('No Shift Records for this Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      SizedBox(height: 4),
                      Text(
                        'Clock-in from the jobs screen to begin logging shift attendance.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              )
            else
              ..._sessions.asMap().entries.map((entry) {
                final idx = entry.key;
                final session = entry.value;
                final inAt = session['clockInAt'] as String?;
                final outAt = session['clockOutAt'] as String?;
                final isCurrent = inAt != null && outAt == null;
                final totalMin = (session['totalMinutes'] as num?)?.toInt() ?? 0;
                final sessionHours = totalMin ~/ 60;
                final sessionMins = totalMin % 60;
                final inLat = session['clockInLatitude'];
                final inLng = session['clockInLongitude'];
                final outLat = session['clockOutLatitude'];
                final outLng = session['clockOutLongitude'];
                final notes = session['notes'] as String?;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isCurrent ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
                      width: isCurrent ? 1.5 : 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: isCurrent ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                                  child: Text(
                                    '#${_sessions.length - idx}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isCurrent ? const Color(0xFF166534) : const Color(0xFF475569),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isCurrent ? 'Active Live Shift' : 'Completed Shift',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: isCurrent ? const Color(0xFF16A34A) : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isCurrent ? const Color(0xFFDCFCE7) : const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isCurrent ? 'Running...' : '${sessionHours}h ${sessionMins}m',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isCurrent ? const Color(0xFF166534) : AppTheme.primaryBlue,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.login, size: 14, color: Color(0xFF16A34A)),
                                      SizedBox(width: 4),
                                      Text('Clock In', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(_formatTime(inAt), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  if (inLat != null && inLng != null)
                                    Text(
                                      'GPS: ${inLat.toStringAsFixed(4)}, ${inLng.toStringAsFixed(4)}',
                                      style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                                    ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.logout, size: 14, color: isCurrent ? const Color(0xFF94A3B8) : const Color(0xFFDC2626)),
                                      const SizedBox(width: 4),
                                      Text('Clock Out', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isCurrent ? 'In Progress' : _formatTime(outAt),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: isCurrent ? const Color(0xFF16A34A) : Colors.black87,
                                    ),
                                  ),
                                  if (outLat != null && outLng != null)
                                    Text(
                                      'GPS: ${outLat.toStringAsFixed(4)}, ${outLng.toStringAsFixed(4)}',
                                      style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (notes != null && notes.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.note_outlined, size: 14, color: Color(0xFF64748B)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    notes,
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF334155)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

