import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../providers/app_providers.dart';

class FieldServiceReportsView extends ConsumerStatefulWidget {
  final String? initialJobId;
  const FieldServiceReportsView({super.key, this.initialJobId});

  @override
  ConsumerState<FieldServiceReportsView> createState() => _FieldServiceReportsViewState();
}

class _FieldServiceReportsViewState extends ConsumerState<FieldServiceReportsView> {
  String _selectedType = 'ALL';
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _openPdf(String reportId) async {
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                SizedBox(width: 12),
                Text('Opening Field Service Report PDF...'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }

      final repo = ref.read(apiRepositoryProvider);
      final url = await repo.getFieldServiceReportPdfUrl(reportId);
      final uri = Uri.parse(url);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        await Clipboard.setData(ClipboardData(text: url));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open automatically. Download link copied to clipboard:\n$url'),
            action: SnackBarAction(
              label: 'Copy',
              textColor: Colors.amber,
              onPressed: () => Clipboard.setData(ClipboardData(text: url)),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _showReportOverview(FieldServiceReportModel report) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.88,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Title Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.assignment_outlined, color: AppTheme.primaryBlue, size: 20),
                          const SizedBox(width: 8),
                          const Text('FIELD SERVICE REPORT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                      Text('Official Service Execution Sheet', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Text('No. ${report.reportNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryBlue)),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Classification Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Text('REPORT TYPE: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569))),
                    Text(report.reportTypeFormatted, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primaryBlue)),
                    const Spacer(),
                    Text('Attended: ${report.attendingDate}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Customer & Dealer Info Box
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Customer Details
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('CUSTOMER DETAILS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                          const SizedBox(height: 4),
                          Text(report.customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 2),
                          Text(report.customerAddress, style: const TextStyle(fontSize: 11, color: Color(0xFF334155))),
                          if (report.contactPhone != null && report.contactPhone!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text('Tel: ${report.contactPhone}', style: const TextStyle(fontSize: 11, color: Color(0xFF0F172A), fontWeight: FontWeight.w500)),
                          ],
                          if (report.personCalling != null && report.personCalling!.isNotEmpty) ...[
                            Text('Caller: ${report.personCalling}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Dealer Details
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFECDD3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('DEALER & SERVICE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                          const SizedBox(height: 4),
                          const Text('CARING COOL TECH', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFFB91C1C))),
                          const SizedBox(height: 2),
                          const Text('Vallalarpet, Puducherry - 605 004', style: TextStyle(fontSize: 10, color: Color(0xFF475569))),
                          const SizedBox(height: 4),
                          Text('Engg: ${report.serviceEngineerName}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Serial Numbers & Equipment
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('INDOOR SERIAL NO:', style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                          Text(report.indoorSerialNo ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('OUTDOOR SERIAL NO:', style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                          Text(report.outdoorSerialNo ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Observations / Action Taken Box
              const Text('OBSERVATIONS / REPORT & ACTION TAKEN:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Text(
                  report.observations,
                  style: const TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF78350F), fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(height: 14),

              // Suggestion to customer
              if (report.suggestions != null && report.suggestions!.isNotEmpty) ...[
                const Text('SUGGESTION TO CUSTOMER:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Text(report.suggestions!, style: const TextStyle(fontSize: 12, color: Color(0xFF166534))),
                ),
                const SizedBox(height: 14),
              ],

              // Final Test Measurements (As applicable)
              const Row(
                children: [
                  Icon(Icons.speed_outlined, color: AppTheme.primaryBlue, size: 16),
                  SizedBox(width: 6),
                  Text('FINAL TEST MEASUREMENTS (AS APPLICABLE):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(9)),
                      ),
                      child: Row(
                        children: [
                          const Text('Power Servo / Stab: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                          Text(
                            report.powerServoStab != null ? report.powerServoStab!.toUpperCase() : 'NO',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: (report.powerServoStab ?? '').toUpperCase() == 'YES' ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildParamRow('Voltage (N - Earth)', report.voltageNEarth ?? '-'),
                    _buildParamRow('Voltage (L1 - N)', report.voltageL1N ?? report.voltage ?? '-'),
                    _buildParamRow('Voltage (L1 - L2)', report.voltageL1L2 ?? '-'),
                    _buildParamRow('Voltage (L2 - N)', report.voltageL2N ?? '-'),
                    _buildParamRow('Voltage (L2 - L3)', report.voltageL2L3 ?? '-'),
                    _buildParamRow('Voltage (L3 - N)', report.voltageL3N ?? '-'),
                    _buildParamRow('Voltage (L3 - L1)', report.voltageL3L1 ?? '-'),
                    _buildParamRow('Suction Pressure (psi)', report.pressSuc ?? report.suctionPressure ?? '-'),
                    _buildParamRow('Discharge Pressure (psi)', report.pressDis ?? report.dischargePressure ?? '-'),
                    _buildParamRow('Compressor Current (Amp)', report.compCurrent ?? '-'),
                    _buildParamRow('Unit Currents (Amp)', report.unitCurrents ?? report.runningCurrent ?? '-'),
                    _buildParamRow('Room Temp (°C)', report.roomTemp ?? report.roomTemperature ?? '-'),
                    _buildParamRow('Supply Air Temp (°C)', report.supplyAirTemp ?? '-'),
                    _buildParamRow('Return Air Temp (°C)', report.returnAirTemp ?? '-'),
                    _buildParamRow('Ambient Temp (°C)', report.ambientTemp ?? '-', isLast: true),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Bottom Actions: Download PDF
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.picture_as_pdf, size: 20),
                label: const Text('Download Official Report PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                onPressed: () {
                  Navigator.pop(ctx);
                  _openPdf(report.id);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildParamRow(String label, String value, {bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF334155)))),
          Expanded(flex: 2, child: Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))),
        ],
      ),
    );
  }

  void _showCreateReportModal({ServiceJobModel? prefilledJob}) {
    final reportNoCtrl = TextEditingController(text: '');
    String reportType = 'DO_AND_CHARGE_REPAIR';
    final custNameCtrl = TextEditingController(text: prefilledJob?.customerName ?? '');
    final custAddrCtrl = TextEditingController(text: prefilledJob?.address ?? '');
    final phoneCtrl = TextEditingController(text: prefilledJob?.customerPhone ?? '');
    final personCallingCtrl = TextEditingController();
    final engineerCtrl = TextEditingController();
    final complaintDateCtrl = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
    final attendingDateCtrl = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
    final modelCtrl = TextEditingController(text: prefilledJob?.acDetails ?? '');
    final indoorSlCtrl = TextEditingController();
    final outdoorSlCtrl = TextEditingController();
    final errorCodeCtrl = TextEditingController(text: 'NONE');
    String powerServoStab = 'NO';
    final voltageNEarthCtrl = TextEditingController();
    final voltageL1NCtrl = TextEditingController(text: '230 V');
    final voltageL2NCtrl = TextEditingController();
    final voltageL3NCtrl = TextEditingController();
    final voltageL1L2Ctrl = TextEditingController();
    final voltageL2L3Ctrl = TextEditingController();
    final voltageL3L1Ctrl = TextEditingController();
    final pressSucCtrl = TextEditingController(text: '65');
    final pressDisCtrl = TextEditingController(text: '250');
    final compCurrentCtrl = TextEditingController(text: '14.5');
    final unitCurrentsCtrl = TextEditingController(text: '14.5');
    final roomTempCtrl = TextEditingController(text: '22');
    final supplyAirTempCtrl = TextEditingController();
    final returnAirTempCtrl = TextEditingController();
    final ambientTempCtrl = TextEditingController(text: '32');
    final obsCtrl = TextEditingController(text: prefilledJob?.notes ?? prefilledJob?.diagnosis ?? '');
    final sugCtrl = TextEditingController(text: 'Recommend regular filter wash every 15 days.');
    final custSignCtrl = TextEditingController(text: prefilledJob?.customerName ?? '');

    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => DraggableScrollableSheet(
          initialChildSize: 0.92,
          minChildSize: 0.6,
          maxChildSize: 0.97,
          builder: (_, scrollController) => Container(
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
              controller: scrollController,
              children: [
                Center(
                  child: Container(
                    width: 44,
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
                    const Icon(Icons.post_add_rounded, color: AppTheme.primaryBlue, size: 24),
                    const SizedBox(width: 8),
                    const Text('New Field Service Report Entry', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                Text('Create official CCT report sheet after completing field job', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                const Divider(height: 24),

                // Report Type Selector
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
                    if (val != null) setModalState(() => reportType = val);
                  },
                ),
                const SizedBox(height: 12),

                // Report Number (Optional custom, e.g. 1110)
                TextField(
                  controller: reportNoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Report Number (Optional, auto-generated if blank)',
                    hintText: 'e.g. 1110 or FSR-1110',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                // Customer Details
                const Text('Customer & Site Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 6),
                TextField(
                  controller: custNameCtrl,
                  decoration: const InputDecoration(labelText: 'Customer Name *', isDense: true, border: OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: custAddrCtrl,
                  decoration: const InputDecoration(labelText: 'Customer Address *', isDense: true, border: OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'Contact Phone', isDense: true, border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: personCallingCtrl,
                        decoration: const InputDecoration(labelText: 'Person Calling', isDense: true, border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Equipment & Serials
                const Text('Equipment & Serial Numbers', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 6),
                TextField(
                  controller: modelCtrl,
                  decoration: const InputDecoration(labelText: 'AC Model / Tonnage', hintText: 'e.g. 17 Ton Package / Daikin 1.5T', isDense: true, border: OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: indoorSlCtrl,
                        decoration: const InputDecoration(labelText: 'Indoor SL No.', isDense: true, border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: outdoorSlCtrl,
                        decoration: const InputDecoration(labelText: 'Outdoor SL No.', isDense: true, border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Observations & Action Taken (Crucial)
                const Text('Observations / Report & Action Taken *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 6),
                TextField(
                  controller: obsCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'e.g. 17 Ton Package Outdoor fan motor changed. 2nd floor 3-phase contactor replaced. All units running in good condition.',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: sugCtrl,
                  decoration: const InputDecoration(labelText: 'Suggestion to Customer', isDense: true, border: OutlineInputBorder()),
                ),
                const SizedBox(height: 14),

                // Final Test Measurements (As applicable)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.speed, color: AppTheme.primaryBlue, size: 18),
                          const SizedBox(width: 6),
                          const Text('Final Test Measurements (As applicable)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryBlue)),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Power Servo/Stab
                      Row(
                        children: [
                          const Text('Power Servo / Stab: ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Yes'),
                            selected: powerServoStab == 'YES',
                            onSelected: (val) => setModalState(() => powerServoStab = val ? 'YES' : 'NO'),
                            visualDensity: VisualDensity.compact,
                          ),
                          const SizedBox(width: 6),
                          ChoiceChip(
                            label: const Text('No'),
                            selected: powerServoStab == 'NO',
                            onSelected: (val) => setModalState(() => powerServoStab = val ? 'NO' : 'YES'),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      const Divider(height: 16),

                      // Voltages Section
                      const Text('Voltages (V)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569))),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: voltageNEarthCtrl, decoration: const InputDecoration(labelText: 'N-Earth', hintText: 'e.g. 2V', isDense: true, border: OutlineInputBorder()))),
                          const SizedBox(width: 6),
                          Expanded(child: TextField(controller: voltageL1NCtrl, decoration: const InputDecoration(labelText: 'L1-N', hintText: 'e.g. 230V', isDense: true, border: OutlineInputBorder()))),
                          const SizedBox(width: 6),
                          Expanded(child: TextField(controller: voltageL1L2Ctrl, decoration: const InputDecoration(labelText: 'L1-L2', hintText: 'e.g. 400V', isDense: true, border: OutlineInputBorder()))),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: voltageL2NCtrl, decoration: const InputDecoration(labelText: 'L2-N', hintText: 'e.g. 230V', isDense: true, border: OutlineInputBorder()))),
                          const SizedBox(width: 6),
                          Expanded(child: TextField(controller: voltageL2L3Ctrl, decoration: const InputDecoration(labelText: 'L2-L3', hintText: 'e.g. 400V', isDense: true, border: OutlineInputBorder()))),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: voltageL3NCtrl, decoration: const InputDecoration(labelText: 'L3-N', hintText: 'e.g. 230V', isDense: true, border: OutlineInputBorder()))),
                          const SizedBox(width: 6),
                          Expanded(child: TextField(controller: voltageL3L1Ctrl, decoration: const InputDecoration(labelText: 'L3-L1', hintText: 'e.g. 400V', isDense: true, border: OutlineInputBorder()))),
                        ],
                      ),
                      const Divider(height: 16),

                      // Pressures & Currents
                      const Text('Pressures (psi) & Currents (Amp)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569))),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: pressSucCtrl, decoration: const InputDecoration(labelText: 'Press (Suc) psi', hintText: '65', isDense: true, border: OutlineInputBorder()))),
                          const SizedBox(width: 6),
                          Expanded(child: TextField(controller: pressDisCtrl, decoration: const InputDecoration(labelText: 'Press (Dis) psi', hintText: '250', isDense: true, border: OutlineInputBorder()))),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: compCurrentCtrl, decoration: const InputDecoration(labelText: 'Comp. Current (A)', hintText: '14.5', isDense: true, border: OutlineInputBorder()))),
                          const SizedBox(width: 6),
                          Expanded(child: TextField(controller: unitCurrentsCtrl, decoration: const InputDecoration(labelText: 'Unit Currents (A)', hintText: '14.5', isDense: true, border: OutlineInputBorder()))),
                        ],
                      ),
                      const Divider(height: 16),

                      // Temperatures
                      const Text('Temperatures (°C)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569))),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: roomTempCtrl, decoration: const InputDecoration(labelText: 'Room Temp °C', hintText: '22', isDense: true, border: OutlineInputBorder()))),
                          const SizedBox(width: 6),
                          Expanded(child: TextField(controller: supplyAirTempCtrl, decoration: const InputDecoration(labelText: 'Supply Air °C', hintText: '12', isDense: true, border: OutlineInputBorder()))),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: returnAirTempCtrl, decoration: const InputDecoration(labelText: 'Return Air °C', hintText: '24', isDense: true, border: OutlineInputBorder()))),
                          const SizedBox(width: 6),
                          Expanded(child: TextField(controller: ambientTempCtrl, decoration: const InputDecoration(labelText: 'Ambient °C', hintText: '32', isDense: true, border: OutlineInputBorder()))),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: custSignCtrl,
                  decoration: const InputDecoration(labelText: 'Customer Signature Name / Rep', isDense: true, border: OutlineInputBorder()),
                ),
                const SizedBox(height: 20),

                // Submit Button
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: isSubmitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.check_circle_outline, size: 20),
                  label: Text(isSubmitting ? 'Saving...' : 'Save & Generate Official Report PDF', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (custNameCtrl.text.trim().isEmpty || obsCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('Please enter customer name and observations')),
                            );
                            return;
                          }

                          setModalState(() => isSubmitting = true);
                          try {
                            final repo = ref.read(apiRepositoryProvider);
                            final created = await repo.createFieldServiceReport(
                              serviceJobId: prefilledJob?.id,
                              reportNumber: reportNoCtrl.text.trim().isNotEmpty ? reportNoCtrl.text.trim() : null,
                              reportType: reportType,
                              customerName: custNameCtrl.text.trim(),
                              customerAddress: custAddrCtrl.text.trim().isNotEmpty ? custAddrCtrl.text.trim() : 'On Site',
                              contactPhone: phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
                              personCalling: personCallingCtrl.text.trim().isNotEmpty ? personCallingCtrl.text.trim() : null,
                              serviceEngineerName: engineerCtrl.text.trim().isNotEmpty ? engineerCtrl.text.trim() : null,
                              complaintDate: complaintDateCtrl.text.trim(),
                              attendingDate: attendingDateCtrl.text.trim(),
                              modelNumber: modelCtrl.text.trim().isNotEmpty ? modelCtrl.text.trim() : null,
                              indoorSerialNo: indoorSlCtrl.text.trim().isNotEmpty ? indoorSlCtrl.text.trim() : null,
                              outdoorSerialNo: outdoorSlCtrl.text.trim().isNotEmpty ? outdoorSlCtrl.text.trim() : null,
                              errorCode: errorCodeCtrl.text.trim().isNotEmpty ? errorCodeCtrl.text.trim() : null,
                              runningCurrent: unitCurrentsCtrl.text.trim().isNotEmpty ? unitCurrentsCtrl.text.trim() : null,
                              suctionPressure: pressSucCtrl.text.trim().isNotEmpty ? pressSucCtrl.text.trim() : null,
                              dischargePressure: pressDisCtrl.text.trim().isNotEmpty ? pressDisCtrl.text.trim() : null,
                              roomTemperature: roomTempCtrl.text.trim().isNotEmpty ? roomTempCtrl.text.trim() : null,
                              voltage: voltageL1NCtrl.text.trim().isNotEmpty ? voltageL1NCtrl.text.trim() : null,
                              powerServoStab: powerServoStab,
                              voltageNEarth: voltageNEarthCtrl.text.trim().isNotEmpty ? voltageNEarthCtrl.text.trim() : null,
                              voltageL1N: voltageL1NCtrl.text.trim().isNotEmpty ? voltageL1NCtrl.text.trim() : null,
                              voltageL2N: voltageL2NCtrl.text.trim().isNotEmpty ? voltageL2NCtrl.text.trim() : null,
                              voltageL3N: voltageL3NCtrl.text.trim().isNotEmpty ? voltageL3NCtrl.text.trim() : null,
                              voltageL1L2: voltageL1L2Ctrl.text.trim().isNotEmpty ? voltageL1L2Ctrl.text.trim() : null,
                              voltageL2L3: voltageL2L3Ctrl.text.trim().isNotEmpty ? voltageL2L3Ctrl.text.trim() : null,
                              voltageL3L1: voltageL3L1Ctrl.text.trim().isNotEmpty ? voltageL3L1Ctrl.text.trim() : null,
                              pressSuc: pressSucCtrl.text.trim().isNotEmpty ? pressSucCtrl.text.trim() : null,
                              pressDis: pressDisCtrl.text.trim().isNotEmpty ? pressDisCtrl.text.trim() : null,
                              compCurrent: compCurrentCtrl.text.trim().isNotEmpty ? compCurrentCtrl.text.trim() : null,
                              unitCurrents: unitCurrentsCtrl.text.trim().isNotEmpty ? unitCurrentsCtrl.text.trim() : null,
                              roomTemp: roomTempCtrl.text.trim().isNotEmpty ? roomTempCtrl.text.trim() : null,
                              supplyAirTemp: supplyAirTempCtrl.text.trim().isNotEmpty ? supplyAirTempCtrl.text.trim() : null,
                              returnAirTemp: returnAirTempCtrl.text.trim().isNotEmpty ? returnAirTempCtrl.text.trim() : null,
                              ambientTemp: ambientTempCtrl.text.trim().isNotEmpty ? ambientTempCtrl.text.trim() : null,
                              observations: obsCtrl.text.trim(),
                              suggestions: sugCtrl.text.trim().isNotEmpty ? sugCtrl.text.trim() : null,
                              customerSignName: custSignCtrl.text.trim().isNotEmpty ? custSignCtrl.text.trim() : null,
                            );

                            Navigator.pop(ctx);
                            ref.refresh(fieldServiceReportsProvider(null));

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Field Service Report No. ${created.reportNumber} created!'),
                                  backgroundColor: const Color(0xFF16A34A),
                                  action: SnackBarAction(
                                    label: 'Open PDF',
                                    textColor: Colors.white,
                                    onPressed: () => _openPdf(created.id),
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            setModalState(() => isSubmitting = false);
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

  @override
  Widget build(BuildContext context) {
    final reportsAsync = ref.watch(fieldServiceReportsProvider(_selectedType == 'ALL' ? null : _selectedType));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Field Service Reports', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(fieldServiceReportsProvider(_selectedType == 'ALL' ? null : _selectedType)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Report Entry', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => _showCreateReportModal(),
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            color: Colors.white,
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search by Customer, Report No. or Observations...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('ALL', 'All Reports'),
                      _buildFilterChip('DO_AND_CHARGE_REPAIR', 'Do & Charge Repair'),
                      _buildFilterChip('WARRANTY', 'Warranty'),
                      _buildFilterChip('COMMISSIONING', 'Commissioning'),
                      _buildFilterChip('MAIN_CONTACT', 'Maintenance (AMC)'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Reports List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.refresh(fieldServiceReportsProvider(_selectedType == 'ALL' ? null : _selectedType));
              },
              child: reportsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Error loading reports: $err')),
                data: (allReports) {
                  final filtered = allReports.where((r) {
                    if (_searchQuery.isEmpty) return true;
                    return r.customerName.toLowerCase().contains(_searchQuery) ||
                        r.reportNumber.toLowerCase().contains(_searchQuery) ||
                        r.customerAddress.toLowerCase().contains(_searchQuery) ||
                        r.serviceEngineerName.toLowerCase().contains(_searchQuery) ||
                        r.observations.toLowerCase().contains(_searchQuery);
                  }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.assignment_outlined, size: 54, color: Color(0xFF94A3B8)),
                            const SizedBox(height: 12),
                            const Text('No field service reports found', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                            const SizedBox(height: 4),
                            const Text('Technicians can create reports after completing service jobs.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B)), textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Create First Report'),
                              onPressed: () => _showCreateReportModal(),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final rep = filtered[i];
                      return _buildReportCard(rep);
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

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedType == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : const Color(0xFF475569),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 11,
        ),
        backgroundColor: const Color(0xFFF1F5F9),
        selectedColor: AppTheme.primaryBlue,
        showCheckmark: false,
        onSelected: (_) => setState(() => _selectedType = key),
      ),
    );
  }

  Widget _buildReportCard(FieldServiceReportModel rep) {
    Color typeColor = AppTheme.primaryBlue;
    if (rep.reportType == 'WARRANTY') typeColor = const Color(0xFF16A34A);
    if (rep.reportType == 'COMMISSIONING') typeColor = const Color(0xFFEA580C);
    if (rep.reportType == 'MAIN_CONTACT' || rep.reportType == 'MAINTENANCE_CONTRACT') typeColor = const Color(0xFF7C3AED);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFFE2E8F0))),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Number, Type & Date
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(6)),
                      child: Text('FSR #${rep.reportNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primaryBlue)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: typeColor.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                      child: Text(rep.reportTypeFormatted, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: typeColor)),
                    ),
                  ],
                ),
                Text(rep.attendingDate, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              ],
            ),
            const SizedBox(height: 10),

            // Customer Name & Address
            Text(rep.customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 2),
            Text(rep.customerAddress, style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
            if (rep.contactPhone != null) ...[
              const SizedBox(height: 2),
              Text('Contact: ${rep.contactPhone}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
            ],
            const SizedBox(height: 6),

            // Engineer & Model
            Row(
              children: [
                const Icon(Icons.person_pin_outlined, size: 14, color: AppTheme.primaryBlue),
                const SizedBox(width: 4),
                Text('Engg: ${rep.serviceEngineerName}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                if (rep.modelNumber != null) ...[
                  const SizedBox(width: 12),
                  const Icon(Icons.ac_unit, size: 13, color: Color(0xFF0D9488)),
                  const SizedBox(width: 4),
                  Expanded(child: Text(rep.modelNumber!, style: const TextStyle(fontSize: 11, color: Color(0xFF0D9488)), overflow: TextOverflow.ellipsis)),
                ],
              ],
            ),
            const SizedBox(height: 8),

            // Observations preview
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Action: ${rep.observations}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: Color(0xFF334155), fontStyle: FontStyle.italic),
              ),
            ),
            const Divider(height: 18),

            // Action Buttons: Overview & Download PDF
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.visibility_outlined, size: 14),
                  label: const Text('Overview Details', style: TextStyle(fontSize: 11)),
                  onPressed: () => _showReportOverview(rep),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.picture_as_pdf, size: 14),
                  label: const Text('Download PDF', style: TextStyle(fontSize: 11)),
                  onPressed: () => _openPdf(rep.id),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

