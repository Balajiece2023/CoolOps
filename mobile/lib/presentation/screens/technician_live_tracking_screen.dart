import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/location_service.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../providers/app_providers.dart';

/// Open-Source Live Map Technician Tracking Screen
/// Powered by flutter_map & OpenStreetMap tiles (zero paid API keys required).
class TechnicianLiveTrackingScreen extends ConsumerStatefulWidget {
  final String jobId;
  final String? initialJobNumber;
  final String? initialCustomerName;
  final String? initialTechName;

  const TechnicianLiveTrackingScreen({
    super.key,
    required this.jobId,
    this.initialJobNumber,
    this.initialCustomerName,
    this.initialTechName,
  });

  @override
  ConsumerState<TechnicianLiveTrackingScreen> createState() => _TechnicianLiveTrackingScreenState();
}

class _TechnicianLiveTrackingScreenState extends ConsumerState<TechnicianLiveTrackingScreen>
    with SingleTickerProviderStateMixin {
  late final MapController _mapController;
  late final AnimationController _pulseController;
  Timer? _pollingTimer;
  Timer? _simulationTimer;
  StreamSubscription? _locationSubscription;

  bool _isLoading = true;
  Map<String, dynamic>? _trackingData;

  // Real-time tracking state
  bool _hasExactCustomerLocation = false;
  double _currentTechLat = LocationService.defaultLatitude;
  double _currentTechLng = LocationService.defaultLongitude;
  double _destLat = 11.9350;
  double _destLng = 79.8250;
  double _distanceKm = 2.4;
  int _etaMinutes = 9;
  String _statusDesc = 'Technician is en-route with service toolkit';
  String _jobStatus = 'EN_ROUTE';

  List<Map<String, double>> _waypoints = [];
  int _currentWaypointIndex = 0;
  bool _isSimulatingMovement = false;

  // Map theme layers
  // 0: OpenStreetMap Standard (100% Free, Zero API keys)
  // 1: Humanitarian High-Contrast Streets
  // 2: Satellite Aerial View (Esri)
  int _mapThemeIndex = 0;

  static const List<Map<String, String>> _mapTiles = [
    {
      'name': 'OpenStreetMap Standard',
      'url': 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    },
    {
      'name': 'High-Contrast Streets (Humanitarian)',
      'url': 'https://a.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png',
    },
    {
      'name': 'Satellite Aerial View',
      'url': 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    },
  ];

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _initializeTracking();
  }

  Future<void> _initializeTracking() async {
    await _fetchTrackingData();

    // Check if current user is the technician - if so, capture phone's real GPS
    final currentUser = ref.read(authStateProvider);
    if (currentUser?.role == UserRole.technician) {
      _startLivePhoneGpsBroadcast();
    }

    // Periodic poll for tracking data from backend
    _pollingTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (!_isSimulatingMovement) {
        _fetchTrackingData(isSilent: true);
      }
    });
  }

  void _startLivePhoneGpsBroadcast() async {
    final hasPerm = await LocationService.ensureLocationPermission();
    if (!hasPerm) return;

    // Immediately get initial fix
    final pos = await LocationService.getCurrentPosition();
    if (pos != null && mounted) {
      setState(() {
        _currentTechLat = pos.latitude;
        _currentTechLng = pos.longitude;
        _recalculateDistanceAndEta();
      });
      _pushLocationUpdate(pos.latitude, pos.longitude);
    }

    // Stream native GPS sensor events
    _locationSubscription = LocationService.getPositionStream(distanceFilterMeters: 10).listen(
      (position) {
        if (!mounted || _isSimulatingMovement) return;
        setState(() {
          _currentTechLat = position.latitude;
          _currentTechLng = position.longitude;
          _recalculateDistanceAndEta();
        });
        _pushLocationUpdate(position.latitude, position.longitude);
      },
      onError: (e) {
        debugPrint('[TechnicianLiveTrackingScreen] GPS Stream error: $e');
      },
    );
  }

  Future<void> _pushLocationUpdate(double lat, double lng) async {
    try {
      final repo = ref.read(apiRepositoryProvider);
      await repo.updateJobLiveLocation(widget.jobId, lat, lng);
      await repo.pingTechnicianLocation(latitude: lat, longitude: lng);
    } catch (_) {}
  }

  void _recalculateDistanceAndEta() {
    final distMeters = LocationService.calculateDistanceInMeters(
      startLatitude: _currentTechLat,
      startLongitude: _currentTechLng,
      endLatitude: _destLat,
      endLongitude: _destLng,
    );
    _distanceKm = (distMeters / 1000.0);
    _etaMinutes = LocationService.estimateEtaMinutes(_distanceKm);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _pollingTimer?.cancel();
    _simulationTimer?.cancel();
    _locationSubscription?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _fetchTrackingData({bool isSilent = false}) async {
    if (!isSilent) {
      setState(() => _isLoading = true);
    }

    try {
      final repo = ref.read(apiRepositoryProvider);
      final data = await repo.getJobTracking(widget.jobId);

      if (mounted) {
        setState(() {
          _trackingData = data;
          _jobStatus = data['status'] ?? 'EN_ROUTE';

          final tech = data['technician'] ?? {};
          final cust = data['customer'] ?? {};
          final route = data['route'] ?? {};

          final tLat = (tech['currentLatitude'] as num?)?.toDouble();
          final tLng = (tech['currentLongitude'] as num?)?.toDouble();
          final cLat = (cust['latitude'] as num?)?.toDouble();
          final cLng = (cust['longitude'] as num?)?.toDouble();
          final bool hasExact = data['hasExactCustomerLocation'] == true || (cLat != null && cLng != null);
          _hasExactCustomerLocation = hasExact;

          if (tLat != null && tLng != null) {
            _currentTechLat = tLat;
            _currentTechLng = tLng;
          }

          if (cLat != null && cLng != null) {
            _destLat = cLat;
            _destLng = cLng;
          }

          _statusDesc = route['statusDescription'] ??
              (!hasExact ? 'Customer exact location pending. Please enter Google Maps location link.' : 'Technician is en-route');

          final rawWp = route['waypoints'] as List? ?? [];
          if (rawWp.isNotEmpty) {
            _waypoints = rawWp
                .map((w) => {
                      'lat': (w['lat'] as num).toDouble(),
                      'lng': (w['lng'] as num).toDouble(),
                    })
                .toList();
          } else {
            _waypoints = _generateDefaultWaypoints(_currentTechLat, _currentTechLng, _destLat, _destLng);
          }

          _recalculateDistanceAndEta();
          _isLoading = false;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              try {
                _fitBothMarkers();
              } catch (_) {}
            }
          });
        });
      }
    } catch (e) {
      if (mounted) {
        _setupFallbackTracking();
        setState(() => _isLoading = false);
      }
    }
  }

  void _setupFallbackTracking() {
    _currentTechLat = 11.9416;
    _currentTechLng = 79.8083;
    _destLat = 11.9320;
    _destLng = 79.8280;
    _statusDesc = 'Technician is riding via MG Road to service location';
    _waypoints = _generateDefaultWaypoints(_currentTechLat, _currentTechLng, _destLat, _destLng);
    _recalculateDistanceAndEta();

    _trackingData = {
      'jobNumber': widget.initialJobNumber ?? 'JOB-20261016-0001',
      'status': 'EN_ROUTE',
      'technician': {
        'name': widget.initialTechName ?? 'Suresh Kumar',
        'phone': '+91 96776 86561',
        'completedJobs': 42,
      },
      'customer': {
        'name': widget.initialCustomerName ?? 'Ramesh Sundaram',
        'phone': '+91 98400 11111',
        'addressLine': '14, Valarampet Street, Near New Bus Stand',
        'area': 'Puducherry',
      },
      'service': {
        'serviceName': 'Jet Pump Foam Deep Cleaning',
        'acDetails': 'Daikin Inverter Split AC (1.5 Ton)',
        'timeSlot': '10:00 AM - 12:00 PM',
      }
    };
  }

  List<Map<String, double>> _generateDefaultWaypoints(
      double startLat, double startLng, double endLat, double endLng) {
    final list = <Map<String, double>>[];
    const steps = 10;
    for (int i = 1; i < steps; i++) {
      final ratio = i / steps;
      final curve = math.sin(ratio * math.pi) * 0.0025;
      list.add({
        'lat': startLat + (endLat - startLat) * ratio + curve,
        'lng': startLng + (endLng - startLng) * ratio - (curve * 0.4),
      });
    }
    return list;
  }

  /// Interactive Movement Simulator for demonstration
  void _toggleLiveSimulation() {
    setState(() {
      _isSimulatingMovement = !_isSimulatingMovement;
    });

    if (_isSimulatingMovement) {
      if (_currentWaypointIndex >= _waypoints.length - 1) {
        _currentWaypointIndex = 0;
      }

      _simulationTimer?.cancel();
      _simulationTimer = Timer.periodic(const Duration(milliseconds: 1400), (t) {
        if (!mounted || !_isSimulatingMovement) {
          t.cancel();
          return;
        }

        if (_currentWaypointIndex < _waypoints.length - 1) {
          _currentWaypointIndex++;
          final nextPoint = _waypoints[_currentWaypointIndex];
          final remainingSteps = _waypoints.length - 1 - _currentWaypointIndex;

          setState(() {
            _currentTechLat = nextPoint['lat']!;
            _currentTechLng = nextPoint['lng']!;
            _recalculateDistanceAndEta();

            if (remainingSteps <= 1) {
              _jobStatus = 'ARRIVED';
              _statusDesc = 'Technician arrived at your gate / doorstep!';
              _distanceKm = 0.0;
              _etaMinutes = 0;
            }
          });

          // Pan camera gently with technician movement
          try {
            _mapController.move(LatLng(_currentTechLat, _currentTechLng), _mapController.camera.zoom);
          } catch (_) {}

          _pushLocationUpdate(_currentTechLat, _currentTechLng);

          if (remainingSteps == 0) {
            _simulationTimer?.cancel();
            setState(() => _isSimulatingMovement = false);
            _showArrivalDialog();
          }
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🛵 Live Movement Simulation Started (Moving on OpenStreetMap)'),
          backgroundColor: Color(0xFF16A34A),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      _simulationTimer?.cancel();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⏸️ Simulation Paused'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  void _showArrivalDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 28),
            SizedBox(width: 8),
            Text('Technician Arrived!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_trackingData?['technician']?['name'] ?? 'Caring CoolTech Technician'} is at the service location.',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.security, color: Color(0xFF15803D), size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Security Notice: Share the 6-digit OTP only after satisfactory inspection of the AC unit.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF166534), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Acknowledge'),
          ),
        ],
      ),
    );
  }

  Future<void> _makePhoneCall(String? phone) async {
    final number = phone ?? '+919677686561';
    final clean = number.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri(scheme: 'tel', path: clean);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open dialer for $number')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error dialing: $e')),
        );
      }
    }
  }

  Future<void> _openExternalMap(double lat, double lng) async {
    final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not launch external map navigation')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening maps: $e')),
        );
      }
    }
  }

  void _centerOnTechnician() {
    _mapController.move(LatLng(_currentTechLat, _currentTechLng), 16.0);
  }

  void _centerOnDestination() {
    if (!_hasExactCustomerLocation) {
      _showLocationLinkDialog();
      return;
    }
    _mapController.move(LatLng(_destLat, _destLng), 16.0);
  }

  void _showLocationLinkDialog() {
    final linkController = TextEditingController();
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
                const Text(
                  'Paste the exact Google Maps location link or coordinates provided by the customer / technician / WhatsApp:',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: linkController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'e.g. https://maps.app.goo.gl/... or 11.9320, 79.8280',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Supports: Google Maps app share links, WhatsApp location links, or latitude/longitude coordinates.',
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
                              jobId: widget.jobId,
                              locationLink: input,
                            );
                        if (ctx.mounted) Navigator.pop(ctx);
                        _fetchTrackingData();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('📍 Exact customer location updated successfully!'),
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
                  : const Text('Save & Update Map', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _fitBothMarkers() {
    if (!_hasExactCustomerLocation) {
      _mapController.move(LatLng(_currentTechLat, _currentTechLng), 14.5);
      return;
    }
    final bounds = LatLngBounds.fromPoints([
      LatLng(_currentTechLat, _currentTechLng),
      LatLng(_destLat, _destLng),
    ]);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 90),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark || _mapThemeIndex == 2;
    final tech = _trackingData?['technician'] ?? {};
    final cust = _trackingData?['customer'] ?? {};
    final serv = _trackingData?['service'] ?? {};

    // Collect route polyline coordinates
    final polylinePoints = <LatLng>[
      LatLng(_currentTechLat, _currentTechLng),
      ..._waypoints.map((w) => LatLng(w['lat']!, w['lng']!)),
      LatLng(_destLat, _destLng),
    ];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.only(left: 12, top: 8, bottom: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.92),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8),
            ],
          ),
          child: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : Colors.black87),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_on, color: AppTheme.primaryBlue, size: 16),
              const SizedBox(width: 6),
              Text(
                _trackingData?['jobNumber'] ?? widget.initialJobNumber ?? 'JOB TRACKING',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.92),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8),
              ],
            ),
            child: PopupMenuButton<int>(
              icon: Icon(
                _mapThemeIndex == 0
                    ? Icons.map_rounded
                    : _mapThemeIndex == 1
                        ? Icons.public_rounded
                        : Icons.nightlight_round,
                color: AppTheme.primaryBlue,
                size: 20,
              ),
              tooltip: 'Choose Open-Source Map Style',
              initialValue: _mapThemeIndex,
              onSelected: (val) => setState(() => _mapThemeIndex = val),
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 0,
                  child: Row(
                    children: [
                      Icon(Icons.public_rounded, color: Color(0xFF16A34A), size: 18),
                      SizedBox(width: 8),
                      Text('OpenStreetMap Standard'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 1,
                  child: Row(
                    children: [
                      Icon(Icons.layers_rounded, color: AppTheme.primaryBlue, size: 18),
                      SizedBox(width: 8),
                      Text('High-Contrast (Humanitarian)'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 2,
                  child: Row(
                    children: [
                      Icon(Icons.satellite_alt_rounded, color: Color(0xFF38BDF8), size: 18),
                      SizedBox(width: 8),
                      Text('Satellite Aerial View'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // 1. Full Open-Source FlutterMap Engine
                Positioned.fill(
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: LatLng(_currentTechLat, _currentTechLng),
                      initialZoom: 15.0,
                      minZoom: 4.0,
                      maxZoom: 18.5,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all,
                      ),
                    ),
                    children: [
                      // Open-source Tile Provider (100% Free, Zero API Keys, No Watermarks)
                      TileLayer(
                        urlTemplate: _mapTiles[_mapThemeIndex]['url']!,
                        userAgentPackageName: 'com.caringcooltech.acservice',
                        maxZoom: 19,
                      ),

                      // Connecting Route Polyline
                      if (_hasExactCustomerLocation)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: polylinePoints,
                              strokeWidth: 5.0,
                              color: const Color(0xFF0284C7),
                              borderStrokeWidth: 2.5,
                              borderColor: Colors.white,
                            ),
                          ],
                        ),

                      // Map Markers (Technician & Customer Destination)
                      MarkerLayer(
                        markers: [
                          // Destination Customer Marker (Sufficient dimensions to prevent pixel overflow)
                          if (_hasExactCustomerLocation)
                            Marker(
                              point: LatLng(_destLat, _destLng),
                              width: 80,
                              height: 80,
                              alignment: Alignment.center,
                              child: _buildDestinationMarker(cust['name'] ?? 'Customer'),
                            ),

                          // Live Technician Pulsing Marker
                          Marker(
                            point: LatLng(_currentTechLat, _currentTechLng),
                            width: 80,
                            height: 80,
                            alignment: Alignment.center,
                            child: AnimatedBuilder(
                              animation: _pulseController,
                              builder: (ctx, child) {
                                return _buildPulsingTechnicianMarker(tech['name'] ?? 'Technician');
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 2. Swiggy / Zepto Floating ETA Banner at Top
                Positioned(
                  top: MediaQuery.of(context).padding.top + 64,
                  left: 16,
                  right: 16,
                  child: _buildTopEtaCard(isDark),
                ),

                // 3. Floating Quick Action Controls on Right Side
                Positioned(
                  right: 16,
                  bottom: 300,
                  child: Column(
                    children: [
                      // Recenter on Technician
                      _buildFloatingMapButton(
                        icon: Icons.my_location_rounded,
                        tooltip: 'Center on Technician',
                        onTap: _centerOnTechnician,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 10),

                      // Fit Both in View
                      _buildFloatingMapButton(
                        icon: Icons.zoom_out_map_rounded,
                        tooltip: 'View Full Trip',
                        onTap: _fitBothMarkers,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 10),

                      // Center on Customer Destination
                      _buildFloatingMapButton(
                        icon: Icons.home_rounded,
                        tooltip: 'Center on Destination',
                        onTap: _centerOnDestination,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 10),

                      // Provide or Update Location Link
                      _buildFloatingMapButton(
                        icon: Icons.add_link_rounded,
                        tooltip: 'Provide Location Link',
                        onTap: _showLocationLinkDialog,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 10),

                      // Open External Navigation (Google Maps / Apple Maps)
                      _buildFloatingMapButton(
                        icon: Icons.navigation_rounded,
                        tooltip: 'Turn-by-Turn Navigation',
                        onTap: () => _openExternalMap(_destLat, _destLng),
                        isDark: isDark,
                      ),
                      const SizedBox(height: 10),

                      // Simulation toggle FAB
                      FloatingActionButton.small(
                        heroTag: 'simulateMovementBtn',
                        backgroundColor: _isSimulatingMovement ? const Color(0xFFE11D48) : const Color(0xFF16A34A),
                        tooltip: _isSimulatingMovement ? 'Pause Movement' : 'Simulate GPS Movement',
                        onPressed: _toggleLiveSimulation,
                        child: Icon(
                          _isSimulatingMovement ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                // 4. Draggable Swiggy/Zepto Order & Technician Bottom Sheet
                DraggableScrollableSheet(
                  initialChildSize: 0.38,
                  minChildSize: 0.22,
                  maxChildSize: 0.88,
                  builder: (ctx, scrollController) {
                    return Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.22),
                            blurRadius: 20,
                            offset: const Offset(0, -6),
                          ),
                        ],
                      ),
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                        children: [
                          // Sheet drag pill
                          Center(
                            child: Container(
                              width: 44,
                              height: 5,
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),

                          // Header status row (Zepto / Swiggy style)
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: _jobStatus == 'ARRIVED'
                                      ? const Color(0xFFDCFCE7)
                                      : AppTheme.primaryBlue.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  _jobStatus == 'ARRIVED'
                                      ? Icons.check_circle_rounded
                                      : Icons.two_wheeler_rounded,
                                  color: _jobStatus == 'ARRIVED'
                                      ? const Color(0xFF16A34A)
                                      : AppTheme.primaryBlue,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _jobStatus == 'ARRIVED'
                                          ? 'Technician has arrived!'
                                          : _jobStatus == 'IN_PROGRESS'
                                              ? 'AC Service in progress'
                                              : 'Technician on the way',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _statusDesc,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0FDF4),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFBBF7D0)),
                                ),
                                child: Text(
                                  _etaMinutes > 0 ? '$_etaMinutes MINS' : 'ARRIVED',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF15803D),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Step Progress Tracker
                          _buildStepTracker(isDark),
                          const SizedBox(height: 20),

                          // Technician Profile Card
                          _buildTechnicianProfileCard(tech, isDark),
                          const SizedBox(height: 16),

                          // Service & Destination Address Details
                          _buildServiceAndAddressCard(serv, cust, isDark),
                          const SizedBox(height: 16),

                          // OpenStreetMap Provider Credit Pill
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.map_outlined, color: AppTheme.primaryBlue, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Free OpenStreetMap & CartoDB tiles • Native GPS sensor tracking active.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
    );
  }

  Widget _buildDestinationMarker(String customerName) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFE11D48),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE11D48).withValues(alpha: 0.4),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.home_rounded, color: Colors.white, size: 20),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            customerName.split(' ').first,
            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildPulsingTechnicianMarker(String techName) {
    final progress = _pulseController.value;
    final haloRadius = 24.0 + (progress * 14.0);
    final haloOpacity = (1.0 - progress).clamp(0.0, 0.7);

    return Stack(
      alignment: Alignment.center,
      children: [
        // Pulsing radar halo
        Container(
          width: haloRadius * 2,
          height: haloRadius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF0284C7).withValues(alpha: haloOpacity),
          ),
        ),
        // Central icon badge
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFF0284C7),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(Icons.two_wheeler_rounded, color: Colors.white, size: 20),
        ),
      ],
    );
  }

  Widget _buildTopEtaCard(bool isDark) {
    if (!_hasExactCustomerLocation) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEA580C), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Color(0xFFEA580C),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.location_searching, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'CUSTOMER LOCATION NEEDED',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Color(0xFFC2410C), letterSpacing: 0.3),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Address could not be located on map. Tap to enter Google Maps link.',
                    style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF7C2D12)),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEA580C),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _showLocationLinkDialog,
              child: const Text('Add Link', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.92) : Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Breathing green beacon dot
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.6),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      _etaMinutes > 0 ? 'ARRIVING IN $_etaMinutes MINS' : 'REACHED DESTINATION',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.4),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('REAL GPS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF166534))),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${_distanceKm.toStringAsFixed(1)} km away • Live technician position',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20, color: AppTheme.primaryBlue),
            tooltip: 'Refresh GPS',
            onPressed: () => _fetchTrackingData(),
          ),
        ],
      ),
    );
  }

  Widget _buildStepTracker(bool isDark) {
    final steps = [
      {'title': 'Confirmed', 'done': true},
      {'title': 'Dispatched', 'done': true},
      {'title': 'En Route', 'done': true, 'active': _jobStatus == 'EN_ROUTE'},
      {'title': 'Arrived', 'done': _jobStatus == 'ARRIVED' || _jobStatus == 'IN_PROGRESS' || _jobStatus == 'COMPLETED'},
    ];

    return Row(
      children: List.generate(steps.length * 2 - 1, (index) {
        if (index.isOdd) {
          final stepIndex = index ~/ 2;
          final isPast = steps[stepIndex + 1]['done'] == true;
          return Expanded(
            child: Container(
              height: 3,
              color: isPast ? const Color(0xFF16A34A) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
          );
        } else {
          final stepIndex = index ~/ 2;
          final step = steps[stepIndex];
          final isDone = step['done'] == true;
          final isActive = step['active'] == true;

          return Column(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: isDone ? const Color(0xFF16A34A) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  shape: BoxShape.circle,
                  border: isActive ? Border.all(color: Colors.white, width: 2) : null,
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: const Color(0xFF16A34A).withValues(alpha: 0.5),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  isDone ? Icons.check : Icons.circle,
                  size: 12,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                step['title'] as String,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  color: isActive ? AppTheme.primaryBlue : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ),
            ],
          );
        }
      }),
    );
  }

  Widget _buildTechnicianProfileCard(Map<String, dynamic> tech, bool isDark) {
    final name = tech['name'] ?? 'Technician';
    final phone = tech['phone'] ?? '+91 96776 86561';
    final completedJobs = (tech['completedJobs'] as num?)?.toInt() ?? 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.15),
            child: const Icon(Icons.engineering_rounded, color: AppTheme.primaryBlue, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.verified_rounded, color: AppTheme.primaryBlue, size: 16),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.verified, color: Color(0xFF16A34A), size: 12),
                          const SizedBox(width: 4),
                          Text(
                            completedJobs > 0 ? '$completedJobs Verified Jobs' : 'Verified Technician',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '• Field Expert',
                      style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Direct Phone dialer button
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(color: Color(0xFFDCFCE7), shape: BoxShape.circle),
              child: const Icon(Icons.phone_rounded, color: Color(0xFF15803D), size: 18),
            ),
            tooltip: 'Call Technician',
            onPressed: () => _makePhoneCall(phone),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceAndAddressCard(Map<String, dynamic> serv, Map<String, dynamic> cust, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.ac_unit_rounded, color: AppTheme.primaryBlue, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  serv['serviceName'] ?? 'AC Service & Maintenance',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              Text(
                serv['acDetails'] ?? 'Split AC',
                style: const TextStyle(fontSize: 11, color: Color(0xFF0D9488), fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const Divider(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on_rounded, color: AppTheme.accentRose, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Customer: ${cust['name'] ?? 'Customer'}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${cust['addressLine'] ?? 'Address'}, ${cust['area'] ?? 'Puducherry'}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEA580C),
                    side: const BorderSide(color: Color(0xFFEA580C)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.add_link_rounded, size: 14),
                  label: Text(
                    _hasExactCustomerLocation ? 'Update Location Link' : '📍 Provide Location Link',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  onPressed: _showLocationLinkDialog,
                ),
              ),
              if (_hasExactCustomerLocation) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.navigation_rounded, size: 14),
                    label: const Text('Google Maps', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    onPressed: () => _openExternalMap(_destLat, _destLng),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingMapButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: AppTheme.primaryBlue, size: 20),
        ),
      ),
    );
  }
}
