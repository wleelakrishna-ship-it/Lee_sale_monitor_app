import 'package:flutter/foundation.dart';

import '../db/database_helper.dart';
import '../models/buyer_summary.dart';
import '../models/payment.dart';
import '../models/sale.dart';
import '../utils/date_utils.dart';

class CartItem {
  final String category;
  final double ratePerKg;
  final double kilograms;
  final double commissionPerKg;

  const CartItem({
    required this.category,
    required this.ratePerKg,
    required this.kilograms,
    this.commissionPerKg = 0.0,
  });

  double get amount => ratePerKg * kilograms;
}

class SalesProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;

  final List<CartItem> _cart = [];
  List<String> _buyerNames = [];
  List<BuyerSummary> _todaySummaries = [];
  ({double totalAmount, double totalKg, double totalCommission, int buyerCount}) _dayTotals =
      (totalAmount: 0.0, totalKg: 0.0, totalCommission: 0.0, buyerCount: 0);
  bool _loading = false;

  List<Sale> _buyerSales = [];
  List<Payment> _buyerPayments = [];
  bool _buyerDetailLoading = false;

  List<CartItem> get cart => List.unmodifiable(_cart);
  double get cartTotal => _cart.fold(0.0, (sum, item) => sum + item.amount);
  List<String> get buyerNames => _buyerNames;
  List<BuyerSummary> get todaySummaries => _todaySummaries;
  ({double totalAmount, double totalKg, double totalCommission, int buyerCount}) get dayTotals =>
      _dayTotals;
  bool get loading => _loading;

  /// Total paid by buyers today (grand total minus this is what's still owed).
  double get givenTotalToday => _todaySummaries.fold(0.0, (sum, s) => sum + s.given);

  /// Total still owed by buyers today (grand total − given so far).
  double get balanceTotalToday => _dayTotals.totalAmount - givenTotalToday;

  List<Sale> get buyerSales => _buyerSales;
  List<Payment> get buyerPayments => _buyerPayments;
  bool get buyerDetailLoading => _buyerDetailLoading;

  Future<void> loadBuyerNames() async {
    _buyerNames = await _db.getDistinctBuyerNames();
    notifyListeners();
  }

  void addCartItem(CartItem item) {
    _cart.add(item);
    notifyListeners();
  }

  void removeCartItem(int index) {
    _cart.removeAt(index);
    notifyListeners();
  }

  void clearCart() {
    _cart.clear();
    notifyListeners();
  }

  Future<void> saveSale({required String buyerName, required double amountGiven}) async {
    if (_cart.isEmpty) return;
    final date = todayDbDate();
    final now = DateTime.now().toIso8601String();
    final sales = _cart
        .map((item) => Sale(
              date: date,
              buyerName: buyerName,
              category: item.category,
              ratePerKg: item.ratePerKg,
              kilograms: item.kilograms,
              amount: item.amount,
              createdAt: now,
              commissionPerKg: item.commissionPerKg,
            ))
        .toList();
    await _db.insertSales(sales);
    if (amountGiven > 0) {
      await _db.insertPayment(
        Payment(date: date, buyerName: buyerName, amountGiven: amountGiven, createdAt: now),
      );
    }
    clearCart();
    await loadBuyerNames();
    await loadTodayOverview();
  }

  Future<void> addPaymentForBuyer(String buyerName, double amountGiven) async {
    if (amountGiven <= 0) return;
    final date = todayDbDate();
    await _db.insertPayment(
      Payment(
        date: date,
        buyerName: buyerName,
        amountGiven: amountGiven,
        createdAt: DateTime.now().toIso8601String(),
      ),
    );
    await loadTodayOverview();
  }

  Future<void> loadTodayOverview() async {
    _loading = true;
    notifyListeners();
    try {
      final date = todayDbDate();
      _todaySummaries = await _db.getBuyerSummariesForDate(date);
      _dayTotals = await _db.getDayTotals(date);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadBuyerDayDetail(String buyerName) async {
    _buyerDetailLoading = true;
    notifyListeners();
    try {
      final date = todayDbDate();
      _buyerSales = await _db.getSalesForBuyerOnDate(date, buyerName);
      _buyerPayments = await _db.getPaymentsForBuyerOnDate(date, buyerName);
    } finally {
      _buyerDetailLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateSaleItem(Sale sale) async {
    await _db.updateSale(sale);
    await loadBuyerDayDetail(sale.buyerName);
    await loadTodayOverview();
  }

  Future<void> deleteSaleItem(String id, String buyerName) async {
    await _db.deleteSale(id);
    await loadBuyerDayDetail(buyerName);
    await loadTodayOverview();
  }

  Future<void> updatePaymentItem(Payment payment) async {
    await _db.updatePayment(payment);
    await loadBuyerDayDetail(payment.buyerName);
    await loadTodayOverview();
  }

  Future<void> deletePaymentItem(String id, String buyerName) async {
    await _db.deletePayment(id);
    await loadBuyerDayDetail(buyerName);
    await loadTodayOverview();
  }
}
