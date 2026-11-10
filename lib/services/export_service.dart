import 'dart:io';

import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/finance.dart';
import '../models/report_data.dart';
import '../models/sale.dart';
import '../utils/date_utils.dart';

class ExportService {
  Future<void> exportReportCsv({
    required DateRange range,
    required List<Sale> sales,
    required List<CategoryTotal> categoryTotals,
    required List<BuyerTotal> buyerTotals,
    required double totalAmount,
    required double totalKg,
  }) async {
    final rows = <List<dynamic>>[
      ['Fish Sales Report', range.label],
      [],
      ['Date', 'Buyer', 'Category', 'Rate/Kg', 'Kilograms', 'Amount'],
      for (final sale in sales)
        [sale.date, sale.buyerName, sale.category, sale.ratePerKg, sale.kilograms, sale.amount],
      [],
      ['Summary'],
      ['Total Amount', totalAmount],
      ['Total Kilograms', totalKg],
      [],
      ['Category Breakdown'],
      ['Category', 'Amount', 'Kilograms'],
      for (final c in categoryTotals) [c.category, c.amount, c.kilograms],
      [],
      ['Buyer Breakdown'],
      ['Buyer', 'Amount', 'Kilograms'],
      for (final b in buyerTotals) [b.buyerName, b.amount, b.kilograms],
    ];

    final csvString = const ListToCsvConverter().convert(rows);
    final directory = await getApplicationDocumentsDirectory();
    final fileName =
        'fish_sales_report_${formatDbDate(range.start)}_to_${formatDbDate(range.end)}.csv';
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(csvString);

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Fish Sales Report - ${range.label}',
      text: 'Fish sales report for ${range.label}',
    );
  }

  Future<void> exportFinanceCsv({
    required DateRange range,
    required List<Expense> expenses,
    required List<Investor> investments,
    required List<ProfitShare> profitShares,
    required ({double totalInvested, double totalExpenses, double totalShared}) financeTotals,
    required double totalInvestedAllTime,
    required double totalSharedAllTime,
  }) async {
    final rows = <List<dynamic>>[
      ['Fish Business Finance Report', range.label],
      [],
      ['Expenses'],
      ['Date', 'Description', 'Amount'],
      for (final e in expenses) [e.date, e.description, e.amount],
      [],
      ['Investments'],
      ['Date', 'Investor', 'Amount', 'Note'],
      for (final i in investments) [i.date, i.name, i.amount, i.note ?? ''],
      [],
      ['Profit Shares'],
      ['Date', 'Investor', 'Amount', 'Note'],
      for (final p in profitShares) [p.date, p.investorName, p.amount, p.note ?? ''],
      [],
      ['Summary (selected range)'],
      ['Total Invested', financeTotals.totalInvested],
      ['Total Expenses', financeTotals.totalExpenses],
      ['Total Shared', financeTotals.totalShared],
      [],
      ['Summary (all time)'],
      ['Total Invested', totalInvestedAllTime],
      ['Total Shared', totalSharedAllTime],
      ['Net Outstanding', totalInvestedAllTime - totalSharedAllTime],
    ];

    final csvString = const ListToCsvConverter().convert(rows);
    final directory = await getApplicationDocumentsDirectory();
    final fileName =
        'fish_finance_report_${formatDbDate(range.start)}_to_${formatDbDate(range.end)}.csv';
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(csvString);

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Fish Business Finance Report - ${range.label}',
      text: 'Finance report for ${range.label}',
    );
  }
}
