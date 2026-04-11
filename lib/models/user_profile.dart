import 'user_role.dart';

class UserProfile {
  const UserProfile({
    required this.id,
    required this.fullName,
    required this.role,
    this.organizationId,
    this.unitId,
  });

  final String id;
  final String fullName;
  final UserRole role;
  final String? organizationId;
  final String? unitId;

  bool get isTenant => role == UserRole.tenant;
  bool get isLandlord => role == UserRole.landlord;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: (json['id'] ?? '').toString(),
      fullName: (json['full_name'] ?? 'User').toString(),
      role: UserRole.fromString(json['role']?.toString()),
      organizationId: json['organization_id']?.toString(),
      unitId: json['unit_id']?.toString(),
    );
  }
}
