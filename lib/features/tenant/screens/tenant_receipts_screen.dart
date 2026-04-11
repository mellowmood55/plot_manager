import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../models/payment.dart';
import '../../../services/tenant_portal_service.dart';

class TenantReceiptsScreen extends StatefulWidget {
  const TenantReceiptsScreen({
    super.key,
    required this.unitId,
  });

  final String unitId;

  @override
  State<TenantReceiptsScreen> createState() => _TenantReceiptsScreenState();
}

class _TenantReceiptsScreenState extends State<TenantReceiptsScreen> {
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: r'$ ', decimalDigits: 2);

  bool _isLoading = true;
  String? _error;
  List<PaymentRecord> _receipts = const [];

  @override
  void initState() {
    super.initState();
    _loadReceipts();
  }

  Future<void> _loadReceipts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final items = await TenantPortalService.instance.fetchMyReceipts(widget.unitId);
      if (!mounted) {
        return;
      }

      setState(() {
        _receipts = items;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = 'Failed to load receipts: $error';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Receipts',
          style: TextStyle(fontFamily: AppTheme.appFontFamily),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _error!,
                      style: const TextStyle(fontFamily: AppTheme.appFontFamily),
                    ),
                  ),
                )
              : _receipts.isEmpty
                  ? const Center(
                      child: Text(
                        'No receipts yet.',
                        style: TextStyle(fontFamily: AppTheme.appFontFamily, fontSize: 16),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _receipts.length,
                      separatorBuilder: (_, index) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final payment = _receipts[index];
                        return Card(
                          child: ListTile(
                            title: Text(
                              _currencyFormat.format(payment.amountPaid),
                              style: const TextStyle(
                                fontFamily: AppTheme.appFontFamily,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              '${payment.paymentMethod} • ${DateFormat('dd MMM yyyy').format(payment.paymentDate)}',
                              style: TextStyle(
                                fontFamily: AppTheme.appFontFamily,
                                color: onSurface.withValues(alpha: 0.75),
                              ),
                            ),
                            trailing: Text(
                              payment.transactionRef?.isNotEmpty == true ? payment.transactionRef! : 'No Ref',
                              style: TextStyle(
                                fontFamily: AppTheme.appFontFamily,
                                color: onSurface.withValues(alpha: 0.7),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
