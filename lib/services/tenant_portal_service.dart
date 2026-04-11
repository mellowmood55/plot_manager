import '../core/backend_api.dart';
import '../models/payment.dart';
import '../models/user_profile.dart';
import '../models/user_role.dart';

class TenantDashboardSnapshot {
  const TenantDashboardSnapshot({
    required this.profile,
    required this.displayName,
    required this.unitId,
    required this.unitNumber,
    required this.balanceDue,
    required this.lastPayments,
  });

  final UserProfile profile;
  final String displayName;
  final String unitId;
  final String unitNumber;
  final double balanceDue;
  final List<PaymentRecord> lastPayments;
}

class TenantPortalService {
  TenantPortalService._();

  static final TenantPortalService instance = TenantPortalService._();

  Future<TenantDashboardSnapshot> fetchTenantDashboardSnapshot() async {
    final response = await BackendApi.instance.getJson('/v1/tenant/dashboard');
    final responseMap = Map<String, dynamic>.from(response as Map);

    final profileJson = responseMap['profile'];
    if (profileJson is! Map) {
      throw Exception('No profile found for this account.');
    }

    final profile = UserProfile.fromJson(Map<String, dynamic>.from(profileJson));
    if (profile.role != UserRole.tenant) {
      throw Exception('This dashboard is available only to tenant accounts.');
    }

    final unitId = (responseMap['unit_id'] ?? profile.unitId)?.toString();
    if (unitId == null || unitId.isEmpty) {
      throw Exception('Tenant profile is not linked to a unit.');
    }

    final balanceDue = responseMap['balance_due'] is num
        ? (responseMap['balance_due'] as num).toDouble()
        : double.tryParse((responseMap['balance_due'] ?? 0).toString()) ?? 0;

    final unitNumber = (responseMap['unit_number'] ?? 'Unit').toString();
    final fullName = (responseMap['display_name'] ?? profile.fullName).toString();

    final lastPayments = (responseMap['last_payments'] as List<dynamic>? ?? const [])
        .map<PaymentRecord>((row) => PaymentRecord.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();

    return TenantDashboardSnapshot(
      profile: profile,
      displayName: fullName,
      unitId: unitId,
      unitNumber: unitNumber,
      balanceDue: balanceDue,
      lastPayments: lastPayments,
    );
  }

  Future<List<PaymentRecord>> fetchMyReceipts(String unitId) {
    return BackendApi.instance.getJson('/v1/tenant/receipts').then((response) {
      final rows = response is List
          ? response
          : (Map<String, dynamic>.from(response as Map))['rows'] as List<dynamic>? ?? const [];

      return rows
          .map<PaymentRecord>((row) => PaymentRecord.fromJson(Map<String, dynamic>.from(row as Map)))
          .toList();
    });
  }
}
