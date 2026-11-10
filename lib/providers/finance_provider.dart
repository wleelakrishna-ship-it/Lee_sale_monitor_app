import 'package:flutter/foundation.dart';

import '../db/database_helper.dart';
import '../models/finance.dart';
import '../utils/date_utils.dart';

class FinanceProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;

  List<InvestorTotal> _investorTotals = [];
  List<Expense> _expenses = [];
  List<String> _investorNames = [];
  double _totalInvestedAllTime = 0;
  double _totalSharedAllTime = 0;
  bool _loading = false;

  ReportRangeType _rangeType = ReportRangeType.day;
  DateTime? _customStart;
  DateTime? _customEnd;
  DateRange _range = buildRange(ReportRangeType.day);
  ({double totalInvested, double totalExpenses, double totalShared}) _financeTotals =
      (totalInvested: 0.0, totalExpenses: 0.0, totalShared: 0.0);
  List<Expense> _expensesInRange = [];
  List<Investor> _investedInRange = [];
  List<ProfitShare> _sharedInRange = [];
  bool _reportLoading = false;

  List<InvestorTotal> get investorTotals => _investorTotals;
  List<Expense> get expenses => _expenses;
  List<String> get investorNames => _investorNames;
  double get totalExpensesAllTime => _expenses.fold(0.0, (sum, e) => sum + e.amount);
  double get totalInvestedAllTime => _totalInvestedAllTime;
  double get totalSharedAllTime => _totalSharedAllTime;
  double get netOutstandingAllTime => _totalInvestedAllTime - _totalSharedAllTime;
  bool get loading => _loading;

  ReportRangeType get rangeType => _rangeType;
  DateRange get range => _range;
  DateTime? get customStart => _customStart;
  DateTime? get customEnd => _customEnd;
  ({double totalInvested, double totalExpenses, double totalShared}) get financeTotals =>
      _financeTotals;
  List<Expense> get expensesInRange => _expensesInRange;
  List<Investor> get investedInRange => _investedInRange;
  List<ProfitShare> get sharedInRange => _sharedInRange;
  bool get reportLoading => _reportLoading;

  Future<void> loadOverview() async {
    _loading = true;
    notifyListeners();
    _investorTotals = await _db.getInvestorTotals();
    _expenses = await _db.getAllExpenses();
    _investorNames = await _db.getDistinctInvestorNames();
    final allTime = await _db.getAllTimeInvestedAndShared();
    _totalInvestedAllTime = allTime.totalInvestedAllTime;
    _totalSharedAllTime = allTime.totalSharedAllTime;
    _loading = false;
    notifyListeners();
  }

  Future<void> addInvestor({required String name, required double amount, String? note}) async {
    final now = DateTime.now().toIso8601String();
    await _db.insertInvestor(
      Investor(name: name, amount: amount, date: todayDbDate(), note: note, createdAt: now),
    );
    await loadOverview();
  }

  Future<void> addExpense({required String description, required double amount}) async {
    final now = DateTime.now().toIso8601String();
    await _db.insertExpense(
      Expense(description: description, amount: amount, date: todayDbDate(), createdAt: now),
    );
    await loadOverview();
  }

  Future<void> addProfitShare({
    required String investorName,
    required double amount,
    String? note,
  }) async {
    final now = DateTime.now().toIso8601String();
    await _db.insertProfitShare(
      ProfitShare(
        investorName: investorName,
        amount: amount,
        date: todayDbDate(),
        note: note,
        createdAt: now,
      ),
    );
    await loadOverview();
  }

  Future<void> setRangeType(ReportRangeType type) async {
    _rangeType = type;
    await _reloadReport();
  }

  Future<void> setCustomRange(DateTime start, DateTime end) async {
    _rangeType = ReportRangeType.custom;
    _customStart = start;
    _customEnd = end;
    await _reloadReport();
  }

  Future<void> loadReport() => _reloadReport();

  Future<void> _reloadReport() async {
    _reportLoading = true;
    notifyListeners();

    _range = buildRange(_rangeType, customStart: _customStart, customEnd: _customEnd);
    final startDate = formatDbDate(_range.start);
    final endDate = formatDbDate(_range.end);

    _financeTotals = await _db.getFinanceTotals(startDate, endDate);
    _expensesInRange = await _db.getExpenseList(startDate, endDate);
    _investedInRange = await _db.getInvestorList(startDate, endDate);
    _sharedInRange = await _db.getProfitShareList(startDate, endDate);
    final allTime = await _db.getAllTimeInvestedAndShared();
    _totalInvestedAllTime = allTime.totalInvestedAllTime;
    _totalSharedAllTime = allTime.totalSharedAllTime;

    _reportLoading = false;
    notifyListeners();
  }
}
