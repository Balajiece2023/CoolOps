import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../providers/app_providers.dart';
import 'technician_live_tracking_screen.dart';
import '../../core/services/location_service.dart';

class BookingRequestsView extends ConsumerStatefulWidget {
  const BookingRequestsView({super.key});

  @override
  ConsumerState<BookingRequestsView> createState() => _BookingRequestsViewState();
}

class _BookingRequestsViewState extends ConsumerState<BookingRequestsView> {
  String _selectedStatus = 'PENDING_APPROVAL';

  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(bookingRequestsProvider(_selectedStatus));
    final user = ref.watch(authStateProvider);
    final isAdmin = user?.role == UserRole.admin;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryBlue,
        icon: const Icon(Icons.add_task, color: Colors.white),
        label: const Text('Log New Incident Ticket', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () => _showCreateTicketDialog(context),
      ),
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _FilterChip(
                  label: 'Pending / Unassigned',
                  isSelected: _selectedStatus == 'PENDING_APPROVAL',
                  onSelected: () => setState(() => _selectedStatus = 'PENDING_APPROVAL'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Assigned / Approved',
                  isSelected: _selectedStatus == 'APPROVED',
                  onSelected: () => setState(() => _selectedStatus = 'APPROVED'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Alternative Proposed',
                  isSelected: _selectedStatus == 'ALTERNATIVE_PROPOSED',
                  onSelected: () => setState(() => _selectedStatus = 'ALTERNATIVE_PROPOSED'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'On Hold ⏸️',
                  isSelected: _selectedStatus == 'ON_HOLD',
                  onSelected: () => setState(() => _selectedStatus = 'ON_HOLD'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'All Tickets',
                  isSelected: _selectedStatus == '',
                  onSelected: () => setState(() => _selectedStatus = ''),
                ),
              ],
            ),
          ),

          // Requests List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.refresh(bookingRequestsProvider(_selectedStatus)),
              child: requestsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Error: $err')),
                data: (requests) {
                  if (requests.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox_outlined, size: 48, color: Color(0xFF94A3B8)),
                          SizedBox(height: 12),
                          Text('No incident tickets found in this filter', style: TextStyle(color: Color(0xFF64748B))),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                    itemCount: requests.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final req = requests[index];
                      return _RequestCard(
                        request: req,
                        isAdmin: isAdmin,
                        onOverviewPressed: () => _showBookingOverview(context, req),
                        onApprovePressed: () => _showApproveDialog(context, req),
                        onRejectPressed: () => _showRejectDialog(context, req),
                        onProposePressed: () => _showProposeDialog(context, req),
                        onHoldPressed: () => _showHoldDialog(context, req),
                        onEditPressed: () => _showEditBookingDialog(context, req),
                        onDeletePressed: () => _showDeleteBookingDialog(context, req),
                        onReassignPressed: () => _showReassignDialog(context, req),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateTicketDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addrCtrl = TextEditingController();
    final areaCtrl = TextEditingController();
    final pinCtrl = TextEditingController(text: '605001');
    final complaintCtrl = TextEditingController();
    final brandCtrl = TextEditingController(text: 'Daikin');
    final dateCtrl = TextEditingController(text: DateTime.now().add(const Duration(days: 1)).toString().split(' ')[0]);
    final customServiceCtrl = TextEditingController();
    final locationLinkCtrl = TextEditingController();
    double? detectedLat;
    double? detectedLng;
    bool isDetectingGps = false;
    String priority = 'MEDIUM';
    String timeSlot = '09:00-11:00';
    String selectedServiceCode = 'CHECKUP';
    String acType = 'SPLIT';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.confirmation_number_outlined, color: AppTheme.primaryBlue),
              SizedBox(width: 8),
              Text('Log Service Incident Ticket', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(ctx).size.width * 0.9,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Customer Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryBlue)),
                  const SizedBox(height: 6),
                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Customer Full Name *')),
                  const SizedBox(height: 8),
                  TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone Number (10 Digits) *')),
                  const SizedBox(height: 8),
                  TextField(controller: addrCtrl, decoration: const InputDecoration(labelText: 'Street Address *')),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: areaCtrl,
                          decoration: const InputDecoration(labelText: 'Area / Neighborhood *'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: pinCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Pincode *'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: detectedLat != null ? const Color(0xFF16A34A) : AppTheme.primaryBlue,
                        side: BorderSide(color: detectedLat != null ? const Color(0xFF16A34A) : AppTheme.primaryBlue),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: isDetectingGps
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : Icon(detectedLat != null ? Icons.check_circle : Icons.my_location, size: 16),
                      label: Text(
                        detectedLat != null
                            ? '📍 Exact GPS Attached (${detectedLat!.toStringAsFixed(4)}, ${detectedLng!.toStringAsFixed(4)})'
                            : '📍 Auto-Capture Customer GPS Location',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      onPressed: isDetectingGps
                          ? null
                          : () async {
                              setDialogState(() => isDetectingGps = true);
                              try {
                                final pos = await LocationService.getCurrentPosition();
                                if (pos != null) {
                                  setDialogState(() {
                                    detectedLat = pos.latitude;
                                    detectedLng = pos.longitude;
                                    isDetectingGps = false;
                                  });
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(
                                        content: Text('📍 Exact GPS captured (${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)})'),
                                        backgroundColor: const Color(0xFF16A34A),
                                      ),
                                    );
                                  }
                                } else {
                                  setDialogState(() => isDetectingGps = false);
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      const SnackBar(content: Text('Could not obtain GPS fix. Address will be geocoded automatically.')),
                                    );
                                  }
                                }
                              } catch (_) {
                                setDialogState(() => isDetectingGps = false);
                              }
                            },
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: locationLinkCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Google Maps Link / WhatsApp Location (Optional)',
                      hintText: 'e.g. https://maps.app.goo.gl/... or coordinates',
                      prefixIcon: Icon(Icons.link, size: 18),
                      isDense: true,
                    ),
                  ),
                  const Divider(height: 24),
                  const Text('Ticket Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryBlue)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedServiceCode,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Service Type / Package *'),
                    items: const [
                      DropdownMenuItem(value: 'CHECKUP', child: Text('Comprehensive AC Inspection (₹499)', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'WASH', child: Text('Jet Pump Foam Wash & Cleaning (₹699)', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'GAS_CHARGE', child: Text('Gas Leak Detection & Top-up (₹1499)', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'PCB_REPAIR', child: Text('Inverter PCB Board Diagnostics & Repair (₹1200)', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'INSTALLATION', child: Text('Split AC New Installation (₹1500)', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'UNINSTALLATION', child: Text('Split AC Uninstallation & Safe Packing (₹799)', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(
                        value: 'CUSTOM',
                        child: Text('➕ Enter Custom Service Package...', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                      ),
                    ],
                    onChanged: (val) => setDialogState(() => selectedServiceCode = val ?? 'CHECKUP'),
                  ),
                  if (selectedServiceCode == 'CUSTOM') ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: customServiceCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Custom Package Name *',
                        hintText: 'e.g. Copper Piping Replacement & Nitrogen Testing',
                        prefixIcon: Icon(Icons.handyman_outlined, color: AppTheme.primaryBlue, size: 20),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: priority,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Ticket Priority *'),
                    items: const [
                      DropdownMenuItem(value: 'LOW', child: Text('Low Priority', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'MEDIUM', child: Text('Medium Priority', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'HIGH', child: Text('High Priority', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'EMERGENCY', child: Text('Emergency', overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (val) => setDialogState(() => priority = val ?? 'MEDIUM'),
                  ),
                  const SizedBox(height: 8),
                  TextField(controller: complaintCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Service Description / Customer Issue *')),
                  const SizedBox(height: 8),
                  TextField(controller: brandCtrl, decoration: const InputDecoration(labelText: 'AC Brand (e.g. Daikin)')),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: acType,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'AC Type'),
                    items: const [
                      DropdownMenuItem(value: 'SPLIT', child: Text('Split AC')),
                      DropdownMenuItem(value: 'WINDOW', child: Text('Window AC')),
                      DropdownMenuItem(value: 'CASSETTE', child: Text('Cassette AC')),
                    ],
                    onChanged: (val) => setDialogState(() => acType = val ?? 'SPLIT'),
                  ),
                  const SizedBox(height: 8),
                  TextField(controller: dateCtrl, decoration: const InputDecoration(labelText: 'Scheduled Date (YYYY-MM-DD)')),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: timeSlot,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Time Slot'),
                    items: const [
                      DropdownMenuItem(value: '09:00-11:00', child: Text('09:00 - 11:00 AM', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: '11:00-13:00', child: Text('11:00 - 01:00 PM', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: '14:00-16:00', child: Text('02:00 - 04:00 PM', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: '16:00-18:00', child: Text('04:00 - 06:00 PM', overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (val) => setDialogState(() => timeSlot = val ?? '09:00-11:00'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.isEmpty || phoneCtrl.text.isEmpty || addrCtrl.text.isEmpty || complaintCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Please fill all mandatory fields (*)')));
                  return;
                }
                if (selectedServiceCode == 'CUSTOM' && customServiceCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Please enter custom package name')));
                  return;
                }

                try {
                  final serviceToUse = selectedServiceCode == 'CUSTOM' ? customServiceCtrl.text.trim() : selectedServiceCode;
                  await ref.read(apiRepositoryProvider).createTicket(
                        customerName: nameCtrl.text.trim(),
                        customerPhone: phoneCtrl.text.trim(),
                        addressLine: addrCtrl.text.trim(),
                        area: areaCtrl.text.trim().isNotEmpty ? areaCtrl.text.trim() : 'Chennai Central',
                        pincode: pinCtrl.text.trim(),
                        serviceTypeId: serviceToUse,
                        complaint: complaintCtrl.text.trim(),
                        priority: priority,
                        acBrand: brandCtrl.text.trim(),
                        acType: acType,
                        latitude: detectedLat,
                        longitude: detectedLng,
                        locationLink: locationLinkCtrl.text.trim().isNotEmpty ? locationLinkCtrl.text.trim() : null,
                        preferredDate: dateCtrl.text.trim(),
                        preferredTimeSlot: timeSlot,
                      );
                  if (ctx.mounted) Navigator.pop(ctx);
                  ref.refresh(bookingRequestsProvider(_selectedStatus));
                  ref.refresh(dashboardStatsProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Incident ticket logged successfully by staff!')),
                    );
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    final cleanMsg = ApiClient.formatErrorMessage(e);
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(cleanMsg), backgroundColor: Colors.red));
                  }
                }
              },
              child: const Text('Create Ticket'),
            ),
          ],
        ),
      ),
    );
  }

  void _showApproveDialog(BuildContext context, BookingRequestModel req) async {
    final techsAsync = await ref.read(apiRepositoryProvider).getTechnicians(date: req.preferredDate);
    if (!context.mounted) return;

    String? selectedTechId = techsAsync.isNotEmpty ? techsAsync.first['id'] : null;
    final dateController = TextEditingController(text: req.preferredDate);
    final slotController = TextEditingController(text: req.preferredTimeSlot);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Approve & Assign: ${req.referenceNumber}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Customer: ${req.customerName} (${req.customerPhone})'),
                Text('Address: ${req.address}'),
                Text('Service: ${req.serviceName}'),
                const SizedBox(height: 16),
                const Text('Select Field Technician:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: selectedTechId,
                  isExpanded: true,
                  decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                  items: techsAsync.map((t) {
                    final userName = t['user']?['name'] ?? 'Tech';
                    final areas = (t['serviceAreas'] as List?)?.join(', ') ?? '';
                    return DropdownMenuItem<String>(
                      value: t['id'],
                      child: Text('$userName (Areas: $areas)', style: const TextStyle(fontSize: 12)),
                    );
                  }).toList(),
                  onChanged: (val) => setDialogState(() => selectedTechId = val),
                ),
                const SizedBox(height: 12),
                const Text('Scheduled Date (YYYY-MM-DD):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                TextField(controller: dateController),
                const SizedBox(height: 12),
                const Text('Time Slot:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                TextField(controller: slotController),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: selectedTechId == null
                  ? null
                  : () async {
                      try {
                        await ref.read(apiRepositoryProvider).approveBookingRequest(
                              requestId: req.id,
                              technicianId: selectedTechId!,
                              scheduledDate: dateController.text.trim(),
                              timeSlot: slotController.text.trim(),
                            );
                        if (ctx.mounted) Navigator.pop(ctx);
                        ref.refresh(bookingRequestsProvider(_selectedStatus));
                        ref.refresh(dashboardStatsProvider);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Booking request approved and technician assigned!')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(ApiClient.formatErrorMessage(e)),
                              backgroundColor: Colors.red.shade700,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    },
              child: const Text('Confirm & Dispatch'),
            ),
          ],
        ),
      ),
    );
  }

  void _showReassignDialog(BuildContext context, BookingRequestModel req) async {
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
                child: Text('Reassign: ${req.referenceNumber}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                      Text('Customer: ${req.customerName} (${req.customerPhone})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFC2410C))),
                      const SizedBox(height: 2),
                      Text('Address: ${req.address}, ${req.area} (${req.pincode ?? ""})', style: const TextStyle(fontSize: 11, color: Color(0xFF9A3412))),
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
                    hintText: 'e.g. Current technician unavailable / Emergency schedule adjustment',
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
                        final res = await ref.read(apiRepositoryProvider).reassignBookingRequest(
                              requestId: req.id,
                              newTechnicianId: selectedTechId!,
                              reason: reasonController.text.trim(),
                            );
                        if (ctx.mounted) Navigator.pop(ctx);
                        ref.refresh(bookingRequestsProvider(_selectedStatus));
                        ref.refresh(dashboardStatsProvider);
                        if (context.mounted) {
                          final techName = res['newTechnicianName'] ?? 'Technician';
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('✅ Ticket ${req.referenceNumber} successfully reassigned to $techName!'),
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
                              backgroundColor: Colors.red.shade700,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Confirm Reassign'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRejectDialog(BuildContext context, BookingRequestModel req) {
    final reasonController = TextEditingController(text: 'Area out of current coverage zone');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Booking Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Request: ${req.referenceNumber} (${req.customerName})'),
            const SizedBox(height: 12),
            const Text('Rejection Reason (will be sent to WhatsApp):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            TextField(controller: reasonController, maxLines: 2),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Back')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentRose),
            onPressed: () async {
              await ref.read(apiRepositoryProvider).rejectBookingRequest(
                    requestId: req.id,
                    reason: reasonController.text.trim(),
                  );
              if (ctx.mounted) Navigator.pop(ctx);
              ref.refresh(bookingRequestsProvider(_selectedStatus));
            },
            child: const Text('Reject Request'),
          ),
        ],
      ),
    );
  }

  void _showHoldDialog(BuildContext context, BookingRequestModel req) {
    final reasonController = TextEditingController(text: 'Customer requested reschedule / Waiting for confirmation');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.pause_circle_filled, color: Color(0xFFD97706)),
            SizedBox(width: 8),
            Text('Put Booking On Hold'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ticket: ${req.referenceNumber} • ${req.customerName}'),
            const SizedBox(height: 12),
            const Text('Reason for Hold *:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'e.g. Spare parts in transit, customer out of station...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706)),
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) return;
              try {
                await ref.read(apiRepositoryProvider).putBookingOnHold(
                      requestId: req.id,
                      reason: reason,
                    );
                if (ctx.mounted) Navigator.pop(ctx);
                ref.refresh(bookingRequestsProvider(_selectedStatus));
                ref.refresh(dashboardStatsProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Booking successfully placed ON HOLD.')),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
                }
              }
            },
            child: const Text('Confirm Put On Hold', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showBookingOverview(BuildContext context, BookingRequestModel req) {
    final isAdmin = ref.read(authStateProvider)?.role == UserRole.admin;

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
                      Text(req.referenceNumber, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _PriorityBadge(priority: req.priority),
                          const SizedBox(width: 8),
                          _StatusBadge(status: req.status),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(sheetCtx),
                  ),
                ],
              ),
              const Divider(height: 24),
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
                    'Call Customer (${req.customerPhone})',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  onPressed: () async {
                    final uri = Uri.parse('tel:${req.customerPhone}');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    }
                  },
                ),
              ),
              const SizedBox(height: 16),
              if (req.holdReason != null && req.holdReason!.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.pause_circle_filled, color: Color(0xFFD97706), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('BOOKING CURRENTLY ON HOLD', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFFB45309))),
                            const SizedBox(height: 2),
                            Text(req.holdReason!, style: const TextStyle(fontSize: 13, color: Color(0xFF92400E))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const Text('Customer & Location', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryBlue)),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(Icons.person, color: Color(0xFF64748B)),
                title: Text(req.customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                subtitle: Text('Contact: ${req.customerPhone}'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(Icons.location_on, color: Color(0xFF64748B)),
                title: Text('${req.address}, ${req.area}'),
                subtitle: Text('City/Pincode: ${req.pincode ?? 'Puducherry'}'),
              ),
              const Divider(height: 24),
              const Text('Service & Appliance Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryBlue)),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(Icons.build_circle, color: Color(0xFF64748B)),
                title: Text(req.serviceName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text('Reported Issue: "${req.complaint}"'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(Icons.ac_unit, color: Color(0xFF64748B)),
                title: Text('${req.acBrand ?? 'AC'} • ${req.acType ?? 'Split'} (${req.acTonnage ?? 1.5}T)'),
                subtitle: Text('Scheduled: ${req.preferredDate} (${req.preferredTimeSlot})'),
              ),
              const Divider(height: 24),
              if (req.latitude == null && req.longitude == null) ...[
                Container(
                  margin: const EdgeInsets.only(top: 8, bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFDBA74)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_off_outlined, color: Color(0xFFEA580C), size: 18),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Address not auto-located on map. Add Google Maps link from technician for tracking.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF9A3412), fontWeight: FontWeight.w600),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(sheetCtx);
                          _showUpdateTicketLocationDialog(context, req);
                        },
                        child: const Text('Add Link', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFFEA580C))),
                      ),
                    ],
                  ),
                ),
              ],
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (req.status != 'REJECTED' && req.status != 'ON_HOLD')
                    OutlinedButton.icon(
                      icon: const Icon(Icons.pause_circle_outline, color: Color(0xFFD97706)),
                      label: const Text('Put On Hold', style: TextStyle(color: Color(0xFFD97706))),
                      onPressed: () {
                        Navigator.pop(sheetCtx);
                        _showHoldDialog(context, req);
                      },
                    ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit Details'),
                    onPressed: () {
                      Navigator.pop(sheetCtx);
                      _showEditBookingDialog(context, req);
                    },
                  ),
                  if (isAdmin && (req.status == 'PENDING_APPROVAL' || req.status == 'ON_HOLD'))
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
                      icon: const Icon(Icons.person_add, color: Colors.white, size: 16),
                      label: const Text('Assign Field Tech', style: TextStyle(color: Colors.white)),
                      onPressed: () {
                        Navigator.pop(sheetCtx);
                        _showApproveDialog(context, req);
                      },
                    ),
                  if (req.status == 'APPROVED') ...[
                    if (isAdmin)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEA580C)),
                        icon: const Icon(Icons.swap_horiz_rounded, color: Colors.white, size: 16),
                        label: const Text('Reassign Tech', style: TextStyle(color: Colors.white)),
                        onPressed: () {
                          Navigator.pop(sheetCtx);
                          _showReassignDialog(context, req);
                        },
                      ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
                      icon: const Icon(Icons.map_outlined, color: Colors.white, size: 16),
                      label: const Text('Track Tech', style: TextStyle(color: Colors.white)),
                      onPressed: () {
                        Navigator.pop(sheetCtx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TechnicianLiveTrackingScreen(
                              jobId: req.id,
                              initialJobNumber: req.referenceNumber,
                              initialCustomerName: req.customerName,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProposeDialog(BuildContext context, BookingRequestModel req) {
    final proposedDate = TextEditingController(text: '2026-10-18');
    final proposedSlot = TextEditingController(text: '14:00-16:00');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Propose Alternative Slot'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: proposedDate, decoration: const InputDecoration(labelText: 'Proposed Date (YYYY-MM-DD)')),
            const SizedBox(height: 8),
            TextField(controller: proposedSlot, decoration: const InputDecoration(labelText: 'Proposed Time Slot')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await ref.read(apiRepositoryProvider).proposeAlternativeSlot(
                    requestId: req.id,
                    proposedDate: proposedDate.text.trim(),
                    proposedTimeSlot: proposedSlot.text.trim(),
                  );
              if (ctx.mounted) Navigator.pop(ctx);
              ref.refresh(bookingRequestsProvider(_selectedStatus));
            },
            child: const Text('Send Proposal to Customer'),
          ),
        ],
      ),
    );
  }

  void _showEditBookingDialog(BuildContext context, BookingRequestModel req) {
    final nameCtrl = TextEditingController(text: req.customerName);
    final phoneCtrl = TextEditingController(text: req.customerPhone);
    final complaintCtrl = TextEditingController(text: req.complaint);
    final dateCtrl = TextEditingController(text: req.preferredDate);
    final brandCtrl = TextEditingController(text: req.acBrand ?? '');
    String timeSlot = req.preferredTimeSlot;
    String priority = req.priority;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.edit_outlined, color: AppTheme.primaryBlue),
              const SizedBox(width: 8),
              Expanded(child: Text('Edit Booking (${req.referenceNumber})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
            ],
          ),
          content: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(ctx).size.width * 0.9,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Customer Name')),
                  const SizedBox(height: 8),
                  TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Customer Phone')),
                  const SizedBox(height: 8),
                  TextField(controller: complaintCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Complaint / Requirement')),
                  const SizedBox(height: 8),
                  TextField(controller: dateCtrl, decoration: const InputDecoration(labelText: 'Date (YYYY-MM-DD)')),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: ['09:00-11:00', '11:00-13:00', '14:00-16:00', '16:00-18:00'].contains(timeSlot) ? timeSlot : '09:00-11:00',
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Time Slot'),
                    items: const [
                      DropdownMenuItem(value: '09:00-11:00', child: Text('09:00 - 11:00 AM', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: '11:00-13:00', child: Text('11:00 - 01:00 PM', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: '14:00-16:00', child: Text('02:00 - 04:00 PM', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: '16:00-18:00', child: Text('04:00 - 06:00 PM', overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (val) => setDialogState(() => timeSlot = val ?? timeSlot),
                  ),
                  const SizedBox(height: 8),
                  TextField(controller: brandCtrl, decoration: const InputDecoration(labelText: 'AC Brand (Optional)')),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                try {
                  await ref.read(apiRepositoryProvider).updateBookingRequest(
                        requestId: req.id,
                        customerName: nameCtrl.text.trim(),
                        customerPhone: phoneCtrl.text.trim(),
                        complaint: complaintCtrl.text.trim(),
                        preferredDate: dateCtrl.text.trim(),
                        preferredTimeSlot: timeSlot,
                        acBrand: brandCtrl.text.trim().isNotEmpty ? brandCtrl.text.trim() : null,
                      );
                  if (ctx.mounted) Navigator.pop(ctx);
                  ref.refresh(bookingRequestsProvider(_selectedStatus));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Booking details updated successfully!')),
                    );
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error updating: $e'), backgroundColor: Colors.red));
                  }
                }
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteBookingDialog(BuildContext context, BookingRequestModel req) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: AppTheme.accentRose),
            SizedBox(width: 8),
            Text('Delete Booking', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete booking ${req.referenceNumber} (${req.customerName})?\n\nThis will remove the booking and cancel any pending assignments.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentRose),
            onPressed: () async {
              try {
                await ref.read(apiRepositoryProvider).deleteBookingRequest(req.id);
                if (ctx.mounted) Navigator.pop(ctx);
                ref.refresh(bookingRequestsProvider(_selectedStatus));
                ref.refresh(dashboardStatsProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Booking deleted successfully.')),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Delete failed: $e'), backgroundColor: Colors.red));
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
  void _showUpdateTicketLocationDialog(BuildContext context, BookingRequestModel req) {
    final linkController = TextEditingController(text: req.locationLink ?? '');
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
                Text(
                  'Ticket: ${req.referenceNumber} (${req.customerName})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFC2410C)),
                ),
                const SizedBox(height: 4),
                Text(
                  'Address: ${req.address}, ${req.area}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Paste Google Maps location link or coordinates from technician / WhatsApp:',
                  style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
                ),
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
                        await ref.read(apiRepositoryProvider).updateBookingRequestCustomerLocation(
                              requestId: req.id,
                              locationLink: input,
                            );
                        if (ctx.mounted) Navigator.pop(ctx);
                        ref.refresh(bookingRequestsProvider(_selectedStatus));
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

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onSelected;

  const _FilterChip({required this.label, required this.isSelected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label, style: TextStyle(color: isSelected ? Colors.white : const Color(0xFF0F172A), fontSize: 12)),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      selectedColor: AppTheme.primaryBlue,
      checkmarkColor: Colors.white,
    );
  }
}

class _RequestCard extends StatelessWidget {
  final BookingRequestModel request;
  final bool isAdmin;
  final VoidCallback onOverviewPressed;
  final VoidCallback onApprovePressed;
  final VoidCallback onRejectPressed;
  final VoidCallback onProposePressed;
  final VoidCallback onHoldPressed;
  final VoidCallback onEditPressed;
  final VoidCallback onDeletePressed;
  final VoidCallback onReassignPressed;

  const _RequestCard({
    required this.request,
    required this.isAdmin,
    required this.onOverviewPressed,
    required this.onApprovePressed,
    required this.onRejectPressed,
    required this.onProposePressed,
    required this.onHoldPressed,
    required this.onEditPressed,
    required this.onDeletePressed,
    required this.onReassignPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isPending = request.status == 'PENDING_APPROVAL';
    final isOnHold = request.status == 'ON_HOLD';

    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOverviewPressed,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onOverviewPressed,
          child: Padding(
            padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          request.referenceNumber,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue, fontSize: 13),
                        ),
                        _PriorityBadge(priority: request.priority),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _StatusBadge(status: request.status),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.phone, size: 18, color: Color(0xFF16A34A)),
                        tooltip: 'Call Customer',
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(4),
                        onPressed: () => launchUrl(Uri.parse('tel:${request.customerPhone}')),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.primaryBlue),
                        tooltip: 'Edit Booking',
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(4),
                        onPressed: onEditPressed,
                      ),
                      if (isAdmin)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.accentRose),
                          tooltip: 'Delete Booking',
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(4),
                          onPressed: onDeletePressed,
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(request.customerName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  InkWell(
                    onTap: () => launchUrl(Uri.parse('tel:${request.customerPhone}')),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.call, size: 14, color: Color(0xFF16A34A)),
                        const SizedBox(width: 4),
                        Text(
                          request.customerPhone,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Text(request.area, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Service: ${request.serviceName}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    Text('Issue: "${request.complaint}"', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                    Text('AC: ${request.acBrand ?? 'AC'} ${request.acType ?? 'Split'} (${request.acTonnage ?? 1.5}T)', style: const TextStyle(fontSize: 12)),
                    if (request.isStaffCreated)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text('Logged by: Staff Support', style: TextStyle(fontSize: 11, color: AppTheme.primaryBlue, fontWeight: FontWeight.w600)),
                      ),
                  ],
                ),
              ),
              if (request.holdReason != null && request.holdReason!.isNotEmpty)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.pause_circle_filled, size: 15, color: Color(0xFFD97706)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text('On Hold: ${request.holdReason}', style: const TextStyle(fontSize: 11, color: Color(0xFF92400E), fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Scheduled Window: ${request.preferredDate} (${request.preferredTimeSlot})',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              if (isPending || isOnHold) ...[
                const Divider(height: 20),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (!isOnHold)
                      OutlinedButton.icon(
                        onPressed: onHoldPressed,
                        icon: const Icon(Icons.pause_circle_outline, size: 14, color: Color(0xFFD97706)),
                        label: const Text('Hold', style: TextStyle(fontSize: 12, color: Color(0xFFD97706))),
                        style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                      ),
                    if (isAdmin) ...[
                      OutlinedButton(
                        onPressed: onProposePressed,
                        style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                        child: const Text('Alt Slot', style: TextStyle(fontSize: 12)),
                      ),
                      OutlinedButton(
                        onPressed: onRejectPressed,
                        style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact, foregroundColor: AppTheme.accentRose),
                        child: const Text('Reject', style: TextStyle(fontSize: 12)),
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.person_add, size: 14),
                        onPressed: onApprovePressed,
                        style: ElevatedButton.styleFrom(visualDensity: VisualDensity.compact, backgroundColor: AppTheme.primaryBlue),
                        label: Text(isOnHold ? 'Resume & Assign' : 'Assign Technician', style: const TextStyle(fontSize: 12)),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_clock, size: 14, color: Color(0xFF64748B)),
                            SizedBox(width: 4),
                            Text('Awaiting Admin Assignment', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
              if (request.status == 'APPROVED') ...[
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (isAdmin) ...[
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFEA580C),
                          side: const BorderSide(color: Color(0xFFFDBA74)),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.swap_horiz_rounded, size: 14),
                        label: const Text('Reassign Tech', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        onPressed: onReassignPressed,
                      ),
                      const SizedBox(width: 8),
                    ],
                    OutlinedButton.icon(
                      onPressed: onHoldPressed,
                      icon: const Icon(Icons.pause_circle_outline, size: 14, color: Color(0xFFD97706)),
                      label: const Text('Hold', style: TextStyle(fontSize: 12, color: Color(0xFFD97706))),
                      style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0284C7),
                        side: const BorderSide(color: Color(0xFF38BDF8)),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.location_searching_rounded, size: 14),
                      label: const Text('Track Tech on Map', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TechnicianLiveTrackingScreen(
                              jobId: request.id,
                              initialJobNumber: request.referenceNumber,
                              initialCustomerName: request.customerName,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
  }
}

