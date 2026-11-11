import 'package:flutter/foundation.dart';

import '../db/database_helper.dart';
import '../models/buyer_overview.dart';
import '../models/payment.dart';
import '../models/sale.dart';

class BuyersProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;

  List<BuyerOverallSummary> _allBuyers = [];
  String _searchQuery = '';
  bool _loading = false;

  List<Sale> _historySales = [];
  List<Payment> _historyPayments = [];
  BuyerOverallSummary? _selectedBuyerSummary;
  bool _historyLoading = false;

  List<BuyerOverallSummary> get allBuyers => _allBuyers;
  String get searchQuery => _searchQuery;
  bool get loading => _loading;

  List<BuyerOverallSummary> get filteredBuyers {
    if (_searchQuery.isEmpty) return _allBuyers;
    final query = _searchQuery.toLowerCase();
    return _allBuyers.where((b) => b.buyerName.toLowerCase().contains(query)).toList();
  }

  List<Sale> get historySales => _historySales;
  List<Payment> get historyPayments => _historyPayments;
  BuyerOverallSummary? get selectedBuyerSummary => _selectedBuyerSummary;
  bool get historyLoading => _historyLoading;

  void setSearchQuery(String value) {
    _searchQuery = value;
    notifyListeners();
  }

  Future<void> loadAllBuyers() async {
    _loading = true;
    notifyListeners();
    try {
      _allBuyers = await _db.getAllBuyerOverallSummaries();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadBuyerHistory(String buyerName) async {
    _historyLoading = true;
    notifyListeners();
    try {
      if (_allBuyers.isEmpty) {
        _allBuyers = await _db.getAllBuyerOverallSummaries();
      }
      _historySales = await _db.getSalesForBuyerAllTime(buyerName);
      _historyPayments = await _db.getPaymentsForBuyerAllTime(buyerName);
      try {
        _selectedBuyerSummary = _allBuyers.firstWhere((b) => b.buyerName == buyerName);
      } catch (_) {
        _selectedBuyerSummary = null;
      }
    } finally {
      _historyLoading = false;
      notifyListeners();
    }
  }
}
