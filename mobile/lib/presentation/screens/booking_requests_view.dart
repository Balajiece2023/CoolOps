import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../providers/app_providers.dart';

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
                        onApprovePressed: () => _showApproveDialog(context, req),
                        onRejectPressed: () => _showRejectDialog(context, req),
                        onProposePressed: () => _showProposeDialog(context, req),
                        onEditPressed: () => _showEditBookingDialog(context, req),
                        onDeletePressed: () => _showDeleteBookingDialog(context, req),
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
    final pinCtrl = TextEditingController(text: '600020');
    final complaintCtrl = TextEditingController();
    final brandCtrl = TextEditingController(text: 'Daikin');
    final dateCtrl = TextEditingController(text: DateTime.now().add(const Duration(days: 1)).toString().split(' ')[0]);
    String priority = 'MEDIUM';
    String timeSlot = '09:00-11:00';
    String serviceId = '00000000-0000-0000-0000-000000000001'; // Default service
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
                  const Divider(height: 24),
                  const Text('Ticket Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryBlue)),
                  const SizedBox(height: 6),
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
                  TextField(controller: complaintCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Customer Issue / Complaint *')),
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

                try {
                  await ref.read(apiRepositoryProvider).createTicket(
                        customerName: nameCtrl.text.trim(),
                        customerPhone: phoneCtrl.text.trim(),
                        addressLine: addrCtrl.text.trim(),
                        area: areaCtrl.text.trim().isNotEmpty ? areaCtrl.text.trim() : 'Chennai Central',
                        pincode: pinCtrl.text.trim(),
                        serviceTypeId: serviceId,
                        complaint: complaintCtrl.text.trim(),
                        priority: priority,
                        acBrand: brandCtrl.text.trim(),
                        acType: acType,
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
  final VoidCallback onApprovePressed;
  final VoidCallback onRejectPressed;
  final VoidCallback onProposePressed;
  final VoidCallback onEditPressed;
  final VoidCallback onDeletePressed;

  const _RequestCard({
    required this.request,
    required this.isAdmin,
    required this.onApprovePressed,
    required this.onRejectPressed,
    required this.onProposePressed,
    required this.onEditPressed,
    required this.onDeletePressed,
  });

  @override
  Widget build(BuildContext context) {
    final isPending = request.status == 'PENDING_APPROVAL';

    return Card(
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
            Text(request.customerName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text('${request.customerPhone} • ${request.area}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            const SizedBox(height: 6),
            Container(
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

            if (isPending) ...[
              const Divider(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
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
                      label: const Text('Assign Technician', style: TextStyle(fontSize: 12)),
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
          ],
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
