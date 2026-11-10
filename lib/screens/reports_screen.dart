import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../models/report_data.dart';
import '../providers/finance_provider.dart';
import '../providers/reports_provider.dart';
import '../services/export_service.dart';
import '../utils/date_utils.dart';
import '../utils/formatters.dart';
import '../widgets/summary_card.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  final _exportService = ExportService();
  late final TabController _tabController;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)..addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReportsProvider>().load();
      context.read<FinanceProvider>().loadReport();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pickCustomRange(ReportsProvider provider) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: provider.customStart ?? now.subtract(const Duration(days: 6)),
        end: provider.customEnd ?? now,
      ),
    );
    if (picked != null) {
      await provider.setCustomRange(picked.start, picked.end);
    }
  }

  Future<void> _pickCustomFinanceRange(FinanceProvider provider) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: provider.customStart ?? now.subtract(const Duration(days: 6)),
        end: provider.customEnd ?? now,
      ),
    );
    if (picked != null) {
      await provider.setCustomRange(picked.start, picked.end);
    }
  }

  Future<void> _export(ReportsProvider provider) async {
    setState(() => _exporting = true);
    try {
      await _exportService.exportReportCsv(
        range: provider.range,
        sales: provider.sales,
        categoryTotals: provider.categoryTotals,
        buyerTotals: provider.buyerTotals,
        totalAmount: provider.totalAmount,
        totalKg: provider.totalKg,
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _exportFinance(FinanceProvider provider) async {
    setState(() => _exporting = true);
    try {
      await _exportService.exportFinanceCsv(
        range: provider.range,
        expenses: provider.expensesInRange,
        investments: provider.investedInRange,
        profitShares: provider.sharedInRange,
        financeTotals: provider.financeTotals,
        totalInvestedAllTime: provider.totalInvestedAllTime,
        totalSharedAllTime: provider.totalSharedAllTime,
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportsProvider = context.watch<ReportsProvider>();
    final financeProvider = context.watch<FinanceProvider>();
    final isFinanceTab = _tabController.index == 1;

    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'reports_title')),
        actions: [
          IconButton(
            icon: _exporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.download),
            tooltip: tr(context, 'download_csv_tooltip'),
            onPressed: _exporting
                ? null
                : () => isFinanceTab ? _exportFinance(financeProvider) : _export(reportsProvider),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [Tab(text: tr(context, 'tab_sales')), Tab(text: tr(context, 'tab_finance'))],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _SalesReportBody(
            provider: reportsProvider,
            onPickCustomRange: () => _pickCustomRange(reportsProvider),
          ),
          _FinanceReportBody(
            provider: financeProvider,
            onPickCustomRange: () => _pickCustomFinanceRange(financeProvider),
          ),
        ],
      ),
    );
  }
}

class _SalesReportBody extends StatelessWidget {
  final ReportsProvider provider;
  final VoidCallback onPickCustomRange;

  const _SalesReportBody({required this.provider, required this.onPickCustomRange});

