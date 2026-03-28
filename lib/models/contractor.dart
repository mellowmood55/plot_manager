class Contractor {
  final String id;
  final String name;
  final String phone;
  final String specialty;
  final String? locationScope;

  Contractor({
    required this.id,
    required this.name,
    required this.phone,
    required this.specialty,
    this.locationScope,
  });

  factory Contractor.fromMap(Map<String, dynamic> map) {
    return Contractor(
      id: map['id'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String,
      specialty: map['specialty'] as String,
      locationScope: map['location_scope'] as String?,
    );
  }

  String get displayLabel => '$name ($specialty)';

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
