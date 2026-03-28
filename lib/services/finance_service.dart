import '../core/supabase_config.dart';
import 'supabase_service.dart';

enum FinanceFilter {
  thisMonth,
  lastMonth,
  thisYear,
}

class FinanceTrendPoint {
  const FinanceTrendPoint({
    required this.month,
    required this.revenue,
    required this.expenses,
  });

  final DateTime month;
  final double revenue;
  final double expenses;
}

class RentCollectionSnapshot {
  const RentCollectionSnapshot({
    required this.collected,
    required this.pending,
  });

  final double collected;
  final double pending;
}

class FinanceService {
  FinanceService._();

  static final FinanceService instance = FinanceService._();

  Future<String?> _getCurrentOrganizationId() {
    return SupabaseService.instance.getCurrentOrganizationId();
  }

  Future<List<Map<String, dynamic>>> _fetchOrganizationUnits() async {
    final orgId = await _getCurrentOrganizationId();
    if (orgId == null || orgId.isEmpty) {
      return [];
    }

    final client = SupabaseConfig.getClient();

    final properties = await client
        .from('properties')
        .select('id')
        .eq('organization_id', orgId);

    if ((properties as List).isEmpty) {
      return [];
    }

    final propertyIds = properties
        .map<String>((row) => (row['id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toList();

    if (propertyIds.isEmpty) {
      return [];
    }

    final units = await client
        .from('units')
        .select('id, rent_amount, status, tenant_id')
        .inFilter('property_id', propertyIds);

    return (units as List)
        .map<Map<String, dynamic>>((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<List<String>> _fetchOrganizationUnitIds() async {
    final units = await _fetchOrganizationUnits();

    return units
        .map((row) => (row['id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toList();
  }

  double _sumNumericField(List<dynamic> rows, String field) {
    double total = 0;

    for (final row in rows) {
      final value = row[field];
      if (value is num) {
        total += value.toDouble();
      } else if (value != null) {
        total += double.tryParse(value.toString()) ?? 0;
      }
    }

    return total;
  }

  DateTime _monthStart(DateTime month) {
    return DateTime(month.year, month.month, 1);
  }

  DateTime _monthEndExclusive(DateTime month) {
    return DateTime(month.year, month.month + 1, 1);
  }

  String _dateOnly(DateTime value) {
    return value.toIso8601String().split('T').first;
  }

  Future<double> getMonthlyRevenue(DateTime month) async {
    final unitIds = await _fetchOrganizationUnitIds();
    if (unitIds.isEmpty) {
      return 0;
    }

    final client = SupabaseConfig.getClient();
    final start = _monthStart(month);
    final endExclusive = _monthEndExclusive(month);

    final rows = await client
        .from('payments')
        .select('amount_paid')
        .inFilter('unit_id', unitIds)
        .gte('payment_date', _dateOnly(start))
        .lt('payment_date', _dateOnly(endExclusive));

    return _sumNumericField(rows as List, 'amount_paid');
  }

  Future<double> getMonthlyExpenses(DateTime month) async {
    final unitIds = await _fetchOrganizationUnitIds();
    if (unitIds.isEmpty) {
      return 0;
    }

    final client = SupabaseConfig.getClient();
    final start = _monthStart(month).toUtc().toIso8601String();
    final endExclusive = _monthEndExclusive(month).toUtc().toIso8601String();

    final rows = await client
        .from('maintenance_requests')
        .select('actual_cost')
        .inFilter('unit_id', unitIds)
        .gte('resolved_at', start)
        .lt('resolved_at', endExclusive);

    return _sumNumericField(rows as List, 'actual_cost');
  }

  Future<List<FinanceTrendPoint>> getSixMonthTrend() async {
    final now = DateTime.now();
    final points = <FinanceTrendPoint>[];

    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final revenue = await getMonthlyRevenue(month);
      final expenses = await getMonthlyExpenses(month);

      points.add(
        FinanceTrendPoint(
          month: month,
          revenue: revenue,
          expenses: expenses,
        ),
      );
    }

    return points;
  }

  Future<double> _getRangeRevenue(FinanceFilter filter) async {
    final now = DateTime.now();

    switch (filter) {
      case FinanceFilter.thisMonth:
        return getMonthlyRevenue(now);
      case FinanceFilter.lastMonth:
        return getMonthlyRevenue(DateTime(now.year, now.month - 1, 1));
      case FinanceFilter.thisYear:
        double total = 0;
        for (int month = 1; month <= now.month; month++) {
          total += await getMonthlyRevenue(DateTime(now.year, month, 1));
        }
        return total;
    }
  }

  Future<double> _getExpectedRentForRange(FinanceFilter filter) async {
    final units = await _fetchOrganizationUnits();
    if (units.isEmpty) {
      return 0;
    }

    double monthlyRentDue = 0;

    for (final unit in units) {
      final status = (unit['status'] ?? '').toString().toLowerCase();
      final tenantId = unit['tenant_id']?.toString();
      final isOccupied = status == 'occupied' || (tenantId != null && tenantId.isNotEmpty);

      if (!isOccupied) {
        continue;
      }

      final rentValue = unit['rent_amount'];
      if (rentValue is num) {
        monthlyRentDue += rentValue.toDouble();
      } else if (rentValue != null) {
        monthlyRentDue += double.tryParse(rentValue.toString()) ?? 0;
      }
    }

    if (filter == FinanceFilter.thisYear) {
      final monthsElapsed = DateTime.now().month;
      return monthlyRentDue * monthsElapsed;
    }

    return monthlyRentDue;
  }

  Future<RentCollectionSnapshot> getRentCollectionSnapshot(FinanceFilter filter) async {
    final collected = await _getRangeRevenue(filter);
    final expected = await _getExpectedRentForRange(filter);
    final pending = ((expected - collected) < 0 ? 0.0 : (expected - collected)).toDouble();

    return RentCollectionSnapshot(
      collected: collected,
      pending: pending,
    );
  }
}
