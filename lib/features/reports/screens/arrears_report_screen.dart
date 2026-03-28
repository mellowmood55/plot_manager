import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme.dart';
import '../../../services/finance_service.dart';

class ArrearsReportScreen extends StatefulWidget {
  const ArrearsReportScreen({super.key});

  @override
  State<ArrearsReportScreen> createState() => _ArrearsReportScreenState();
}

class _ArrearsReportScreenState extends State<ArrearsReportScreen> {
  static const String _fontFamily = 'Comic Sans MS';

  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: r'$ ', decimalDigits: 2);

  bool _isLoading = true;
  String? _error;
  List<ArrearsItem> _arrears = const [];

  @override
  void initState() {
    super.initState();
    _loadArrears();
  }

  Future<void> _loadArrears() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await FinanceService.instance.getArrearsReport();
      if (!mounted) return;

      setState(() {
        _arrears = data;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load arrears report: $error';
        _isLoading = false;
      });
    }
  }

  Future<void> _sendReminder(ArrearsItem item) async {
    final phone = _normalizedPhone(item.tenantPhone);
    if (phone == null) {
      _showSnackBar('Tenant phone number is missing.', isError: true);
      return;
    }

    final amount = _currencyFormat.format(item.balanceDue);
    final message =
        'Hi ${item.tenantName}, your rent balance for ${item.unitNumber} is $amount. Please settle via M-Pesa.';

    final uri = Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(message)}');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }

    _showSnackBar('Could not open WhatsApp for this contact.', isError: true);
  }

  String? _normalizedPhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return null;
    }

    if (digits.startsWith('0') && digits.length == 10) {
      return '254${digits.substring(1)}';
    }

    if (digits.startsWith('254')) {
      return digits;
    }

    return digits;
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isError ? Colors.red.shade700 : AppTheme.primaryColor,
        content: Text(
          message,
          style: const TextStyle(fontFamily: _fontFamily),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Debt Aging Report',
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
              : _arrears.isEmpty
                  ? const Center(
                      child: Text(
                        'No arrears found. Great work!',
                        style: TextStyle(fontFamily: _fontFamily, fontSize: 16),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadArrears,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _arrears.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = _arrears[index];
                          return Card(
                            color: AppTheme.surfaceColor,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.tenantName,
                                          style: const TextStyle(
                                            fontFamily: _fontFamily,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFACC15),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          _currencyFormat.format(item.balanceDue),
                                          style: const TextStyle(
                                            fontFamily: _fontFamily,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Unit: ${item.unitNumber}',
                                    style: const TextStyle(
                                      fontFamily: _fontFamily,
                                      color: Color(0xFFCBD5E1),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        _sendReminder(item);
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFFACC15),
                                        foregroundColor: Colors.black,
                                      ),
                                      icon: const Icon(LucideIcons.messageCircle),
                                      label: const Text(
                                        'Send Reminder',
                                        style: TextStyle(
                                          fontFamily: _fontFamily,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
