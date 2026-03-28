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

class ArrearsItem {
  const ArrearsItem({
    required this.unitId,
    required this.unitNumber,
    required this.tenantName,
    required this.tenantPhone,
    required this.balanceDue,
  });

  final String unitId;
  final String unitNumber;
  final String tenantName;
  final String? tenantPhone;
  final double balanceDue;
}

class PotentialIncomeSnapshot {
  const PotentialIncomeSnapshot({
    required this.totalUnits,
    required this.occupiedUnits,
    required this.monthlyRentTemplate,
    required this.potentialIncome,
    required this.actualRevenue,
    required this.potentialLoss,
    required this.occupancyRate,
  });

  final int totalUnits;
  final int occupiedUnits;
  final double monthlyRentTemplate;
  final double potentialIncome;
  final double actualRevenue;
  final double potentialLoss;
  final double occupancyRate;
}

class _DateBounds {
  const _DateBounds(this.startInclusive, this.endExclusive);

  final DateTime startInclusive;
  final DateTime endExclusive;
}

class FinanceService {
  FinanceService._();

  static const double _mriTaxRate = 0.10;

  static final FinanceService instance = FinanceService._();

  Future<double> getMonthlyRevenue(DateTime month) async {
    final bounds = _monthBounds(month);
    return _sumRevenueInRange(bounds.startInclusive, bounds.endExclusive);
  }

  Future<double> getMonthlyExpenses(DateTime month) async {
    final bounds = _monthBounds(month);
    return _sumExpensesInRange(bounds.startInclusive, bounds.endExclusive);
  }

  Future<double> getMonthlyMriTax(DateTime month) async {
    final monthlyRevenue = await getMonthlyRevenue(month);
    return monthlyRevenue * _mriTaxRate;
  }

