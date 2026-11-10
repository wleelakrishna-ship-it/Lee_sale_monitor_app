import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/buyer_overview.dart';
import '../models/buyer_summary.dart';
import '../models/category_rate.dart';
import '../models/finance.dart';
import '../models/payment.dart';
import '../models/report_data.dart';
import '../models/sale.dart';
import '../utils/date_utils.dart';

/// Shared cloud data store (Cloud Firestore). Every signed-in user reads/writes the
/// same collections, so the data is shared across devices rather than per-device.
///
/// Firestore can't do SQL-style SUM/GROUP BY, so aggregations here fetch the relevant
/// documents (filtered by a single field to stay within Firestore's automatic indexes)
/// and reduce them in Dart. That's fine at this app's data volume.
class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _categoryRates =>
      _firestore.collection('category_rates');
  CollectionReference<Map<String, dynamic>> get _sales => _firestore.collection('sales');
  CollectionReference<Map<String, dynamic>> get _payments => _firestore.collection('payments');
  CollectionReference<Map<String, dynamic>> get _investors => _firestore.collection('investors');
  CollectionReference<Map<String, dynamic>> get _expenses => _firestore.collection('expenses');
  CollectionReference<Map<String, dynamic>> get _profitShares =>
      _firestore.collection('profit_shares');

  // ---------------- Category rates ----------------

  Future<void> insertCategoryRate(CategoryRate rate) async {
    await _categoryRates.add(rate.toMap());
  }

  Future<void> updateCategoryRate(CategoryRate rate) async {
    await _categoryRates.doc(rate.id).update(rate.toMap());
  }

  Future<void> deleteCategoryRate(String id) async {
    await _categoryRates.doc(id).delete();
  }

  Future<List<CategoryRate>> getRatesForDate(String date) async {
    final snapshot = await _categoryRates.where('date', isEqualTo: date).get();
    final rates = snapshot.docs.map((doc) => CategoryRate.fromMap(doc.id, doc.data())).toList();
    rates.sort((a, b) => a.category.compareTo(b.category));
    return rates;
  }

  /// Rates from the most recent date strictly before [date], for "copy yesterday's rates".
  Future<List<CategoryRate>> getMostRecentRatesBefore(String date) async {
    final snapshot = await _categoryRates
        .where('date', isLessThan: date)
        .orderBy('date', descending: true)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return [];
    final maxDate = snapshot.docs.first.data()['date'] as String;
    return getRatesForDate(maxDate);
  }

  // ---------------- Sales ----------------

  Future<void> insertSales(List<Sale> sales) async {
    final batch = _firestore.batch();
    for (final sale in sales) {
      batch.set(_sales.doc(), sale.toMap());
    }
    await batch.commit();
  }

  Future<List<Sale>> getSalesForDateRange(String startDate, String endDate) async {
    final snapshot = await _sales
        .where('date', isGreaterThanOrEqualTo: startDate)
        .where('date', isLessThanOrEqualTo: endDate)
        .get();
    final sales = snapshot.docs.map((doc) => Sale.fromMap(doc.id, doc.data())).toList();
    sales.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return sales;
  }

  Future<void> updateSale(Sale sale) async {
    await _sales.doc(sale.id).update(sale.toMap());
  }

  Future<void> deleteSale(String id) async {
    await _sales.doc(id).delete();
  }

  Future<List<Sale>> getSalesForBuyerOnDate(String date, String buyerName) async {
    final snapshot = await _sales.where('date', isEqualTo: date).get();
    final sales = snapshot.docs
        .map((doc) => Sale.fromMap(doc.id, doc.data()))
        .where((sale) => sale.buyerName == buyerName)
        .toList();
    sales.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return sales;
  }

  // ---------------- Payments ----------------

  Future<void> insertPayment(Payment payment) async {
    await _payments.add(payment.toMap());
  }

  Future<List<Payment>> getPaymentsForDateRange(String startDate, String endDate) async {
    final snapshot = await _payments
        .where('date', isGreaterThanOrEqualTo: startDate)
        .where('date', isLessThanOrEqualTo: endDate)
        .get();
    final payments = snapshot.docs.map((doc) => Payment.fromMap(doc.id, doc.data())).toList();
    payments.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return payments;
  }

  Future<void> updatePayment(Payment payment) async {
    await _payments.doc(payment.id).update(payment.toMap());
  }

  Future<void> deletePayment(String id) async {
    await _payments.doc(id).delete();
  }

  Future<List<Payment>> getPaymentsForBuyerOnDate(String date, String buyerName) async {
    final snapshot = await _payments.where('date', isEqualTo: date).get();
    final payments = snapshot.docs
        .map((doc) => Payment.fromMap(doc.id, doc.data()))
        .where((payment) => payment.buyerName == buyerName)
        .toList();
    payments.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return payments;
  }

  // ---------------- Buyers ----------------

  Future<List<String>> getDistinctBuyerNames() async {
    final snapshot = await _sales.get();
    final names = <String>{for (final doc in snapshot.docs) doc.data()['buyer_name'] as String};
    final sorted = names.toList()..sort();
    return sorted;
  }

  Future<List<BuyerSummary>> getBuyerSummariesForDate(String date) async {
    final salesSnapshot = await _sales.where('date', isEqualTo: date).get();
    final paymentsSnapshot = await _payments.where('date', isEqualTo: date).get();

    final totalsByBuyer = <String, double>{};
    final kgByBuyer = <String, double>{};
    for (final doc in salesSnapshot.docs) {
      final data = doc.data();
      final buyerName = data['buyer_name'] as String;
      totalsByBuyer[buyerName] =
          (totalsByBuyer[buyerName] ?? 0) + (data['amount'] as num).toDouble();
      kgByBuyer[buyerName] = (kgByBuyer[buyerName] ?? 0) + (data['kilograms'] as num).toDouble();
    }
    final givenByBuyer = <String, double>{};
    for (final doc in paymentsSnapshot.docs) {
      final data = doc.data();
      final buyerName = data['buyer_name'] as String;
      givenByBuyer[buyerName] =
          (givenByBuyer[buyerName] ?? 0) + (data['amount_given'] as num).toDouble();
    }

    final summaries = totalsByBuyer.entries
        .map((entry) => BuyerSummary(
              buyerName: entry.key,
              total: entry.value,
              totalKilograms: kgByBuyer[entry.key] ?? 0.0,
              given: givenByBuyer[entry.key] ?? 0.0,
            ))
        .toList();
    summaries.sort((a, b) => a.buyerName.compareTo(b.buyerName));
    return summaries;
  }

  Future<({double totalAmount, double totalKg, int buyerCount})> getDayTotals(String date) async {
    final snapshot = await _sales.where('date', isEqualTo: date).get();
    double totalAmount = 0;
    double totalKg = 0;
    final buyers = <String>{};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      totalAmount += (data['amount'] as num).toDouble();
      totalKg += (data['kilograms'] as num).toDouble();
      buyers.add(data['buyer_name'] as String);
    }
    return (totalAmount: totalAmount, totalKg: totalKg, buyerCount: buyers.length);
  }

  /// All-time (not date-filtered) per-buyer totals, for the Buyers/ledger screens.
  Future<List<BuyerOverallSummary>> getAllBuyerOverallSummaries() async {
    final salesSnapshot = await _sales.get();
    final paymentsSnapshot = await _payments.get();

    final totalsByBuyer = <String, double>{};
    final kgByBuyer = <String, double>{};
    for (final doc in salesSnapshot.docs) {
      final data = doc.data();
      final buyerName = data['buyer_name'] as String;
      totalsByBuyer[buyerName] =
          (totalsByBuyer[buyerName] ?? 0) + (data['amount'] as num).toDouble();
      kgByBuyer[buyerName] = (kgByBuyer[buyerName] ?? 0) + (data['kilograms'] as num).toDouble();
    }
    final givenByBuyer = <String, double>{};
    for (final doc in paymentsSnapshot.docs) {
      final data = doc.data();
      final buyerName = data['buyer_name'] as String;
      givenByBuyer[buyerName] =
          (givenByBuyer[buyerName] ?? 0) + (data['amount_given'] as num).toDouble();
    }

    final summaries = totalsByBuyer.entries
        .map((entry) => BuyerOverallSummary(
              buyerName: entry.key,
              totalAmount: entry.value,
              totalKilograms: kgByBuyer[entry.key] ?? 0.0,
              totalGiven: givenByBuyer[entry.key] ?? 0.0,
            ))
        .toList();

    summaries.sort((a, b) {
      final balanceCompare = b.balance.compareTo(a.balance);
      if (balanceCompare != 0) return balanceCompare;
      return a.buyerName.compareTo(b.buyerName);
    });
    return summaries;
  }

  Future<List<Sale>> getSalesForBuyerAllTime(String buyerName) async {
    final snapshot = await _sales.where('buyer_name', isEqualTo: buyerName).get();
    final sales = snapshot.docs.map((doc) => Sale.fromMap(doc.id, doc.data())).toList();
    sales.sort((a, b) {
      final dateCompare = b.date.compareTo(a.date);
      if (dateCompare != 0) return dateCompare;
      return b.createdAt.compareTo(a.createdAt);
    });
    return sales;
  }

  Future<List<Payment>> getPaymentsForBuyerAllTime(String buyerName) async {
    final snapshot = await _payments.where('buyer_name', isEqualTo: buyerName).get();
    final payments = snapshot.docs.map((doc) => Payment.fromMap(doc.id, doc.data())).toList();
    payments.sort((a, b) {
      final dateCompare = b.date.compareTo(a.date);
      if (dateCompare != 0) return dateCompare;
      return b.createdAt.compareTo(a.createdAt);
    });
    return payments;
  }

  // ---------------- Reports aggregation ----------------

  Future<List<CategoryTotal>> getCategoryTotals(String startDate, String endDate) async {
    final sales = await getSalesForDateRange(startDate, endDate);
    final amountByCategory = <String, double>{};
    final kgByCategory = <String, double>{};
    for (final sale in sales) {
      amountByCategory[sale.category] = (amountByCategory[sale.category] ?? 0) + sale.amount;
      kgByCategory[sale.category] = (kgByCategory[sale.category] ?? 0) + sale.kilograms;
    }
    final totals = amountByCategory.entries
        .map((entry) => CategoryTotal(
              category: entry.key,
              amount: entry.value,
              kilograms: kgByCategory[entry.key] ?? 0.0,
            ))
        .toList();
    totals.sort((a, b) => b.amount.compareTo(a.amount));
    return totals;
  }

  Future<List<BuyerTotal>> getBuyerTotals(String startDate, String endDate) async {
    final sales = await getSalesForDateRange(startDate, endDate);
    final amountByBuyer = <String, double>{};
    final kgByBuyer = <String, double>{};
    for (final sale in sales) {
      amountByBuyer[sale.buyerName] = (amountByBuyer[sale.buyerName] ?? 0) + sale.amount;
      kgByBuyer[sale.buyerName] = (kgByBuyer[sale.buyerName] ?? 0) + sale.kilograms;
    }
    final totals = amountByBuyer.entries
        .map((entry) => BuyerTotal(
              buyerName: entry.key,
              amount: entry.value,
              kilograms: kgByBuyer[entry.key] ?? 0.0,
            ))
        .toList();
    totals.sort((a, b) => b.amount.compareTo(a.amount));
    return totals;
  }

  Future<List<DailyTotal>> getDailyTotals(DateTime start, DateTime end) async {
    final startDate = formatDbDate(start);
    final endDate = formatDbDate(end);
    final sales = await getSalesForDateRange(startDate, endDate);
    final totalsByDate = <String, double>{};
    for (final sale in sales) {
      totalsByDate[sale.date] = (totalsByDate[sale.date] ?? 0) + sale.amount;
    }
    return dbDatesInRange(start, end)
        .map((date) => DailyTotal(date: dbDateFormat.parse(date), amount: totalsByDate[date] ?? 0.0))
        .toList();
  }

  // ---------------- Investors / Expenses / Profit shares ----------------

  Future<void> insertInvestor(Investor investor) async {
    await _investors.add(investor.toMap());
  }

  Future<void> insertExpense(Expense expense) async {
    await _expenses.add(expense.toMap());
  }

  Future<void> insertProfitShare(ProfitShare share) async {
    await _profitShares.add(share.toMap());
  }

  Future<List<String>> getDistinctInvestorNames() async {
    final snapshot = await _investors.get();
    final names = <String>{for (final doc in snapshot.docs) doc.data()['name'] as String};
    final sorted = names.toList()..sort();
    return sorted;
  }

  Future<List<Expense>> getAllExpenses() async {
    final snapshot = await _expenses.get();
    final expenses = snapshot.docs.map((doc) => Expense.fromMap(doc.id, doc.data())).toList();
    _sortByDateDesc(expenses, (e) => e.date, (e) => e.createdAt);
    return expenses;
  }

  Future<List<Expense>> getExpenseList(String startDate, String endDate) async {
    final snapshot = await _expenses
        .where('date', isGreaterThanOrEqualTo: startDate)
        .where('date', isLessThanOrEqualTo: endDate)
        .get();
    final expenses = snapshot.docs.map((doc) => Expense.fromMap(doc.id, doc.data())).toList();
    _sortByDateDesc(expenses, (e) => e.date, (e) => e.createdAt);
    return expenses;
  }

  Future<List<Investor>> getInvestorList(String startDate, String endDate) async {
    final snapshot = await _investors
        .where('date', isGreaterThanOrEqualTo: startDate)
        .where('date', isLessThanOrEqualTo: endDate)
        .get();
    final investors = snapshot.docs.map((doc) => Investor.fromMap(doc.id, doc.data())).toList();
    _sortByDateDesc(investors, (i) => i.date, (i) => i.createdAt);
    return investors;
  }

  Future<List<ProfitShare>> getProfitShareList(String startDate, String endDate) async {
    final snapshot = await _profitShares
        .where('date', isGreaterThanOrEqualTo: startDate)
        .where('date', isLessThanOrEqualTo: endDate)
        .get();
    final shares = snapshot.docs.map((doc) => ProfitShare.fromMap(doc.id, doc.data())).toList();
    _sortByDateDesc(shares, (s) => s.date, (s) => s.createdAt);
    return shares;
  }

  void _sortByDateDesc<T>(
    List<T> items,
    String Function(T) date,
    String Function(T) createdAt,
  ) {
    items.sort((a, b) {
      final dateCompare = date(b).compareTo(date(a));
      if (dateCompare != 0) return dateCompare;
      return createdAt(b).compareTo(createdAt(a));
    });
  }

  /// All-time per-investor invested vs. shared totals, merged and sorted by name.
  Future<List<InvestorTotal>> getInvestorTotals() async {
    final investorSnapshot = await _investors.get();
    final shareSnapshot = await _profitShares.get();

    final investedByName = <String, double>{};
    for (final doc in investorSnapshot.docs) {
      final data = doc.data();
      final name = data['name'] as String;
      investedByName[name] = (investedByName[name] ?? 0) + (data['amount'] as num).toDouble();
    }
    final sharedByName = <String, double>{};
    for (final doc in shareSnapshot.docs) {
      final data = doc.data();
      final name = data['investor_name'] as String;
      sharedByName[name] = (sharedByName[name] ?? 0) + (data['amount'] as num).toDouble();
    }

    final totals = investedByName.entries.map((entry) {
      final name = entry.key;
      final invested = entry.value;
      final shared = sharedByName.remove(name) ?? 0.0;
      return InvestorTotal(name: name, invested: invested, shared: shared, net: invested - shared);
    }).toList();

    // Investors with profit-share rows but no matching investment row (shouldn't normally
    // happen since the UI only offers known investor names, but keep totals complete).
    for (final entry in sharedByName.entries) {
      totals.add(InvestorTotal(name: entry.key, invested: 0, shared: entry.value, net: -entry.value));
    }

    return totals..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<({double totalInvested, double totalExpenses, double totalShared})> getFinanceTotals(
    String startDate,
    String endDate,
  ) async {
    final investors = await getInvestorList(startDate, endDate);
    final expenses = await getExpenseList(startDate, endDate);
    final shares = await getProfitShareList(startDate, endDate);
    return (
      totalInvested: investors.fold(0.0, (total, i) => total + i.amount),
      totalExpenses: expenses.fold(0.0, (total, e) => total + e.amount),
      totalShared: shares.fold(0.0, (total, s) => total + s.amount),
    );
  }

  Future<({double totalInvestedAllTime, double totalSharedAllTime})> getAllTimeInvestedAndShared() async {
    final investorSnapshot = await _investors.get();
    final shareSnapshot = await _profitShares.get();
    final totalInvested = investorSnapshot.docs
        .fold(0.0, (total, doc) => total + (doc.data()['amount'] as num).toDouble());
    final totalShared = shareSnapshot.docs
        .fold(0.0, (total, doc) => total + (doc.data()['amount'] as num).toDouble());
    return (totalInvestedAllTime: totalInvested, totalSharedAllTime: totalShared);
  }
}
