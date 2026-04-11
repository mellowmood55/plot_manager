enum UserRole {
  landlord,
  tenant;

  static UserRole fromString(String? value) {
    switch ((value ?? '').toLowerCase()) {
      case 'tenant':
        return UserRole.tenant;
      case 'landlord':
      default:
        return UserRole.landlord;
    }
  }

  String get value {
    switch (this) {
      case UserRole.landlord:
        return 'landlord';
      case UserRole.tenant:
        return 'tenant';
    }
  }
}