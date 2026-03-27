class Property {
  final String id;
  final String organizationId;
  final String name;
  final String? location;
  final String? propertyType;

  Property({
    required this.id,
    required this.organizationId,
    required this.name,
    this.location,
    this.propertyType,
  });

  factory Property.fromJson(Map<String, dynamic> json) {
    return Property(
      id: json['id'].toString(),
      organizationId: (json['organization_id'] ?? '').toString(),
      name: (json['name'] ?? 'Unnamed Plot').toString(),
      location: json['location']?.toString(),
      propertyType: json['property_type']?.toString(),
    );
  }
}