  @override
  Widget build(BuildContext context) {
    if (provider.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _RangeChip(
              label: tr(context, 'range_day'),
              selected: provider.rangeType == ReportRangeType.day,
              onTap: () => provider.setRangeType(ReportRangeType.day),
            ),
            _RangeChip(
              label: tr(context, 'range_week'),
              selected: provider.rangeType == ReportRangeType.week,
              onTap: () => provider.setRangeType(ReportRangeType.week),
            ),
            _RangeChip(
              label: tr(context, 'range_month'),
              selected: provider.rangeType == ReportRangeType.month,
              onTap: () => provider.setRangeType(ReportRangeType.month),
            ),
            _RangeChip(
              label: tr(context, 'range_year'),
              selected: provider.rangeType == ReportRangeType.year,
              onTap: () => provider.setRangeType(ReportRangeType.year),
            ),
            _RangeChip(
              label: tr(context, 'range_custom'),
              selected: provider.rangeType == ReportRangeType.custom,
              onTap: onPickCustomRange,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(provider.range.label, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: SummaryCard(
                title: tr(context, 'total_amount_card'),
                value: formatCurrency(provider.totalAmount),
                icon: Icons.currency_rupee,
                color: Colors.teal,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SummaryCard(
                title: tr(context, 'total_kg_card'),
                value: formatKg(provider.totalKg),
                icon: Icons.scale,
                color: Colors.indigo,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (provider.dailyTotals.length > 1) ...[
          Text(tr(context, 'daily_totals_label'), style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 12),
          SizedBox(height: 220, child: _DailyTotalsChart(data: provider.dailyTotals)),
          const SizedBox(height: 24),
        ],
        Text(tr(context, 'category_breakdown_label'), style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        if (provider.categoryTotals.isEmpty)
          Text(tr(context, 'no_sales_period'))
        else
          ...provider.categoryTotals.map(
            (c) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(c.category),
              subtitle: Text(formatKg(c.kilograms)),
              trailing:
                  Text(formatCurrency(c.amount), style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        const SizedBox(height: 16),
        Text(tr(context, 'buyer_breakdown_label'), style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        if (provider.buyerTotals.isEmpty)
          Text(tr(context, 'no_sales_period'))
        else
          ...provider.buyerTotals.map(
            (b) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(b.buyerName),
              subtitle: Text(formatKg(b.kilograms)),
              trailing:
                  Text(formatCurrency(b.amount), style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
      ],
    );
  }
}

class _FinanceReportBody extends StatelessWidget {
  final FinanceProvider provider;
  final VoidCallback onPickCustomRange;

  const _FinanceReportBody({required this.provider, required this.onPickCustomRange});

  @override
  Widget build(BuildContext context) {
    if (provider.reportLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final totals = provider.financeTotals;
    final netStatusResult = netStatus(provider.totalInvestedAllTime, provider.totalSharedAllTime);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _RangeChip(
              label: tr(context, 'range_day'),
              selected: provider.rangeType == ReportRangeType.day,
              onTap: () => provider.setRangeType(ReportRangeType.day),
            ),
            _RangeChip(
              label: tr(context, 'range_week'),
              selected: provider.rangeType == ReportRangeType.week,
              onTap: () => provider.setRangeType(ReportRangeType.week),
            ),
            _RangeChip(
              label: tr(context, 'range_month'),
              selected: provider.rangeType == ReportRangeType.month,
              onTap: () => provider.setRangeType(ReportRangeType.month),
            ),
            _RangeChip(
              label: tr(context, 'range_year'),
              selected: provider.rangeType == ReportRangeType.year,
              onTap: () => provider.setRangeType(ReportRangeType.year),
            ),
            _RangeChip(
              label: tr(context, 'range_custom'),
              selected: provider.rangeType == ReportRangeType.custom,
              onTap: onPickCustomRange,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(provider.range.label, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: SummaryCard(
                title: tr(context, 'invested_range_card'),
                value: formatCurrency(totals.totalInvested),
                icon: Icons.trending_up,
                color: Colors.teal,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SummaryCard(
                title: tr(context, 'expenses_range_card'),
                value: formatCurrency(totals.totalExpenses),
                icon: Icons.receipt_long,
                color: Colors.deepOrange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: SummaryCard(
                title: tr(context, 'shared_range_card'),
                value: formatCurrency(totals.totalShared),
                icon: Icons.volunteer_activism,
                color: Colors.purple,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SummaryCard(
                title: netStatusResult.isProfit
                    ? tr(context, 'net_profit_alltime_card')
                    : tr(context, 'net_outstanding_alltime_card'),
                value: netStatusResult.isProfit
                    ? '+${formatCurrency(netStatusResult.amount)}'
                    : formatCurrency(netStatusResult.amount),
                icon: Icons.account_balance_wallet_outlined,
                color: netStatusResult.isProfit ? Colors.green.shade700 : Colors.red.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(tr(context, 'expenses_in_range_label'), style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        if (provider.expensesInRange.isEmpty)
          Text(tr(context, 'no_expenses_period'))
        else
          ...provider.expensesInRange.map(
            (e) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(e.description),
              subtitle: Text(e.date),
              trailing:
                  Text(formatCurrency(e.amount), style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        const SizedBox(height: 16),
        Text(tr(context, 'investments_in_range_label'), style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        if (provider.investedInRange.isEmpty)
          Text(tr(context, 'no_investments_period'))
        else
          ...provider.investedInRange.map(
            (i) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(i.name),
              subtitle: Text(i.date),
              trailing:
                  Text(formatCurrency(i.amount), style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        const SizedBox(height: 16),
        Text(tr(context, 'profit_shares_in_range_label'), style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        if (provider.sharedInRange.isEmpty)
          Text(tr(context, 'no_profit_shares_period'))
        else
          ...provider.sharedInRange.map(
            (p) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(p.investorName),
              subtitle: Text(p.date),
              trailing:
                  Text(formatCurrency(p.amount), style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
      ],
    );
  }
}

class _RangeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RangeChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap());
  }
}

class _DailyTotalsChart extends StatelessWidget {
  final List<DailyTotal> data;

  const _DailyTotalsChart({required this.data});

  static const _barColor = Color(0xFF0D9488); // teal-600: single-series magnitude, one hue.

  @override
  Widget build(BuildContext context) {
    final maxAmount = data.fold<double>(0, (max, d) => d.amount > max ? d.amount : max);
    final showEveryLabel = data.length <= 7;

    return BarChart(
      BarChartData(
        maxY: maxAmount == 0 ? 10 : maxAmount * 1.2,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (maxAmount == 0 ? 10 : maxAmount * 1.2) / 4,
          getDrawingHorizontalLine: (_) => const FlLine(color: Color(0xFFE5E7EB), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (value, meta) => Text(
                formatCurrency(value),
                style: const TextStyle(fontSize: 10, color: Colors.black45),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= data.length) return const SizedBox.shrink();
                if (!showEveryLabel && index % (data.length / 6).ceil() != 0) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    displayDayFormat.format(data[index].date),
                    style: const TextStyle(fontSize: 10, color: Colors.black54),
                  ),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
              '${displayDayFormat.format(data[group.x].date)}\n${formatCurrency(rod.toY)}',
              const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < data.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: data[i].amount,
                  color: _barColor,
                  width: data.length > 20 ? 6 : 14,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
