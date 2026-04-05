import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme.dart';
import '../../../models/contractor.dart';
import '../../../models/maintenance_request.dart';
import '../../../services/maintenance_service.dart';
import 'maintenance_detail_screen.dart';

class ContractorProfileScreen extends StatefulWidget {
  const ContractorProfileScreen({
    required this.contractorId,
    this.initialContractor,
    super.key,
  });

  final String contractorId;
  final Contractor? initialContractor;

  @override
  State<ContractorProfileScreen> createState() => _ContractorProfileScreenState();
}

class _ContractorProfileScreenState extends State<ContractorProfileScreen> {
  static const String _fontFamily = 'Comic Sans MS';
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: r'$ ', decimalDigits: 2);

  bool _isLoading = true;
  String? _error;
  Contractor? _contractor;
  List<MaintenanceRequest> _history = const [];

  @override
  void initState() {
    super.initState();
    _contractor = widget.initialContractor;
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final contractorFuture = MaintenanceService.instance.getContractorById(widget.contractorId);
      final historyFuture =
          MaintenanceService.instance.getMaintenanceRequestsByContractor(widget.contractorId);
      final results = await Future.wait<dynamic>([contractorFuture, historyFuture]);

      final contractor = results[0] as Contractor?;
      final history = results[1] as List<MaintenanceRequest>;

      if (!mounted) return;
      setState(() {
        _contractor = contractor ?? _contractor;
        _history = history;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load contractor profile: $error';
        _isLoading = false;
      });
    }
  }

  Future<void> _callContractor() async {
    final phone = _contractor?.phone.trim() ?? '';
    if (phone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: const Text(
            'Contractor phone number is missing.',
            style: TextStyle(fontFamily: _fontFamily),
          ),
        ),
      );
      return;
    }

    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.red.shade700,
        content: const Text(
          'Could not open dialer for contractor.',
          style: TextStyle(fontFamily: _fontFamily),
        ),
      ),
    );
  }

  bool _isResolved(MaintenanceRequest item) {
    return item.status == MaintenanceStatus.completed || item.status == MaintenanceStatus.closed;
  }

  @override
  Widget build(BuildContext context) {
    final contractor = _contractor;
    final resolved = _history.where(_isResolved).toList();
    final totalCompleted = resolved.length;
    final totalEarnings = resolved.fold<double>(
      0,
      (sum, item) => sum + (item.actualCost ?? 0),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Contractor Profile',
          style: TextStyle(fontFamily: _fontFamily),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontFamily: _fontFamily),
                    ),
                  ),
                )
              : contractor == null
                  ? const Center(
                      child: Text(
                        'Contractor not found.',
                        style: TextStyle(fontFamily: _fontFamily),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    contractor.name,
                                    style: const TextStyle(
                                      fontFamily: _fontFamily,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    contractor.specialty,
                                    style: TextStyle(
                                      fontFamily: _fontFamily,
                                      fontSize: 16,
                                      color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[500]! : Color(0xFFCBD5E1),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: _callContractor,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primaryColor,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                      ),
                                      icon: const Icon(Icons.call, size: 22),
                                      label: const Text(
                                        'Call Contractor',
                                        style: TextStyle(
                                          fontFamily: _fontFamily,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 18,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _StatCard(
                                  title: 'Total Jobs Completed',
                                  value: totalCompleted.toString(),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _StatCard(
                                  title: 'Total Earnings',
                                  value: _currencyFormat.format(totalEarnings),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Maintenance History',
                            style: TextStyle(
                              fontFamily: _fontFamily,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (_history.isEmpty)
                            const Card(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Text(
                                  'No maintenance history yet for this contractor.',
                                  style: TextStyle(fontFamily: _fontFamily),
                                ),
                              ),
                            )
                          else
                            ..._history.map(
                              (item) => Card(
                                child: ListTile(
                                  title: Text(
                                    item.title,
                                    style: const TextStyle(
                                      fontFamily: _fontFamily,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${item.category} • ${item.status.displayName}',
                                    style: const TextStyle(fontFamily: _fontFamily),
                                  ),
                                  trailing: Text(
                                    item.actualCost == null
                                        ? '-'
                                        : _currencyFormat.format(item.actualCost),
                                    style: TextStyle(
                                      fontFamily: _fontFamily,
                                      color: AppTheme.primaryColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  onTap: () async {
                                    if (!mounted) return;
                                    await Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => MaintenanceDetailScreen(requestId: item.id),
                                      ),
                                    );
                                    if (!mounted) return;
                                    await _load();
                                  },
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
  });

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Comic Sans MS',
                fontSize: 13,
                color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[500]! : Color(0xFFCBD5E1),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontFamily: 'Comic Sans MS',
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
