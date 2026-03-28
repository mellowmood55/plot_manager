import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme.dart';
import '../../../services/finance_service.dart';
import 'arrears_report_screen.dart';

class FinanceDashboardScreen extends StatefulWidget {
  const FinanceDashboardScreen({super.key});

  @override
  State<FinanceDashboardScreen> createState() => _FinanceDashboardScreenState();
}

class _FinanceDashboardScreenState extends State<FinanceDashboardScreen> {
  static const String _fontFamily = 'Comic Sans MS';

  final FinanceService _financeService = FinanceService.instance;
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: r'$ ', decimalDigits: 2);

  FinanceRange _selectedRange = FinanceRange.thisMonth;

  bool _isLoading = true;
  String? _error;

  double _revenue = 0;
  double _expenses = 0;
  double _netProfit = 0;
  double _taxLiability = 0;

  double _rentCollected = 0;
  double _pendingRent = 0;
  PotentialIncomeSnapshot _potentialIncome = const PotentialIncomeSnapshot(
    totalUnits: 0,
    occupiedUnits: 0,
    monthlyRentTemplate: 0,
    potentialIncome: 0,
    actualRevenue: 0,
    potentialLoss: 0,
    occupancyRate: 0,
  );

  List<MonthlyFinancePoint> _trend = const [];

  @override
  void initState() {
    super.initState();
    _loadFinanceData();
  }

  Future<void> _loadFinanceData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final revenue = await _financeService.getRevenueForRange(_selectedRange);
      final expenses = await _financeService.getExpensesForRange(_selectedRange);
      final snapshot = await _financeService.getRentCollectionSnapshot(_selectedRange);
      final trend = await _financeService.getSixMonthTrend();
        final taxLiability = await _financeService.getCurrentMonthMriTax();
        final potentialIncome =
          await _financeService.getPotentialIncomeSnapshot(range: _selectedRange);

      if (!mounted) return;

      setState(() {
        _revenue = revenue;
        _expenses = expenses;
        _netProfit = revenue - expenses;
        _taxLiability = taxLiability;
        _rentCollected = snapshot.collected;
        _pendingRent = snapshot.pending;
        _potentialIncome = potentialIncome;
        _trend = trend;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _error = 'Failed to load finance dashboard: $error';
      });
    }
  }

  Future<void> _onRangeChanged(FinanceRange? value) async {
    if (value == null) {
      return;
    }

    if (!mounted) return;

    setState(() {
      _selectedRange = value;
    });

    await _loadFinanceData();
  }

  String _rangeLabel(FinanceRange range) {
    switch (range) {
      case FinanceRange.thisMonth:
        return 'This Month';
      case FinanceRange.lastMonth:
        return 'Last Month';
      case FinanceRange.thisYear:
        return 'This Year';
    }
  }

  Widget _buildNetProfitCard() {
    final bool isPositive = _netProfit >= 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: isPositive
              ? const [Color(0xFF0F766E), Color(0xFF134E4A)]
              : const [Color(0xFF9A3412), Color(0xFF7C2D12)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Net Profit',
            style: TextStyle(
              fontFamily: _fontFamily,
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _currencyFormat.format(_netProfit),
            style: const TextStyle(
              fontFamily: _fontFamily,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _rangeLabel(_selectedRange),
            style: const TextStyle(
              fontFamily: _fontFamily,
              fontSize: 14,
              color: Color(0xFFE2E8F0),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              _miniMetricPill(
                label: 'Revenue',
                value: _currencyFormat.format(_revenue),
                color: const Color(0xFF14B8A6),
              ),
              _miniMetricPill(
                label: 'Expenses',
                value: _currencyFormat.format(_expenses),
                color: const Color(0xFFFB923C),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTaxLiabilityCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFACC15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.alertTriangle, color: Colors.black),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tax Liability (KRA MRI 10%)',
                  style: TextStyle(
                    fontFamily: _fontFamily,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _currencyFormat.format(_taxLiability),
                  style: const TextStyle(
                    fontFamily: _fontFamily,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPotentialIncomeCard() {
    final occupancyPercent = (_potentialIncome.occupancyRate * 100).clamp(0, 100).toDouble();

    return Card(
      color: AppTheme.surfaceColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Potential Income',
              style: TextStyle(
                fontFamily: _fontFamily,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Potential: ${_currencyFormat.format(_potentialIncome.potentialIncome)}',
              style: const TextStyle(fontFamily: _fontFamily),
            ),
            const SizedBox(height: 4),
            Text(
              'Actual Revenue: ${_currencyFormat.format(_potentialIncome.actualRevenue)}',
              style: const TextStyle(fontFamily: _fontFamily),
            ),
            const SizedBox(height: 4),
            Text(
              'Income Gap: ${_currencyFormat.format(_potentialIncome.potentialLoss)}',
              style: const TextStyle(
                fontFamily: _fontFamily,
                color: Color(0xFFFACC15),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: _potentialIncome.occupancyRate,
                minHeight: 10,
                backgroundColor: const Color(0xFF334155),
                color: const Color(0xFF0D9488),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Current Occupancy: ${occupancyPercent.toStringAsFixed(0)}%',
              style: const TextStyle(
                fontFamily: _fontFamily,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniMetricPill({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$label: $value',
            style: const TextStyle(
              fontFamily: _fontFamily,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChartCard() {
    final total = _rentCollected + _pendingRent;
    final hasPieData = total > 0;

    return Card(
      color: AppTheme.surfaceColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Rent Overview',
              style: TextStyle(
                fontFamily: _fontFamily,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final chartSize = constraints.maxWidth < 360 ? 170.0 : 220.0;

                return Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: chartSize,
                      height: chartSize,
                      child: hasPieData
                          ? PieChart(
                              PieChartData(
                                centerSpaceRadius: chartSize * 0.25,
                                sectionsSpace: 3,
                                sections: [
                                  PieChartSectionData(
                                    color: const Color(0xFF0D9488),
                                    value: _rentCollected,
                                    title:
                                        '${((_rentCollected / total) * 100).toStringAsFixed(1)}%',
                                    titleStyle: const TextStyle(
                                      fontFamily: _fontFamily,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  PieChartSectionData(
                                    color: const Color(0xFFF97316),
                                    value: _pendingRent,
                                    title: '${((_pendingRent / total) * 100).toStringAsFixed(1)}%',
                                    titleStyle: const TextStyle(
                                      fontFamily: _fontFamily,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF334155),
                                  width: 2,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: const Text(
                                'No rent\ndata',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: _fontFamily,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ),
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 210, maxWidth: 280),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLegendLine(
                            color: const Color(0xFF0D9488),
                            label: 'Rent Collected',
                            value: _currencyFormat.format(_rentCollected),
                          ),
                          const SizedBox(height: 12),
                          _buildLegendLine(
                            color: const Color(0xFFF97316),
                            label: 'Pending Rent',
                            value: _currencyFormat.format(_pendingRent),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendLine({
    required Color color,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: _fontFamily,
              fontSize: 14,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildBarChartCard() {
    if (_trend.isEmpty) {
      return Card(
        color: AppTheme.surfaceColor,
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'No trend data available yet.',
            style: TextStyle(
              fontFamily: _fontFamily,
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    final maxY = _resolveBarMaxY();

    return Card(
      color: AppTheme.surfaceColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '6-Month Revenue vs Expenses',
              style: TextStyle(
                fontFamily: _fontFamily,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final chartWidth = constraints.maxWidth < 520 ? 520.0 : constraints.maxWidth;

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: chartWidth,
                    height: 260,
                    child: BarChart(
                      BarChartData(
                        maxY: maxY,
                        barGroups: _buildBarGroups(),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: maxY / 4,
                          getDrawingHorizontalLine: (_) => FlLine(
                            color: const Color(0xFF334155),
                            strokeWidth: 1,
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: maxY / 4,
                              reservedSize: 64,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  _currencyFormat.format(value),
                                  style: const TextStyle(
                                    fontFamily: _fontFamily,
                                    fontSize: 10,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                );
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final index = value.toInt();
                                if (index < 0 || index >= _trend.length) {
                                  return const SizedBox.shrink();
                                }

                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    DateFormat('MMM').format(_trend[index].month),
                                    style: const TextStyle(
                                      fontFamily: _fontFamily,
                                      fontSize: 12,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        barTouchData: BarTouchData(enabled: true),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 16,
              runSpacing: 10,
              children: const [
                _ChartLegend(label: 'Revenue', color: Color(0xFF0D9488)),
                _ChartLegend(label: 'Expenses', color: Color(0xFFF97316)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<BarChartGroupData> _buildBarGroups() {
    final groups = <BarChartGroupData>[];

    for (int i = 0; i < _trend.length; i++) {
      final data = _trend[i];
      groups.add(
        BarChartGroupData(
          x: i,
          barsSpace: 6,
          barRods: [
            BarChartRodData(
              toY: data.revenue,
              width: 11,
              borderRadius: BorderRadius.circular(3),
              color: const Color(0xFF0D9488),
            ),
            BarChartRodData(
              toY: data.expenses,
              width: 11,
              borderRadius: BorderRadius.circular(3),
              color: const Color(0xFFF97316),
            ),
          ],
        ),
      );
    }

    return groups;
  }

  double _resolveBarMaxY() {
    double maxValue = 0;

    for (final point in _trend) {
      if (point.revenue > maxValue) {
        maxValue = point.revenue;
      }
      if (point.expenses > maxValue) {
        maxValue = point.expenses;
      }
    }

    if (maxValue <= 0) {
      return 100;
    }

    return maxValue * 1.2;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Profit & Loss Dashboard',
          style: TextStyle(fontFamily: _fontFamily),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: _fontFamily,
                        fontSize: 16,
                      ),
                    ),
                  ),
                )
              : SafeArea(
                  child: RefreshIndicator(
                    onRefresh: _loadFinanceData,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Filter',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontFamily: _fontFamily,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ),
                            SizedBox(
                              width: 170,
                              child: DropdownButtonFormField<FinanceRange>(
                                value: _selectedRange,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                                style: const TextStyle(
                                  fontFamily: _fontFamily,
                                  color: Colors.white,
                                ),
                                dropdownColor: AppTheme.surfaceColor,
                                items: FinanceRange.values
                                    .map(
                                      (range) => DropdownMenuItem<FinanceRange>(
                                        value: range,
                                        child: Text(
                                          _rangeLabel(range),
                                          style: const TextStyle(fontFamily: _fontFamily),
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  _onRangeChanged(value);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _buildNetProfitCard(),
                        const SizedBox(height: 12),
                        _buildTaxLiabilityCard(),
                        const SizedBox(height: 16),
                        _buildPieChartCard(),
                        const SizedBox(height: 16),
                        _buildPotentialIncomeCard(),
                        const SizedBox(height: 16),
                        _buildBarChartCard(),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const ArrearsReportScreen(),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFACC15),
                              foregroundColor: Colors.black,
                            ),
                            icon: const Icon(LucideIcons.walletCards),
                            label: const Text(
                              'Open Debt Aging Report',
                              style: TextStyle(
                                fontFamily: _fontFamily,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontFamily: _FinanceDashboardScreenState._fontFamily,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
