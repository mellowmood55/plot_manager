class PaymentRecord {
  final String id;
  final String unitId;
  final String? tenantId;
  final double amountPaid;
  final String? transactionRef;
  final String paymentMethod;
  final DateTime paymentDate;
  final double? waterReadingPrevious;
  final double? waterReadingCurrent;
  final double? utilityAmount;

  PaymentRecord({
    required this.id,
    required this.unitId,
    required this.tenantId,
    required this.amountPaid,
    required this.transactionRef,
    required this.paymentMethod,
    required this.paymentDate,
    this.waterReadingPrevious,
    this.waterReadingCurrent,
    this.utilityAmount,
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
      waterReadingPrevious: json['water_reading_previous'] == null
          ? null
          : (json['water_reading_previous'] is num
              ? (json['water_reading_previous'] as num).toDouble()
              : double.tryParse(json['water_reading_previous'].toString())),
      waterReadingCurrent: json['water_reading_current'] == null
          ? null
          : (json['water_reading_current'] is num
              ? (json['water_reading_current'] as num).toDouble()
              : double.tryParse(json['water_reading_current'].toString())),
      utilityAmount: json['utility_amount'] == null
          ? null
          : (json['utility_amount'] is num
              ? (json['utility_amount'] as num).toDouble()
              : double.tryParse(json['utility_amount'].toString())),
    );
  }
}
