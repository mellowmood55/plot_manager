class Contractor {
  final String id;
  final String name;
  final String phone;
  final String specialty;
  final String? organizationId;
  final double reliabilityScore;
  final String? locationScope;

  Contractor({
    required this.id,
    required this.name,
    required this.phone,
    required this.specialty,
    this.organizationId,
    this.reliabilityScore = 0,
    this.locationScope,
  });

  factory Contractor.fromMap(Map<String, dynamic> map) {
    return Contractor(
      id: map['id'].toString(),
      name: (map['name'] ?? 'Unknown Contractor').toString(),
      phone: (map['phone'] ?? '').toString(),
      specialty: (map['specialty'] ?? 'General Handyman').toString(),
      organizationId: map['organization_id']?.toString(),
      reliabilityScore: map['reliability_score'] is num
          ? (map['reliability_score'] as num).toDouble()
          : double.tryParse((map['reliability_score'] ?? '0').toString()) ?? 0,
      locationScope: map['location_scope'] as String?,
    );
  }

  String get displayLabel => '$name ($specialty)';

  String get reliabilityLabel => reliabilityScore.toStringAsFixed(1);

  List<String> get specialties {
    final tokens = specialty
        .split(RegExp(r'[,/;|]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (tokens.isEmpty) {
      return const ['General Handyman'];
    }

    return tokens;
  }

  bool matchesCategory(String category) {
    final normalizedCategory = category.trim().toLowerCase();
    if (normalizedCategory.isEmpty || normalizedCategory == 'general') {
      return true;
    }

    return specialties.any(
      (role) => role.toLowerCase().contains(normalizedCategory),
    );
  }
}
