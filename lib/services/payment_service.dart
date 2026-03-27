import '../core/supabase_config.dart';
import '../models/payment.dart';

class MpesaSmsParseResult {
  const MpesaSmsParseResult({
    this.transactionCode,
    this.amount,
    this.paymentDate,
  });

  final String? transactionCode;
  final double? amount;
  final DateTime? paymentDate;

  bool get hasMatch => transactionCode != null || amount != null || paymentDate != null;
}

class PaymentService {
  PaymentService._();

  static final PaymentService instance = PaymentService._();

  static MpesaSmsParseResult parseMpesaSms(String text) {
    final normalizedText = text.trim();
    if (normalizedText.isEmpty) {
      return const MpesaSmsParseResult();
    }

    final txMatch = RegExp(r'\b([A-Z0-9]{10})\b', caseSensitive: false).firstMatch(normalizedText);
    final amountMatch = RegExp(r'Ksh\s*([0-9,]+(?:\.[0-9]+)?)\.', caseSensitive: false)
        .firstMatch(normalizedText);
    final dateMatch = RegExp(r'\b(\d{1,2}/\d{1,2}/\d{2,4})\b').firstMatch(normalizedText);

    double? amount;
    if (amountMatch != null) {
      final rawAmount = amountMatch.group(1)?.replaceAll(',', '');
      amount = rawAmount == null ? null : double.tryParse(rawAmount);
    }

    DateTime? paymentDate;
    if (dateMatch != null) {
      final rawDate = dateMatch.group(1)!;
      final parts = rawDate.split('/');
      if (parts.length == 3) {
        final day = int.tryParse(parts[0]);
        final month = int.tryParse(parts[1]);
        final yearRaw = int.tryParse(parts[2]);

        if (day != null && month != null && yearRaw != null) {
          final year = yearRaw < 100 ? 2000 + yearRaw : yearRaw;
          paymentDate = DateTime.tryParse(
            '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}',
          );
        }
      }
    }

    return MpesaSmsParseResult(
      transactionCode: txMatch?.group(1)?.toUpperCase(),
      amount: amount,
      paymentDate: paymentDate,
    );
  }

  Future<void> logPayment({
    required String unitId,
    required String? tenantId,
    required double amountPaid,
    required String transactionRef,
    required String paymentMethod,
    required DateTime paymentDate,
  }) async {
    final client = SupabaseConfig.getClient();

    await client.from('payments').insert({
      'unit_id': unitId,
      'tenant_id': tenantId,
      'amount_paid': amountPaid,
      'transaction_ref': transactionRef.trim().isEmpty ? null : transactionRef.trim(),
      'payment_method': paymentMethod,
      'payment_date': paymentDate.toIso8601String().split('T').first,
    });
  }

  Future<List<PaymentRecord>> fetchPaymentHistoryByUnit(String unitId) async {
    final client = SupabaseConfig.getClient();

    final rows = await client
        .from('payments')
        .select('id, unit_id, tenant_id, amount_paid, transaction_ref, payment_method, payment_date')
        .eq('unit_id', unitId)
        .order('payment_date', ascending: false)
        .order('created_at', ascending: false);

    return rows.map<PaymentRecord>((row) => PaymentRecord.fromJson(row)).toList();
  }

  Future<double> fetchTotalPaidThisMonth(String unitId) async {
    final client = SupabaseConfig.getClient();
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1).toIso8601String().split('T').first;
    final endOfMonth = DateTime(now.year, now.month + 1, 0).toIso8601String().split('T').first;

    final rows = await client
        .from('payments')
        .select('amount_paid')
        .eq('unit_id', unitId)
        .gte('payment_date', startOfMonth)
        .lte('payment_date', endOfMonth);

    double total = 0;
    for (final row in rows) {
      final raw = row['amount_paid'];
      total += raw is num ? raw.toDouble() : double.tryParse(raw.toString()) ?? 0;
    }

    return total;
  }
}
