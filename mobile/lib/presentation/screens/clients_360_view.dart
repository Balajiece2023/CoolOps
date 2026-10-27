import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../providers/app_providers.dart';

class Clients360View extends ConsumerStatefulWidget {
  const Clients360View({super.key});

  @override
  ConsumerState<Clients360View> createState() => _Clients360ViewState();
}

class _Clients360ViewState extends ConsumerState<Clients360View> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _clients = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  Future<void> _loadClients({String? query}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final clients = await ref.read(apiRepositoryProvider).getClients(search: query);
      setState(() {
        _clients = clients;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _showEditClientDialog(Map<String, dynamic> client) {
    final nameCtrl = TextEditingController(text: client['name'] ?? '');
    final phoneCtrl = TextEditingController(text: client['phone'] ?? '');
    final emailCtrl = TextEditingController(text: client['email'] ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.edit_outlined, color: AppTheme.primaryBlue),
            SizedBox(width: 8),
            Text('Edit Client Profile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Client Name')),
            const SizedBox(height: 8),
            TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Primary Phone')),
            const SizedBox(height: 8),
            TextField(controller: emailCtrl, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email Address')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              try {
                await ref.read(apiRepositoryProvider).updateClient(
                      clientId: client['id'],
                      name: nameCtrl.text.trim(),
                      phone: phoneCtrl.text.trim(),
                      email: emailCtrl.text.trim().isNotEmpty ? emailCtrl.text.trim() : null,
                    );
                if (ctx.mounted) Navigator.pop(ctx);
                _loadClients(query: _searchController.text.trim());
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Client details updated!')));
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Update failed: $e'), backgroundColor: Colors.red));
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showClientHistorySheet(String clientId) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => FutureBuilder<Map<String, dynamic>>(
        future: ref.read(apiRepositoryProvider).getClient360(clientId),
        builder: (ctx, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(height: 300, child: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasError) {
            return SizedBox(height: 200, child: Center(child: Text('Error: ${snapshot.error}')));
          }

          final data = snapshot.data!;
          final bookings = (data['bookings'] as List?) ?? [];
          final invoices = (data['invoices'] as List?) ?? [];
          final metrics = data['metrics'] ?? {};

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.8,
            maxChildSize: 0.95,
            builder: (ctx, scrollController) => Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                controller: scrollController,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(data['name'] ?? 'Client', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('${data['phone']} • ${data['email'] ?? 'No email'}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(8)),
                        child: Text(
                          '₹${(metrics['totalLifetimeSpend'] ?? 0).toStringAsFixed(0)} LTV',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF15803D), fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _MetricBox(title: 'Bookings', value: '${metrics['totalBookings'] ?? 0}'),
                      const SizedBox(width: 8),
                      _MetricBox(title: 'Invoices', value: '${metrics['totalInvoices'] ?? 0}'),
                    ],
                  ),
                  const Divider(height: 24),
                  const Text('Past Service History', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (bookings.isEmpty)
                    const Text('No bookings found for this customer.', style: TextStyle(color: Color(0xFF64748B), fontStyle: FontStyle.italic))
                  else
                    ...bookings.map((b) {
                      final service = b['serviceType']?['nameEn'] ?? 'Service';
                      final date = (b['scheduledDate'] as String?)?.split('T')[0] ?? '';
                      final status = b['status'] ?? 'CONFIRMED';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text('$service (${b['bookingNumber']})', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          subtitle: Text('Date: $date • ${b['timeSlot']}'),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(4)),
                            child: Text(status, style: const TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold, fontSize: 10)),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clients 360 & History', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => _loadClients(query: _searchController.text.trim())),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => _loadClients(query: val.trim()),
              decoration: InputDecoration(
                hintText: 'Search by client name, mobile or email...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _loadClients();
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(child: Text('Error: $_errorMessage', style: const TextStyle(color: Colors.red)))
                    : _clients.isEmpty
                        ? const Center(child: Text('No clients found.'))
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                            itemCount: _clients.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (ctx, i) {
                              final c = _clients[i];
                              final counts = c['_count'] ?? {};
                              final int bkgCount = counts['bookings'] ?? 0;
                              final int invCount = counts['invoices'] ?? 0;

                              return Card(
                                child: ListTile(
                                  leading: const CircleAvatar(
                                    backgroundColor: Color(0xFFEFF6FF),
                                    child: Icon(Icons.person, color: AppTheme.primaryBlue),
                                  ),
                                  title: Text(c['name'] ?? 'Client', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  subtitle: Text('${c['phone']} • $bkgCount bookings, $invCount invoices', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.visibility_outlined, color: AppTheme.primaryBlue, size: 20),
                                        tooltip: 'Client 360 History',
                                        onPressed: () => _showClientHistorySheet(c['id']),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, color: Color(0xFF64748B), size: 20),
                                        tooltip: 'Edit Client',
                                        onPressed: () => _showEditClientDialog(c),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class _MetricBox extends StatelessWidget {
  final String title;
  final String value;
  const _MetricBox({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          ],
        ),
      ),
    );
  }
}
