import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme.dart';
import '../../../models/payment.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../services/tenant_portal_service.dart';
import '../../maintenance/screens/add_maintenance_screen.dart';
import '../../settings/settings_screen.dart';
import 'tenant_receipts_screen.dart';

class TenantDashboardScreen extends ConsumerStatefulWidget {
  const TenantDashboardScreen({super.key});

  @override
  ConsumerState<TenantDashboardScreen> createState() => _TenantDashboardScreenState();
}

class _TenantDashboardScreenState extends ConsumerState<TenantDashboardScreen> {
  static const String _reportHeroTag = 'tenant-report-hero';

  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: r'$ ', decimalDigits: 2);

  bool _isLoading = true;
  String? _error;
  TenantDashboardSnapshot? _snapshot;

  @override
  void initState() {
    super.initState();
    _loadSnapshot();
  }

  Future<void> _loadSnapshot() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final snapshot = await TenantPortalService.instance.fetchTenantDashboardSnapshot();
      if (!mounted) {
        return;
      }

      setState(() {
        _snapshot = snapshot;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = 'Failed to load tenant dashboard: $error';
        _isLoading = false;
      });
    }
  }

  Future<void> _openReportIssue() async {
    if (_snapshot == null) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddMaintenanceScreen(
          unitId: _snapshot!.unitId,
          heroTag: _reportHeroTag,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    await _loadSnapshot();
  }

  Future<void> _openReceipts() async {
    if (_snapshot == null) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TenantReceiptsScreen(unitId: _snapshot!.unitId),
      ),
    );
  }

  Widget _buildHistory(List<PaymentRecord> payments) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    if (payments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'No recent payments yet.',
          style: TextStyle(
            fontFamily: AppTheme.appFontFamily,
            fontSize: 14,
          ),
        ),
      );
    }

    return Column(
      children: payments.map((payment) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: onSurface.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            children: [
              const Icon(LucideIcons.receipt, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currencyFormat.format(payment.amountPaid),
                      style: const TextStyle(
                        fontFamily: AppTheme.appFontFamily,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${payment.paymentMethod} • ${DateFormat('dd MMM').format(payment.paymentDate)}',
                      style: TextStyle(
                        fontFamily: AppTheme.appFontFamily,
                        color: onSurface.withValues(alpha: 0.72),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                payment.transactionRef?.isNotEmpty == true ? payment.transactionRef! : 'No Ref',
                style: TextStyle(
                  fontFamily: AppTheme.appFontFamily,
                  color: onSurface.withValues(alpha: 0.72),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Tenant Portal',
          style: TextStyle(fontFamily: AppTheme.appFontFamily),
        ),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(LucideIcons.cog),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(LucideIcons.logOut),
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontFamily: AppTheme.appFontFamily),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadSnapshot,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.highlightAccent.withValues(alpha: 0.45),
                              AppTheme.primaryColor.withValues(alpha: 0.18),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                            color: AppTheme.primaryColor.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          'Welcome Home, ${_snapshot!.displayName}!',
                          style: TextStyle(
                            fontFamily: AppTheme.appFontFamily,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Current Balance',
                                style: TextStyle(
                                  fontFamily: AppTheme.appFontFamily,
                                  color: colorScheme.onSurface.withValues(alpha: 0.8),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _currencyFormat.format(_snapshot!.balanceDue),
                                style: TextStyle(
                                  fontFamily: AppTheme.appFontFamily,
                                  fontSize: 34,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Unit ${_snapshot!.unitNumber}',
                                style: TextStyle(
                                  fontFamily: AppTheme.appFontFamily,
                                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Actions',
                                style: TextStyle(
                                  fontFamily: AppTheme.appFontFamily,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _openReportIssue,
                                      icon: Hero(
                                        tag: _reportHeroTag,
                                        child: Material(
                                          color: Colors.transparent,
                                          child: Icon(
                                            LucideIcons.wrench,
                                            color: Theme.of(context).colorScheme.onPrimary,
                                            size: 18,
                                          ),
                                        ),
                                      ),
                                      label: const Text(
                                        'Report Issue',
                                        style: TextStyle(fontFamily: AppTheme.appFontFamily),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _openReceipts,
                                      icon: const Icon(LucideIcons.receipt),
                                      label: const Text(
                                        'My Receipts',
                                        style: TextStyle(fontFamily: AppTheme.appFontFamily),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'History',
                                style: TextStyle(
                                  fontFamily: AppTheme.appFontFamily,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildHistory(_snapshot!.lastPayments),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
