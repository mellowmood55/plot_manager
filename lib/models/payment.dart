class PaymentRecord {
  final String id;
  final String unitId;
  final String? tenantId;
  final double amountPaid;
  final String? transactionRef;
  final String paymentMethod;
  final DateTime paymentDate;

  PaymentRecord({
    required this.id,
    required this.unitId,
    required this.tenantId,
    required this.amountPaid,
    required this.transactionRef,
    required this.paymentMethod,
    required this.paymentDate,
  });

  factory PaymentRecord.fromJson(Map<String, dynamic> json) {
    final amountRaw = json['amount_paid'];
    final amount = amountRaw is num ? amountRaw.toDouble() : double.tryParse(amountRaw.toString()) ?? 0;

    return PaymentRecord(
      id: json['id'].toString(),
      unitId: (json['unit_id'] ?? '').toString(),
      tenantId: json['tenant_id']?.toString(),
      amountPaid: amount,
      transactionRef: json['transaction_ref']?.toString(),
      paymentMethod: (json['payment_method'] ?? 'Unknown').toString(),
      paymentDate: DateTime.tryParse((json['payment_date'] ?? '').toString()) ?? DateTime.now(),
    );
  }
}
