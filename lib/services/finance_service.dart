import '../core/supabase_config.dart';
import 'supabase_service.dart';

enum FinanceRange {
  thisMonth,
  lastMonth,
  thisYear,
}

class RentCollectionSnapshot {
  const RentCollectionSnapshot({
    required this.collected,
    required this.pending,
  });

  final double collected;
  final double pending;
}

class MonthlyFinancePoint {
  const MonthlyFinancePoint({
    required this.month,
    required this.revenue,
    required this.expenses,
  });

  final DateTime month;
  final double revenue;
  final double expenses;
}

class _DateBounds {
  const _DateBounds(this.startInclusive, this.endExclusive);

  final DateTime startInclusive;
  final DateTime endExclusive;
}

class FinanceService {
  FinanceService._();

  static final FinanceService instance = FinanceService._();

  Future<double> getMonthlyRevenue(DateTime month) async {
    final bounds = _monthBounds(month);
    return _sumRevenueInRange(bounds.startInclusive, bounds.endExclusive);
  }

  Future<double> getMonthlyExpenses(DateTime month) async {
    final bounds = _monthBounds(month);
    return _sumExpensesInRange(bounds.startInclusive, bounds.endExclusive);
  }

  Future<List<MonthlyFinancePoint>> getSixMonthTrend() async {
    final now = DateTime.now();
    final startMonth = DateTime(now.year, now.month - 5, 1);
    final points = <MonthlyFinancePoint>[];

    for (int i = 0; i < 6; i++) {
      final month = DateTime(startMonth.year, startMonth.month + i, 1);
      final revenue = await getMonthlyRevenue(month);
      final expenses = await getMonthlyExpenses(month);

      points.add(
        MonthlyFinancePoint(
          month: month,
          revenue: revenue,
          expenses: expenses,
        ),
      );
    }

    return points;
  }

  Future<double> getRevenueForRange(FinanceRange range) async {
    final bounds = _rangeBounds(range);
    return _sumRevenueInRange(bounds.startInclusive, bounds.endExclusive);
  }

  Future<double> getExpensesForRange(FinanceRange range) async {
    final bounds = _rangeBounds(range);
    return _sumExpensesInRange(bounds.startInclusive, bounds.endExclusive);
  }

  Future<RentCollectionSnapshot> getRentCollectionSnapshot(FinanceRange range) async {
    final unitRows = await _fetchOrganizationUnits();
    if (unitRows.isEmpty) {
      return const RentCollectionSnapshot(collected: 0, pending: 0);
    }

    final occupiedUnits = unitRows.where((row) {
      final status = (row['status'] ?? '').toString().toLowerCase();
      final tenantId = row['tenant_id'];
      return status == 'occupied' || tenantId != null;
    }).toList();

    final monthlyRent = _sumRows(occupiedUnits, 'rent_amount');
    final bounds = _rangeBounds(range);
    final collected = await _sumRevenueInRange(bounds.startInclusive, bounds.endExclusive);

    int monthCount = 1;
    if (range == FinanceRange.thisYear) {
      monthCount = 12;
    }

    final expected = monthlyRent * monthCount;
    final pending = (expected - collected).clamp(0, double.infinity).toDouble();

    return RentCollectionSnapshot(collected: collected, pending: pending);
  }

  Future<List<String>> _fetchOrganizationUnitIds() async {
    final units = await _fetchOrganizationUnits();
    return units
        .map((row) => row['id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList();
  }

  Future<List<dynamic>> _fetchOrganizationUnits() async {
    final orgId = await SupabaseService.instance.getCurrentOrganizationId();
    if (orgId == null) {
      return const [];
    }

    final client = SupabaseConfig.getClient();

    final propertyRows = await client
        .from('properties')
        .select('id')
        .eq('organization_id', orgId);

    final propertyIds = propertyRows
        .map((row) => row['id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList();

    if (propertyIds.isEmpty) {
      return const [];
    }

    return client
        .from('units')
        .select('id, rent_amount, status, tenant_id')
        .inFilter('property_id', propertyIds);
  }

  Future<double> _sumRevenueInRange(DateTime startInclusive, DateTime endExclusive) async {
    final unitIds = await _fetchOrganizationUnitIds();
    if (unitIds.isEmpty) {
      return 0;
    }

    final client = SupabaseConfig.getClient();
    final startDate = _dateOnly(startInclusive);
    final endDate = _dateOnly(endExclusive.subtract(const Duration(days: 1)));

    final rows = await client
        .from('payments')
        .select('amount_paid')
        .inFilter('unit_id', unitIds)
        .gte('payment_date', startDate)
        .lte('payment_date', endDate);

    return _sumRows(rows, 'amount_paid');
  }

  Future<double> _sumExpensesInRange(DateTime startInclusive, DateTime endExclusive) async {
    final unitIds = await _fetchOrganizationUnitIds();
    if (unitIds.isEmpty) {
      return 0;
    }

    final client = SupabaseConfig.getClient();

    final rows = await client
        .from('maintenance_requests')
        .select('actual_cost, resolved_at, created_at')
        .inFilter('unit_id', unitIds)
        .not('actual_cost', 'is', null);

    double total = 0;
    for (final row in rows) {
      final rawTimestamp = row['resolved_at'] ?? row['created_at'];
      if (rawTimestamp == null) {
        continue;
      }

      final timestamp = DateTime.tryParse(rawTimestamp.toString());
      if (timestamp == null) {
        continue;
      }

      final inRange = !timestamp.isBefore(startInclusive) && timestamp.isBefore(endExclusive);
      if (!inRange) {
        continue;
      }

      final rawCost = row['actual_cost'];
      total += rawCost is num ? rawCost.toDouble() : double.tryParse(rawCost.toString()) ?? 0;
    }

    return total;
  }

  _DateBounds _monthBounds(DateTime month) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    return _DateBounds(start, end);
  }

  _DateBounds _rangeBounds(FinanceRange range) {
    final now = DateTime.now();

    switch (range) {
      case FinanceRange.thisMonth:
        return _DateBounds(DateTime(now.year, now.month, 1), DateTime(now.year, now.month + 1, 1));
      case FinanceRange.lastMonth:
        return _DateBounds(DateTime(now.year, now.month - 1, 1), DateTime(now.year, now.month, 1));
      case FinanceRange.thisYear:
        return _DateBounds(DateTime(now.year, 1, 1), DateTime(now.year + 1, 1, 1));
    }
  }

  String _dateOnly(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  double _sumRows(List<dynamic> rows, String key) {
    double total = 0;
    for (final row in rows) {
      final value = row[key];
      total += value is num ? value.toDouble() : double.tryParse(value.toString()) ?? 0;
    }
    return total;
  }
}
