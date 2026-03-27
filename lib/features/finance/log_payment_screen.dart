import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../services/payment_service.dart';

class LogPaymentScreen extends StatefulWidget {
  const LogPaymentScreen({
    required this.unitId,
    required this.tenantId,
    super.key,
  });

  final String unitId;
  final String? tenantId;

  @override
  State<LogPaymentScreen> createState() => _LogPaymentScreenState();
}

class _LogPaymentScreenState extends State<LogPaymentScreen> {
  final _mpesaSmsController = TextEditingController();
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  final List<String> _methods = const ['Cash', 'Mobile Money', 'Bank Transfer', 'Card'];

  DateTime _paymentDate = DateTime.now();
  String _selectedMethod = 'Cash';
  bool _isSaving = false;

  @override
  void dispose() {
    _mpesaSmsController.dispose();
    _amountController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  void _onMpesaSmsChanged(String text) {
    final parsed = PaymentService.parseMpesaSms(text);
    if (!parsed.hasMatch) {
      return;
    }

    if (parsed.amount != null) {
      _amountController.text = parsed.amount!.toStringAsFixed(2);
    }

    if (parsed.transactionCode != null && parsed.transactionCode!.isNotEmpty) {
      _referenceController.text = parsed.transactionCode!;
    }

    if (parsed.paymentDate != null) {
      if (!mounted) return;
      setState(() {
        _paymentDate = parsed.paymentDate!;
      });
    }
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (selected == null) {
      return;
    }

    setState(() {
      _paymentDate = selected;
    });
  }

  Future<void> _savePayment() async {
    final amount = double.tryParse(_amountController.text.trim());

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: const Text(
            'Enter a valid amount greater than 0.',
            style: TextStyle(fontFamily: AppTheme.appFontFamily),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await PaymentService.instance.logPayment(
        unitId: widget.unitId,
        tenantId: widget.tenantId,
        amountPaid: amount,
        transactionRef: _referenceController.text,
        paymentMethod: _selectedMethod,
        paymentDate: _paymentDate,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.primaryColor,
          content: Text(
            'Payment logged successfully.',
            style: TextStyle(fontFamily: AppTheme.appFontFamily),
          ),
        ),
      );

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(
            'Failed to log payment: $error',
            style: const TextStyle(fontFamily: AppTheme.appFontFamily),
          ),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
    }
  }

  String _dateLabel(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text(
          'Log Payment',
          style: TextStyle(fontFamily: AppTheme.appFontFamily),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SizedBox(
            width: screenWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _mpesaSmsController,
                  maxLines: 3,
                  onChanged: _onMpesaSmsChanged,
                  style: const TextStyle(fontFamily: AppTheme.appFontFamily),
                  decoration: InputDecoration(
                    labelText: 'Paste M-Pesa SMS here (Optional)',
                    labelStyle: const TextStyle(fontFamily: AppTheme.appFontFamily),
                    hintText: 'Paste the payment SMS to auto-fill amount and ref...',
                    hintStyle: const TextStyle(fontFamily: AppTheme.appFontFamily),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF64748B), width: 1.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF94A3B8), width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontFamily: AppTheme.appFontFamily),
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    hintText: 'Amount Paid',
                    prefixText: '\$ ',
                  ),
                ),
                const SizedBox(height: 14),
                InkWell(
                  onTap: _isSaving ? null : _pickDate,
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Payment Date',
                    ),
                    child: Text(
                      _dateLabel(_paymentDate),
                      style: const TextStyle(fontFamily: AppTheme.appFontFamily),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _referenceController,
                  style: const TextStyle(fontFamily: AppTheme.appFontFamily),
                  decoration: const InputDecoration(
                    labelText: 'Reference Code',
                    hintText: 'Transaction Ref (optional)',
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _selectedMethod,
                  dropdownColor: AppTheme.surfaceColor,
                  decoration: const InputDecoration(
                    labelText: 'Payment Method',
                  ),
                  style: const TextStyle(
                    fontFamily: AppTheme.appFontFamily,
                    color: Colors.white,
                  ),
                  items: _methods
                      .map(
                        (method) => DropdownMenuItem<String>(
                          value: method,
                          child: Text(
                            method,
                            style: const TextStyle(fontFamily: AppTheme.appFontFamily),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _isSaving
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() {
                            _selectedMethod = value;
                          });
                        },
                ),
                const SizedBox(height: 22),
                ElevatedButton(
                  onPressed: _isSaving ? null : _savePayment,
                  child: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Save Payment',
                          style: TextStyle(fontFamily: AppTheme.appFontFamily),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
