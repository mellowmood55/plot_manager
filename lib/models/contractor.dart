class Contractor {
  final String id;
  final String name;
  final String phone;
  final String specialty;

  Contractor({
    required this.id,
    required this.name,
    required this.phone,
    required this.specialty,
  });

  factory Contractor.fromMap(Map<String, dynamic> map) {
    return Contractor(
      id: map['id'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String,
      specialty: map['specialty'] as String,
    );
  }

  String get displayLabel => '$name ($specialty)';
}