  Future<double> getCurrentMonthMriTax() async {
    return getMonthlyMriTax(DateTime.now());
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

  Future<PotentialIncomeSnapshot> getPotentialIncomeSnapshot({
    FinanceRange range = FinanceRange.thisMonth,
  }) async {
    final unitRows = await _fetchOrganizationUnits();
    if (unitRows.isEmpty) {
      return const PotentialIncomeSnapshot(
        totalUnits: 0,
        occupiedUnits: 0,
        monthlyRentTemplate: 0,
        potentialIncome: 0,
        actualRevenue: 0,
        potentialLoss: 0,
        occupancyRate: 0,
      );
    }

    final totalUnits = unitRows.length;
    final occupiedUnits = unitRows.where((row) {
      final status = (row['status'] ?? '').toString().toLowerCase();
      final tenantId = row['tenant_id'];
      return status == 'occupied' || tenantId != null;
    }).length;

    final totalMonthlyRent = _sumRows(unitRows, 'rent_amount');
    final monthlyTemplate = totalUnits == 0 ? 0.0 : (totalMonthlyRent / totalUnits).toDouble();

    final monthCount = range == FinanceRange.thisYear ? 12.0 : 1.0;
    final potentialIncome = (totalUnits * monthlyTemplate) * monthCount;
    final actualRevenue = await getRevenueForRange(range);
    final potentialLoss = (potentialIncome - actualRevenue).clamp(0, double.infinity).toDouble();
    final occupancyRate = totalUnits == 0 ? 0.0 : (occupiedUnits / totalUnits).toDouble();

    return PotentialIncomeSnapshot(
      totalUnits: totalUnits,
      occupiedUnits: occupiedUnits,
      monthlyRentTemplate: monthlyTemplate,
      potentialIncome: potentialIncome,
      actualRevenue: actualRevenue,
      potentialLoss: potentialLoss,
      occupancyRate: occupancyRate,
    );
  }

  Future<List<ArrearsItem>> getArrearsReport() async {
    final units = await _fetchOrganizationUnitsDetailed();
    if (units.isEmpty) {
      return const [];
    }

    final now = DateTime.now();
    final monthBounds = _monthBounds(now);
    final unitIds = units
        .map((unit) => unit['id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList();

    final paidMap = await _fetchRevenueByUnitInRange(
      unitIds,
      monthBounds.startInclusive,
      monthBounds.endExclusive,
    );

    final arrears = <ArrearsItem>[];

    for (final unit in units) {
      final status = (unit['status'] ?? '').toString().toLowerCase();
      if (status != 'occupied') {
        continue;
      }

      final unitId = (unit['id'] ?? '').toString();
      if (unitId.isEmpty) {
        continue;
      }

      final unitNumber = (unit['unit_number'] ?? 'Unit').toString();
      final rentAmount = _parseDouble(unit['rent_amount']);
      final directBalanceDue = _parseDouble(unit['balance_due']);
      final paidThisMonth = paidMap[unitId] ?? 0;

      final computedBalance = (rentAmount - paidThisMonth).clamp(0, double.infinity).toDouble();
      final effectiveBalance = directBalanceDue > 0 ? directBalanceDue : computedBalance;

      if (effectiveBalance <= 0) {
        continue;
      }

      final tenantInfo = _extractTenant(unit['tenants']);
      arrears.add(
        ArrearsItem(
          unitId: unitId,
          unitNumber: unitNumber,
          tenantName: tenantInfo['full_name'] ?? 'Tenant',
          tenantPhone: tenantInfo['phone_number'],
          balanceDue: effectiveBalance,
        ),
      );
    }

    arrears.sort((a, b) => b.balanceDue.compareTo(a.balanceDue));
    return arrears;
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

  Future<List<dynamic>> _fetchOrganizationUnitsDetailed() async {
    final orgId = await SupabaseService.instance.getCurrentOrganizationId();
    if (orgId == null) {
      return const [];
    }

    final client = SupabaseConfig.getClient();
    final propertyRows = await client.from('properties').select('id').eq('organization_id', orgId);

    final propertyIds = propertyRows
        .map((row) => row['id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList();

    if (propertyIds.isEmpty) {
      return const [];
    }

    try {
      return await client
          .from('units')
          .select('id, unit_number, rent_amount, status, tenant_id, balance_due, tenants(full_name, phone_number)')
          .inFilter('property_id', propertyIds);
    } catch (_) {
      return client
          .from('units')
          .select('id, unit_number, rent_amount, status, tenant_id, tenants(full_name, phone_number)')
          .inFilter('property_id', propertyIds);
    }
  }

  Future<Map<String, double>> _fetchRevenueByUnitInRange(
    List<String> unitIds,
    DateTime startInclusive,
    DateTime endExclusive,
  ) async {
    if (unitIds.isEmpty) {
      return const {};
    }

    final client = SupabaseConfig.getClient();
    final startDate = _dateOnly(startInclusive);
    final endDate = _dateOnly(endExclusive.subtract(const Duration(days: 1)));

    final rows = await client
        .from('payments')
        .select('unit_id, amount_paid')
        .inFilter('unit_id', unitIds)
        .gte('payment_date', startDate)
        .lte('payment_date', endDate);

    final totals = <String, double>{};

    for (final row in rows) {
      final unitId = (row['unit_id'] ?? '').toString();
      if (unitId.isEmpty) {
        continue;
      }
      final amount = _parseDouble(row['amount_paid']);
      totals[unitId] = (totals[unitId] ?? 0) + amount;
    }

    return totals;
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

  double _parseDouble(dynamic value) {
    if (value == null) {
      return 0;
    }
    return value is num ? value.toDouble() : double.tryParse(value.toString()) ?? 0;
  }

  Map<String, String?> _extractTenant(dynamic tenantsRaw) {
    if (tenantsRaw is Map<String, dynamic>) {
      return {
        'full_name': tenantsRaw['full_name']?.toString(),
        'phone_number': tenantsRaw['phone_number']?.toString(),
      };
    }

    if (tenantsRaw is List && tenantsRaw.isNotEmpty) {
      final first = tenantsRaw.first;
      if (first is Map<String, dynamic>) {
        return {
          'full_name': first['full_name']?.toString(),
          'phone_number': first['phone_number']?.toString(),
        };
      }
    }

    return {
      'full_name': null,
      'phone_number': null,
    };
  }
}
