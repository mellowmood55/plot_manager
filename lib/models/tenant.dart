class Tenant {
  final String id;
  final String name;
  final String phoneNumber;
  final String nationalId;
  final int occupants;

  Tenant({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.nationalId,
    required this.occupants,
  });

  String get phone => phoneNumber;

  factory Tenant.fromJson(Map<String, dynamic> json) {
    final occupantsRaw = json['occupants_count'] ?? json['occupants'] ?? 1;

    return Tenant(
      id: json['id'].toString(),
      name: (json['full_name'] ?? json['name'] ?? 'Unknown Tenant').toString(),
      phoneNumber: (json['phone_number'] ?? json['phone'] ?? 'N/A').toString(),
      nationalId: (json['national_id'] ?? 'N/A').toString(),
      occupants: occupantsRaw is int ? occupantsRaw : int.tryParse(occupantsRaw.toString()) ?? 1,
    );
  }
}
