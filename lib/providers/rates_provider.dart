import 'package:flutter/foundation.dart';

import '../db/database_helper.dart';
import '../models/category_rate.dart';
import '../utils/date_utils.dart';

class RatesProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;

  List<CategoryRate> _todayRates = [];
  bool _loading = false;

  List<CategoryRate> get todayRates => _todayRates;
  bool get loading => _loading;

  Future<void> loadTodayRates() async {
    _loading = true;
    notifyListeners();
    try {
      _todayRates = await _db.getRatesForDate(todayDbDate());
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> addCategory(String category, double ratePerKg) async {
    await _db.insertCategoryRate(
      CategoryRate(date: todayDbDate(), category: category, ratePerKg: ratePerKg),
    );
    await loadTodayRates();
  }

  Future<void> updateCategory(CategoryRate rate) async {
    await _db.updateCategoryRate(rate);
    await loadTodayRates();
  }

  Future<void> deleteCategory(String id) async {
    await _db.deleteCategoryRate(id);
    await loadTodayRates();
  }

  Future<bool> copyYesterdaysRates() async {
    final previous = await _db.getMostRecentRatesBefore(todayDbDate());
    if (previous.isEmpty) return false;
    for (final rate in previous) {
      await _db.insertCategoryRate(
        CategoryRate(date: todayDbDate(), category: rate.category, ratePerKg: rate.ratePerKg),
      );
    }
    await loadTodayRates();
    return true;
  }
}
