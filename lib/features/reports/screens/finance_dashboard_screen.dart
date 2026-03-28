import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../services/finance_service.dart';

class FinanceDashboardScreen extends StatefulWidget {
  const FinanceDashboardScreen({super.key});

  @override
  State<FinanceDashboardScreen> createState() => _FinanceDashboardScreenState();
}

class _FinanceDashboardScreenState extends State<FinanceDashboardScreen> {
  final _currency = NumberFormat.currency(symbol: r'$ ', decimalDigits: 0);

  bool _isLoading = true;
  String? _error;
  FinanceFilter _selectedFilter = FinanceFilter.thisMonth;

  double _currentMonthProfit = 0;
  RentCollectionSnapshot _rentSnapshot = const RentCollectionSnapshot(
    collected: 0,
    pending: 0,
  );
  List<FinanceTrendPoint> _trend = [];

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final now = DateTime.now();

      final currentMonthRevenue =
          await FinanceService.instance.getMonthlyRevenue(now);
      final currentMonthExpenses =
          await FinanceService.instance.getMonthlyExpenses(now);
      final rentSnapshot =
          await FinanceService.instance.getRentCollectionSnapshot(_selectedFilter);
      final trend = await FinanceService.instance.getSixMonthTrend();

      if (!mounted) return;

