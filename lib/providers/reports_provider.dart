import 'package:flutter/foundation.dart';

import '../db/database_helper.dart';
import '../models/report_data.dart';
import '../models/sale.dart';
import '../utils/date_utils.dart';

class ReportsProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;

  ReportRangeType _rangeType = ReportRangeType.day;
  DateTime? _customStart;
  DateTime? _customEnd;
  DateRange _range = buildRange(ReportRangeType.day);

  double totalAmount = 0;
  double totalKg = 0;
  List<CategoryTotal> categoryTotals = [];
  List<BuyerTotal> buyerTotals = [];
  List<DailyTotal> dailyTotals = [];
  List<Sale> sales = [];
  bool loading = false;

  ReportRangeType get rangeType => _rangeType;
  DateRange get range => _range;
  DateTime? get customStart => _customStart;
  DateTime? get customEnd => _customEnd;

  Future<void> setRangeType(ReportRangeType type) async {
    _rangeType = type;
    await _reload();
  }

  Future<void> setCustomRange(DateTime start, DateTime end) async {
    _rangeType = ReportRangeType.custom;
    _customStart = start;
    _customEnd = end;
    await _reload();
  }

  Future<void> load() => _reload();

  Future<void> _reload() async {
    loading = true;
    notifyListeners();

    try {
      _range = buildRange(_rangeType, customStart: _customStart, customEnd: _customEnd);
      final startDate = formatDbDate(_range.start);
      final endDate = formatDbDate(_range.end);

      sales = await _db.getSalesForDateRange(startDate, endDate);
      categoryTotals = await _db.getCategoryTotals(startDate, endDate);
      buyerTotals = await _db.getBuyerTotals(startDate, endDate);
      dailyTotals = await _db.getDailyTotals(_range.start, _range.end);
      totalAmount = categoryTotals.fold(0.0, (sum, c) => sum + c.amount);
      totalKg = categoryTotals.fold(0.0, (sum, c) => sum + c.kilograms);
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
