class Unit {
  final String id;
  final String propertyId;
  final String unitNumber;
  final String status;
  final String? tenantId;
  final String? unitType;
  final double rentAmount;

  Unit({
    required this.id,
    required this.propertyId,
    required this.unitNumber,
    required this.status,
    this.tenantId,
    this.unitType,
    this.rentAmount = 0,
  });

  String get name => unitNumber;

  bool get isOccupied => status.toLowerCase() == 'occupied' || tenantId != null;

  factory Unit.fromJson(Map<String, dynamic> json) {
    final number = (json['unit_number'] ?? json['name'] ?? 'Unit').toString();

    return Unit(
      id: json['id'].toString(),
      propertyId: (json['property_id'] ?? '').toString(),
      unitNumber: number,
      status: (json['status'] ?? 'vacant').toString(),
      tenantId: json['tenant_id']?.toString(),
      unitType: json['unit_type']?.toString(),
      rentAmount: json['rent_amount'] is num
          ? (json['rent_amount'] as num).toDouble()
          : double.tryParse((json['rent_amount'] ?? '0').toString()) ?? 0,
    );
  }
}
