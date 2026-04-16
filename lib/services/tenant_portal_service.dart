import '../core/supabase_config.dart';
import '../models/payment.dart';
import '../models/user_profile.dart';
import '../models/user_role.dart';
import 'payment_service.dart';

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
    final client = SupabaseConfig.getClient();
    final user = client.auth.currentUser;
    if (user == null) {
      throw Exception('You must be logged in to view the tenant dashboard.');
    }

    final profileRow = await client
        .from('profiles')
        .select('id, full_name, role, organization_id, unit_id')
        .eq('id', user.id)
        .maybeSingle();

    if (profileRow == null) {
      throw Exception('No profile found for this account.');
    }

    final profile = UserProfile.fromJson(Map<String, dynamic>.from(profileRow));
    if (profile.role != UserRole.tenant) {
      throw Exception('This dashboard is available only to tenant accounts.');
    }

    final unitId = profile.unitId;
    if (unitId == null || unitId.isEmpty) {
      throw Exception('Tenant profile is not linked to a unit.');
    }

    final unitRow = await client
        .from('units')
        .select('id, unit_number, rent_amount, balance_due')
        .eq('id', unitId)
        .maybeSingle();

    if (unitRow == null) {
      throw Exception('Tenant unit could not be found.');
    }

    final unitNumber = (unitRow['unit_number'] ?? 'Unit').toString();
    final fullName = profile.fullName;
    final directBalanceDue = unitRow['balance_due'] is num
        ? (unitRow['balance_due'] as num).toDouble()
        : double.tryParse((unitRow['balance_due'] ?? 0).toString()) ?? 0;

    final rentAmount = unitRow['rent_amount'] is num
        ? (unitRow['rent_amount'] as num).toDouble()
        : double.tryParse((unitRow['rent_amount'] ?? 0).toString()) ?? 0;
    final currentMonthPaid = await PaymentService.instance.fetchTotalPaidThisMonth(unitId);
    final balanceDue = directBalanceDue > 0 ? directBalanceDue : (rentAmount - currentMonthPaid).clamp(0, double.infinity).toDouble();

    final lastPayments = await PaymentService.instance.fetchPaymentHistoryByUnit(unitId);

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
    return PaymentService.instance.fetchPaymentHistoryByUnit(unitId);
  }
}