      setState(() {
        _currentMonthProfit = currentMonthRevenue - currentMonthExpenses;
        _rentSnapshot = rentSnapshot;
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

  Future<void> _onFilterChanged(FinanceFilter? filter) async {
    if (filter == null || filter == _selectedFilter) {
      return;
    }

    if (!mounted) return;

    setState(() {
      _selectedFilter = filter;
      _isLoading = true;
    });

    try {
      final rentSnapshot =
          await FinanceService.instance.getRentCollectionSnapshot(filter);

      if (!mounted) return;

      setState(() {
        _rentSnapshot = rentSnapshot;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _error = 'Failed to refresh filter: $error';
      });
    }
  }

  String _labelForFilter(FinanceFilter filter) {
    switch (filter) {
      case FinanceFilter.thisMonth:
        return 'This Month';
      case FinanceFilter.lastMonth:
        return 'Last Month';
      case FinanceFilter.thisYear:
        return 'This Year';
    }
  }

  Widget _buildProfitCard() {
    final isPositive = _currentMonthProfit >= 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPositive ? AppTheme.primaryColor : Colors.orange,
          width: 1.4,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Net Profit',
            style: TextStyle(
              fontFamily: AppTheme.appFontFamily,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _currency.format(_currentMonthProfit),
            style: TextStyle(
              fontFamily: AppTheme.appFontFamily,
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: isPositive ? AppTheme.primaryColor : Colors.orange,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Current month balance',
            style: TextStyle(
              fontFamily: AppTheme.appFontFamily,
              color: Color(0xFFCBD5E1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown() {
    return DropdownButtonFormField<FinanceFilter>(
      initialValue: _selectedFilter,
      decoration: const InputDecoration(
        labelText: 'Period',
      ),
      style: const TextStyle(fontFamily: AppTheme.appFontFamily),
      items: FinanceFilter.values
          .map(
            (item) => DropdownMenuItem<FinanceFilter>(
              value: item,
              child: Text(
                _labelForFilter(item),
                style: const TextStyle(fontFamily: AppTheme.appFontFamily),
              ),
            ),
          )
          .toList(),
      onChanged: _onFilterChanged,
    );
  }

  Widget _buildRentPieChart(BoxConstraints constraints) {
    final total = _rentSnapshot.collected + _rentSnapshot.pending;
    final isEmpty = total <= 0;
    final chartSize = constraints.maxWidth < 360 ? 180.0 : 230.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rent Status (${_labelForFilter(_selectedFilter)})',
            style: const TextStyle(
              fontFamily: AppTheme.appFontFamily,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          if (isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  'No rent activity available',
                  style: TextStyle(fontFamily: AppTheme.appFontFamily),
                ),
              ),
            )
          else
            SizedBox(
              height: chartSize,
              child: PieChart(
                PieChartData(
                  centerSpaceRadius: chartSize * 0.2,
                  sectionsSpace: 2,
                  sections: [
                    PieChartSectionData(
                      value: _rentSnapshot.collected,
                      color: AppTheme.primaryColor,
                      title:
                          '${((_rentSnapshot.collected / total) * 100).toStringAsFixed(0)}%',
                      radius: chartSize * 0.32,
                      titleStyle: const TextStyle(
                        fontFamily: AppTheme.appFontFamily,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    PieChartSectionData(
                      value: _rentSnapshot.pending,
                      color: Colors.orange,
                      title:
                          '${((_rentSnapshot.pending / total) * 100).toStringAsFixed(0)}%',
                      radius: chartSize * 0.32,
                      titleStyle: const TextStyle(
                        fontFamily: AppTheme.appFontFamily,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _legendItem(
                color: AppTheme.primaryColor,
                label: 'Rent Collected: ${_currency.format(_rentSnapshot.collected)}',
              ),
              _legendItem(
                color: Colors.orange,
                label: 'Pending Rent: ${_currency.format(_rentSnapshot.pending)}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendItem({
    required Color color,
    required String label,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontFamily: AppTheme.appFontFamily),
        ),
      ],
    );
  }

  Widget _buildTrendBarChart(BoxConstraints constraints) {
    final chartHeight = constraints.maxWidth < 380 ? 250.0 : 300.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Revenue vs Expenses (6 Months)',
            style: TextStyle(
              fontFamily: AppTheme.appFontFamily,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          if (_trend.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'No trend data available',
                  style: TextStyle(fontFamily: AppTheme.appFontFamily),
                ),
              ),
            )
          else
            SizedBox(
              height: chartHeight,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: _maxTrendValue() * 1.2,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: _gridInterval(_maxTrendValue()),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 48,
                        interval: _gridInterval(_maxTrendValue()),
                        getTitlesWidget: (value, meta) {
                          return Text(
                            NumberFormat.compact().format(value),
                            style: const TextStyle(
                              fontFamily: AppTheme.appFontFamily,
                              fontSize: 10,
                            ),
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

                          final monthLabel = DateFormat('MMM').format(_trend[index].month);
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              monthLabel,
                              style: const TextStyle(
                                fontFamily: AppTheme.appFontFamily,
                                fontSize: 10,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(
                    _trend.length,
                    (index) {
                      final item = _trend[index];
                      return BarChartGroupData(
                        x: index,
                        barsSpace: 4,
                        barRods: [
                          BarChartRodData(
                            toY: item.revenue,
                            color: AppTheme.primaryColor,
                            width: constraints.maxWidth < 380 ? 10 : 12,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          BarChartRodData(
                            toY: item.expenses,
                            color: Colors.orange,
                            width: constraints.maxWidth < 380 ? 10 : 12,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _legendItem(color: AppTheme.primaryColor, label: 'Revenue'),
              _legendItem(color: Colors.orange, label: 'Expenses'),
            ],
          ),
        ],
      ),
    );
  }

  double _maxTrendValue() {
    double maxValue = 0;
    for (final item in _trend) {
      if (item.revenue > maxValue) {
        maxValue = item.revenue;
      }
      if (item.expenses > maxValue) {
        maxValue = item.expenses;
      }
    }

    return maxValue <= 0 ? 100 : maxValue;
  }

  double _gridInterval(double maxValue) {
    if (maxValue <= 1000) return 250;
    if (maxValue <= 5000) return 1000;
    if (maxValue <= 20000) return 5000;
    return 10000;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Profit & Loss Dashboard',
          style: TextStyle(fontFamily: AppTheme.appFontFamily),
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
                      style: const TextStyle(fontFamily: AppTheme.appFontFamily),
                    ),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    return RefreshIndicator(
                      onRefresh: _loadDashboard,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight - 32,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildProfitCard(),
                              const SizedBox(height: 16),
                              _buildFilterDropdown(),
                              const SizedBox(height: 16),
                              _buildRentPieChart(constraints),
                              const SizedBox(height: 16),
                              _buildTrendBarChart(constraints),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
