import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme.dart';
import '../../../models/contractor.dart';
import '../../../models/maintenance_request.dart';
import '../../../services/maintenance_service.dart';

class ContractorProfileScreen extends StatefulWidget {
  const ContractorProfileScreen({
    required this.contractor,
    super.key,
  });

  final Contractor contractor;

  @override
  State<ContractorProfileScreen> createState() => _ContractorProfileScreenState();
}

class _ContractorProfileScreenState extends State<ContractorProfileScreen> {
  static const String _fontFamily = 'Comic Sans MS';
  static final NumberFormat _currency = NumberFormat.currency(symbol: r'$ ', decimalDigits: 2);

  bool _isLoading = true;
  String? _error;
  List<MaintenanceRequest> _history = const [];
  int _totalJobsCompleted = 0;
  double _totalEarnings = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final history = await MaintenanceService.instance
          .getMaintenanceRequestsByContractor(widget.contractor.id);

      int jobsCompleted = 0;
      double earnings = 0;
      for (final request in history) {
        final isResolved = request.status == MaintenanceStatus.completed ||
            request.status == MaintenanceStatus.closed ||
            request.resolvedAt != null;
        if (!isResolved) {
          continue;
        }

        jobsCompleted += 1;
        earnings += request.actualCost ?? 0;
      }

      if (!mounted) return;
      setState(() {
        _history = history;
        _totalJobsCompleted = jobsCompleted;
        _totalEarnings = earnings;
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
    final uri = Uri(scheme: 'tel', path: widget.contractor.phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Colors.redAccent,
        content: Text(
          'Could not launch dialer for contractor.',
          style: TextStyle(fontFamily: _fontFamily),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Card(
        color: AppTheme.surfaceColor,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: _fontFamily,
                  color: Color(0xFFCBD5E1),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontFamily: _fontFamily,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              : RefreshIndicator(
                  onRefresh: _loadProfile,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        color: AppTheme.surfaceColor,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.contractor.name,
                                style: const TextStyle(
                                  fontFamily: _fontFamily,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 24,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Specialty: ${widget.contractor.specialty}',
                                style: const TextStyle(
                                  fontFamily: _fontFamily,
                                  color: Color(0xFFCBD5E1),
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _callContractor,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0D9488),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                  ),
                                  icon: const Icon(Icons.call, size: 22),
                                  label: const Text(
                                    'Call Contractor',
                                    style: TextStyle(
                                      fontFamily: _fontFamily,
                                      fontWeight: FontWeight.bold,
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
                          _buildStatCard(
                            title: 'Total Jobs Completed',
                            value: _totalJobsCompleted.toString(),
                            color: const Color(0xFF0D9488),
                          ),
                          const SizedBox(width: 12),
                          _buildStatCard(
                            title: 'Total Earnings',
                            value: _currency.format(_totalEarnings),
                            color: const Color(0xFFF97316),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Maintenance History',
                        style: TextStyle(
                          fontFamily: _fontFamily,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_history.isEmpty)
                        Card(
                          color: AppTheme.surfaceColor,
                          child: const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'No tickets assigned to this contractor yet.',
                              style: TextStyle(fontFamily: _fontFamily),
                            ),
                          ),
                        )
                      else
                        ..._history.map(
                          (request) => Card(
                            color: AppTheme.surfaceColor,
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              title: Text(
                                request.title,
                                style: const TextStyle(
                                  fontFamily: _fontFamily,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                '${request.category}  •  ${request.status.displayName}  •  ${_formatDate(request.createdAt)}',
                                style: const TextStyle(fontFamily: _fontFamily),
                              ),
                              trailing: Text(
                                _currency.format(request.actualCost ?? 0),
                                style: const TextStyle(
                                  fontFamily: _fontFamily,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFF97316),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}