class _PriorityBadge extends StatelessWidget {
  final String priority;
  const _PriorityBadge({required this.priority});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label = priority;

    switch (priority.toUpperCase()) {
      case 'EMERGENCY':
        bg = const Color(0xFFFFE4E6);
        fg = const Color(0xFFE11D48);
        label = 'EMERGENCY';
        break;
      case 'HIGH':
        bg = const Color(0xFFFFEDD5);
        fg = const Color(0xFFEA580C);
        label = 'HIGH';
        break;
      case 'LOW':
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF475569);
        label = 'LOW';
        break;
      case 'MEDIUM':
      default:
        bg = const Color(0xFFEFF6FF);
        fg = const Color(0xFF2563EB);
        label = 'MEDIUM';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (status) {
      case 'PENDING_APPROVAL':
        bg = Colors.amber.shade100;
        fg = Colors.amber.shade900;
        break;
      case 'APPROVED':
        bg = Colors.green.shade100;
        fg = Colors.green.shade900;
        break;
      case 'REJECTED':
        bg = Colors.red.shade100;
        fg = Colors.red.shade900;
        break;
      case 'ALTERNATIVE_PROPOSED':
        bg = Colors.blue.shade100;
        fg = Colors.blue.shade900;
        break;
      case 'ON_HOLD':
        bg = Colors.orange.shade100;
        fg = Colors.orange.shade900;
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
