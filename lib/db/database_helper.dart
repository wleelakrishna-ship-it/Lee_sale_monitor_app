import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/buyer_overview.dart';
import '../models/buyer_summary.dart';
import '../models/category_rate.dart';
import '../models/finance.dart';
import '../models/payment.dart';
import '../models/report_data.dart';
import '../models/sale.dart';
import '../utils/date_utils.dart';

/// Local-first data store (SQLite via sqflite) — every read/write is instant and
/// works fully offline. Every table carries three sync-bookkeeping columns used by
/// [SyncService] to push/pull changes to Firestore on demand (see sync_service.dart):
/// `updated_at` (drives conflict resolution and "what changed since last sync"),
/// `deleted` (soft-delete, so a deletion can still be synced later), and `synced`
/// (0 = has local changes not yet pushed).
class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  static const _uuid = Uuid();
  static String newId() => _uuid.v4();
  static String _now() => DateTime.now().toIso8601String();

  Database? _database;

  Future<Database> get database async {
    final existing = _database;
    if (existing != null) return existing;
    final db = await _initDatabase();
    _database = db;
    return db;
  }

  // Version 3 fixed a schema-version downgrade bug (see git history) by rebuilding
  // the database from scratch — safe at the time since this app had no local-first
  // data yet. From version 3 onward, this is the real source of truth for live
  // business data, so every later bump MUST migrate additively (ALTER TABLE, never
  // DROP) or real data gets silently wiped on the next app open.
  static const _schemaVersion = 4;

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'fish_app.db');
    return openDatabase(
      path,
      version: _schemaVersion,
      onCreate: (db, version) => _createSchema(db),
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 3) {
          // Pre-3 schema (integer ids, no sync columns) is fundamentally
          // incompatible — nothing meaningful to preserve, so rebuild clean.
          await _rebuildSchema(db);
          return;
        }
        if (oldVersion < 4) {
          await db.execute(
            'ALTER TABLE category_rates ADD COLUMN commission_per_kg REAL NOT NULL DEFAULT 0',
          );
        }
      },
      onDowngrade: (db, oldVersion, newVersion) => _rebuildSchema(db),
    );
  }

  static const _tableNames = [
    'category_rates',
    'sales',
    'payments',
    'investors',
    'expenses',
    'profit_shares',
  ];

  /// Drops any tables left over from an older, incompatible schema (e.g. this app's
  /// original integer-id version) and recreates them fresh. Any data that was already
  /// pushed to Firestore before the schema changed can still be pulled back in with
  /// the sync button; a clean rebuild is far simpler and safer than trying to migrate
  /// integer ids into the new text-id, sync-tracked schema row by row.
  Future<void> _rebuildSchema(Database db) async {
    for (final table in _tableNames) {
      await db.execute('DROP TABLE IF EXISTS $table');
    }
    await _createSchema(db);
  }

  Future<void> _createSchema(Database db) async {
    const syncColumns = '''
      updated_at TEXT NOT NULL,
      deleted INTEGER NOT NULL DEFAULT 0,
      synced INTEGER NOT NULL DEFAULT 0
    ''';
    await db.execute('''
      CREATE TABLE category_rates (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        category TEXT NOT NULL,
        rate_per_kg REAL NOT NULL,
        commission_per_kg REAL NOT NULL DEFAULT 0,
        $syncColumns
      )
    ''');
    await db.execute('''
      CREATE TABLE sales (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        buyer_name TEXT NOT NULL,
        category TEXT NOT NULL,
        rate_per_kg REAL NOT NULL,
        kilograms REAL NOT NULL,
        amount REAL NOT NULL,
        created_at TEXT NOT NULL,
        $syncColumns
      )
    ''');
    await db.execute('''
      CREATE TABLE payments (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        buyer_name TEXT NOT NULL,
        amount_given REAL NOT NULL,
        created_at TEXT NOT NULL,
        $syncColumns
      )
    ''');
    await db.execute('''
      CREATE TABLE investors (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        note TEXT,
        created_at TEXT NOT NULL,
        $syncColumns
      )
    ''');
    await db.execute('''
      CREATE TABLE expenses (
        id TEXT PRIMARY KEY,
        description TEXT NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        $syncColumns
      )
    ''');
    await db.execute('''
      CREATE TABLE profit_shares (
        id TEXT PRIMARY KEY,
        investor_name TEXT NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        note TEXT,
        created_at TEXT NOT NULL,
        $syncColumns
      )
    ''');
    await db.execute('CREATE INDEX idx_sales_date ON sales(date)');
    await db.execute('CREATE INDEX idx_payments_date ON payments(date)');
    await db.execute('CREATE INDEX idx_category_rates_date ON category_rates(date)');
    await db.execute('CREATE INDEX idx_sales_updated ON sales(updated_at)');
    await db.execute('CREATE INDEX idx_payments_updated ON payments(updated_at)');
    await db.execute('CREATE INDEX idx_category_rates_updated ON category_rates(updated_at)');
    await db.execute('CREATE INDEX idx_investors_updated ON investors(updated_at)');
    await db.execute('CREATE INDEX idx_expenses_updated ON expenses(updated_at)');
    await db.execute('CREATE INDEX idx_profit_shares_updated ON profit_shares(updated_at)');
  }

  // ---------------- Category rates ----------------

  Future<void> insertCategoryRate(CategoryRate rate) async {
    final db = await database;
    final map = rate.toMap()
      ..['id'] = newId()
      ..['updated_at'] = _now()
      ..['deleted'] = 0
      ..['synced'] = 0;
    await db.insert('category_rates', map);
  }

  Future<void> updateCategoryRate(CategoryRate rate) async {
    final db = await database;
    final map = rate.toMap()
      ..['updated_at'] = _now()
      ..['synced'] = 0;
    await db.update('category_rates', map, where: 'id = ?', whereArgs: [rate.id]);
  }

  Future<void> deleteCategoryRate(String id) async {
    final db = await database;
    await db.update(
      'category_rates',
      {'deleted': 1, 'updated_at': _now(), 'synced': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<CategoryRate>> getRatesForDate(String date) async {
    final db = await database;
    final rows = await db.query(
      'category_rates',
      where: 'date = ? AND deleted = 0',
      whereArgs: [date],
      orderBy: 'category ASC',
    );
    return rows.map((row) => CategoryRate.fromMap(row['id'] as String, row)).toList();
  }

  /// Rates from the most recent date strictly before [date], for "copy yesterday's rates".
  Future<List<CategoryRate>> getMostRecentRatesBefore(String date) async {
    final db = await database;
    final latest = await db.rawQuery(
      'SELECT MAX(date) as max_date FROM category_rates WHERE date < ? AND deleted = 0',
      [date],
    );
    final maxDate = latest.first['max_date'] as String?;
    if (maxDate == null) return [];
    return getRatesForDate(maxDate);
  }

  // ---------------- Sales ----------------

  Future<void> insertSales(List<Sale> sales) async {
    final db = await database;
    final batch = db.batch();
    final now = _now();
    for (final sale in sales) {
      final map = sale.toMap()
        ..['id'] = newId()
        ..['updated_at'] = now
        ..['deleted'] = 0
        ..['synced'] = 0;
      batch.insert('sales', map);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Sale>> getSalesForDateRange(String startDate, String endDate) async {
    final db = await database;
    final rows = await db.query(
      'sales',
      where: 'date BETWEEN ? AND ? AND deleted = 0',
      whereArgs: [startDate, endDate],
      orderBy: 'created_at ASC',
    );
    return rows.map((row) => Sale.fromMap(row['id'] as String, row)).toList();
  }

  Future<void> updateSale(Sale sale) async {
    final db = await database;
    final map = sale.toMap()
      ..['updated_at'] = _now()
      ..['synced'] = 0;
    await db.update('sales', map, where: 'id = ?', whereArgs: [sale.id]);
  }

  Future<void> deleteSale(String id) async {
    final db = await database;
    await db.update(
      'sales',
      {'deleted': 1, 'updated_at': _now(), 'synced': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Sale>> getSalesForBuyerOnDate(String date, String buyerName) async {
    final db = await database;
    final rows = await db.query(
      'sales',
      where: 'date = ? AND buyer_name = ? AND deleted = 0',
      whereArgs: [date, buyerName],
      orderBy: 'created_at ASC',
    );
    return rows.map((row) => Sale.fromMap(row['id'] as String, row)).toList();
  }

  // ---------------- Payments ----------------

  Future<void> insertPayment(Payment payment) async {
    final db = await database;
    final map = payment.toMap()
      ..['id'] = newId()
      ..['updated_at'] = _now()
      ..['deleted'] = 0
      ..['synced'] = 0;
    await db.insert('payments', map);
  }

  Future<List<Payment>> getPaymentsForDateRange(String startDate, String endDate) async {
    final db = await database;
    final rows = await db.query(
      'payments',
      where: 'date BETWEEN ? AND ? AND deleted = 0',
      whereArgs: [startDate, endDate],
      orderBy: 'created_at ASC',
    );
    return rows.map((row) => Payment.fromMap(row['id'] as String, row)).toList();
  }

  Future<void> updatePayment(Payment payment) async {
    final db = await database;
    final map = payment.toMap()
      ..['updated_at'] = _now()
      ..['synced'] = 0;
    await db.update('payments', map, where: 'id = ?', whereArgs: [payment.id]);
  }

  Future<void> deletePayment(String id) async {
    final db = await database;
    await db.update(
      'payments',
      {'deleted': 1, 'updated_at': _now(), 'synced': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Payment>> getPaymentsForBuyerOnDate(String date, String buyerName) async {
    final db = await database;
    final rows = await db.query(
      'payments',
      where: 'date = ? AND buyer_name = ? AND deleted = 0',
      whereArgs: [date, buyerName],
      orderBy: 'created_at ASC',
    );
    return rows.map((row) => Payment.fromMap(row['id'] as String, row)).toList();
  }

  // ---------------- Buyers ----------------

  Future<List<String>> getDistinctBuyerNames() async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT DISTINCT buyer_name FROM sales WHERE deleted = 0 ORDER BY buyer_name ASC',
    );
    return rows.map((row) => row['buyer_name'] as String).toList();
  }

  Future<List<BuyerSummary>> getBuyerSummariesForDate(String date) async {
    final db = await database;
    final salesRows = await db.rawQuery(
      '''
      SELECT buyer_name, SUM(amount) as total, SUM(kilograms) as total_kg
      FROM sales WHERE date = ? AND deleted = 0 GROUP BY buyer_name
      ''',
      [date],
    );
    final paymentRows = await db.rawQuery(
      'SELECT buyer_name, SUM(amount_given) as given FROM payments WHERE date = ? AND deleted = 0 GROUP BY buyer_name',
      [date],
    );
    final givenByBuyer = <String, double>{
      for (final row in paymentRows)
        row['buyer_name'] as String: (row['given'] as num?)?.toDouble() ?? 0.0,
    };

    return salesRows.map((row) {
      final buyerName = row['buyer_name'] as String;
      return BuyerSummary(
        buyerName: buyerName,
        total: (row['total'] as num?)?.toDouble() ?? 0.0,
        totalKilograms: (row['total_kg'] as num?)?.toDouble() ?? 0.0,
        given: givenByBuyer[buyerName] ?? 0.0,
      );
    }).toList()
      ..sort((a, b) => a.buyerName.compareTo(b.buyerName));
  }

  Future<({double totalAmount, double totalKg, int buyerCount})> getDayTotals(String date) async {
    final db = await database;
    final rows = await db.rawQuery(
      '''
      SELECT SUM(amount) as total_amount, SUM(kilograms) as total_kg,
             COUNT(DISTINCT buyer_name) as buyer_count
      FROM sales WHERE date = ? AND deleted = 0
      ''',
      [date],
    );
    final row = rows.first;
    return (
      totalAmount: (row['total_amount'] as num?)?.toDouble() ?? 0.0,
      totalKg: (row['total_kg'] as num?)?.toDouble() ?? 0.0,
      buyerCount: (row['buyer_count'] as num?)?.toInt() ?? 0,
    );
  }

  /// All-time (not date-filtered) per-buyer totals, for the Buyers/ledger screens.
  Future<List<BuyerOverallSummary>> getAllBuyerOverallSummaries() async {
    final db = await database;
    final salesRows = await db.rawQuery(
      'SELECT buyer_name, SUM(amount) as total, SUM(kilograms) as total_kg FROM sales WHERE deleted = 0 GROUP BY buyer_name',
    );
    final paymentRows = await db.rawQuery(
      'SELECT buyer_name, SUM(amount_given) as given FROM payments WHERE deleted = 0 GROUP BY buyer_name',
    );
    final givenByBuyer = <String, double>{
      for (final row in paymentRows)
        row['buyer_name'] as String: (row['given'] as num?)?.toDouble() ?? 0.0,
    };

    final summaries = salesRows.map((row) {
      final buyerName = row['buyer_name'] as String;
      return BuyerOverallSummary(
        buyerName: buyerName,
        totalAmount: (row['total'] as num?)?.toDouble() ?? 0.0,
        totalKilograms: (row['total_kg'] as num?)?.toDouble() ?? 0.0,
        totalGiven: givenByBuyer[buyerName] ?? 0.0,
      );
    }).toList();

    summaries.sort((a, b) {
      final balanceCompare = b.balance.compareTo(a.balance);
      if (balanceCompare != 0) return balanceCompare;
      return a.buyerName.compareTo(b.buyerName);
    });
    return summaries;
  }

  Future<List<Sale>> getSalesForBuyerAllTime(String buyerName) async {
    final db = await database;
    final rows = await db.query(
      'sales',
      where: 'buyer_name = ? AND deleted = 0',
      whereArgs: [buyerName],
      orderBy: 'date DESC, created_at DESC',
    );
    return rows.map((row) => Sale.fromMap(row['id'] as String, row)).toList();
  }

  Future<List<Payment>> getPaymentsForBuyerAllTime(String buyerName) async {
    final db = await database;
    final rows = await db.query(
      'payments',
      where: 'buyer_name = ? AND deleted = 0',
      whereArgs: [buyerName],
      orderBy: 'date DESC, created_at DESC',
    );
    return rows.map((row) => Payment.fromMap(row['id'] as String, row)).toList();
  }

  // ---------------- Reports aggregation ----------------

  Future<List<CategoryTotal>> getCategoryTotals(String startDate, String endDate) async {
    final db = await database;
    final rows = await db.rawQuery(
      '''
      SELECT category, SUM(amount) as total, SUM(kilograms) as total_kg
      FROM sales WHERE date BETWEEN ? AND ? AND deleted = 0
      GROUP BY category ORDER BY total DESC
      ''',
      [startDate, endDate],
    );
    return rows
        .map((row) => CategoryTotal(
              category: row['category'] as String,
              amount: (row['total'] as num?)?.toDouble() ?? 0.0,
              kilograms: (row['total_kg'] as num?)?.toDouble() ?? 0.0,
            ))
        .toList();
  }

  Future<List<BuyerTotal>> getBuyerTotals(String startDate, String endDate) async {
    final db = await database;
    final rows = await db.rawQuery(
      '''
      SELECT buyer_name, SUM(amount) as total, SUM(kilograms) as total_kg
      FROM sales WHERE date BETWEEN ? AND ? AND deleted = 0
      GROUP BY buyer_name ORDER BY total DESC
      ''',
      [startDate, endDate],
    );
    return rows
        .map((row) => BuyerTotal(
              buyerName: row['buyer_name'] as String,
              amount: (row['total'] as num?)?.toDouble() ?? 0.0,
              kilograms: (row['total_kg'] as num?)?.toDouble() ?? 0.0,
            ))
        .toList();
  }

  Future<List<DailyTotal>> getDailyTotals(DateTime start, DateTime end) async {
    final db = await database;
    final startDate = formatDbDate(start);
    final endDate = formatDbDate(end);
    final rows = await db.rawQuery(
      '''
      SELECT date, SUM(amount) as total FROM sales
      WHERE date BETWEEN ? AND ? AND deleted = 0 GROUP BY date
      ''',
      [startDate, endDate],
    );
    final totalsByDate = <String, double>{
      for (final row in rows) row['date'] as String: (row['total'] as num?)?.toDouble() ?? 0.0,
    };
    return dbDatesInRange(start, end)
        .map((date) => DailyTotal(date: dbDateFormat.parse(date), amount: totalsByDate[date] ?? 0.0))
        .toList();
  }

  // ---------------- Investors / Expenses / Profit shares ----------------

  Future<void> insertInvestor(Investor investor) async {
    final db = await database;
    final map = investor.toMap()
      ..['id'] = newId()
      ..['updated_at'] = _now()
      ..['deleted'] = 0
      ..['synced'] = 0;
    await db.insert('investors', map);
  }

  Future<void> updateInvestor(Investor investor) async {
    final db = await database;
    final map = investor.toMap()
      ..['updated_at'] = _now()
      ..['synced'] = 0;
    await db.update('investors', map, where: 'id = ?', whereArgs: [investor.id]);
  }

  Future<void> deleteInvestor(String id) async {
    final db = await database;
    await db.update(
      'investors',
      {'deleted': 1, 'updated_at': _now(), 'synced': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// All individual investment records for one investor (all-time), for the
  /// investor detail/edit screen.
  Future<List<Investor>> getInvestorRecords(String name) async {
    final db = await database;
    final rows = await db.query(
      'investors',
      where: 'name = ? AND deleted = 0',
      whereArgs: [name],
      orderBy: 'date DESC, created_at DESC',
    );
    return rows.map((row) => Investor.fromMap(row['id'] as String, row)).toList();
  }

  Future<void> insertExpense(Expense expense) async {
    final db = await database;
    final map = expense.toMap()
      ..['id'] = newId()
      ..['updated_at'] = _now()
      ..['deleted'] = 0
      ..['synced'] = 0;
    await db.insert('expenses', map);
  }

  Future<void> insertProfitShare(ProfitShare share) async {
    final db = await database;
    final map = share.toMap()
      ..['id'] = newId()
      ..['updated_at'] = _now()
      ..['deleted'] = 0
      ..['synced'] = 0;
    await db.insert('profit_shares', map);
  }

  Future<List<String>> getDistinctInvestorNames() async {
    final db = await database;
    final rows = await db
        .rawQuery('SELECT DISTINCT name FROM investors WHERE deleted = 0 ORDER BY name ASC');
    return rows.map((row) => row['name'] as String).toList();
  }

  Future<List<Expense>> getAllExpenses() async {
    final db = await database;
    final rows =
        await db.query('expenses', where: 'deleted = 0', orderBy: 'date DESC, created_at DESC');
    return rows.map((row) => Expense.fromMap(row['id'] as String, row)).toList();
  }

  Future<List<Expense>> getExpenseList(String startDate, String endDate) async {
    final db = await database;
    final rows = await db.query(
      'expenses',
      where: 'date BETWEEN ? AND ? AND deleted = 0',
      whereArgs: [startDate, endDate],
      orderBy: 'date DESC, created_at DESC',
    );
    return rows.map((row) => Expense.fromMap(row['id'] as String, row)).toList();
  }

  Future<List<Investor>> getInvestorList(String startDate, String endDate) async {
    final db = await database;
    final rows = await db.query(
      'investors',
      where: 'date BETWEEN ? AND ? AND deleted = 0',
      whereArgs: [startDate, endDate],
      orderBy: 'date DESC, created_at DESC',
    );
    return rows.map((row) => Investor.fromMap(row['id'] as String, row)).toList();
  }

  Future<List<ProfitShare>> getProfitShareList(String startDate, String endDate) async {
    final db = await database;
    final rows = await db.query(
      'profit_shares',
      where: 'date BETWEEN ? AND ? AND deleted = 0',
      whereArgs: [startDate, endDate],
      orderBy: 'date DESC, created_at DESC',
    );
    return rows.map((row) => ProfitShare.fromMap(row['id'] as String, row)).toList();
  }

  /// All-time per-investor invested vs. shared totals, merged and sorted by name.
  Future<List<InvestorTotal>> getInvestorTotals() async {
    final db = await database;
    final investedRows = await db
        .rawQuery('SELECT name, SUM(amount) as total FROM investors WHERE deleted = 0 GROUP BY name');
    final sharedRows = await db.rawQuery(
      'SELECT investor_name, SUM(amount) as total FROM profit_shares WHERE deleted = 0 GROUP BY investor_name',
    );
    final sharedByName = <String, double>{
      for (final row in sharedRows)
        row['investor_name'] as String: (row['total'] as num?)?.toDouble() ?? 0.0,
    };

    final totals = investedRows.map((row) {
      final name = row['name'] as String;
      final invested = (row['total'] as num?)?.toDouble() ?? 0.0;
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
    final db = await database;
    final investedRows = await db.rawQuery(
      'SELECT SUM(amount) as total FROM investors WHERE date BETWEEN ? AND ? AND deleted = 0',
      [startDate, endDate],
    );
    final expenseRows = await db.rawQuery(
      'SELECT SUM(amount) as total FROM expenses WHERE date BETWEEN ? AND ? AND deleted = 0',
      [startDate, endDate],
    );
    final sharedRows = await db.rawQuery(
      'SELECT SUM(amount) as total FROM profit_shares WHERE date BETWEEN ? AND ? AND deleted = 0',
      [startDate, endDate],
    );
    return (
      totalInvested: (investedRows.first['total'] as num?)?.toDouble() ?? 0.0,
      totalExpenses: (expenseRows.first['total'] as num?)?.toDouble() ?? 0.0,
      totalShared: (sharedRows.first['total'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Future<({double totalInvestedAllTime, double totalSharedAllTime})> getAllTimeInvestedAndShared() async {
    final db = await database;
    final investedRows =
        await db.rawQuery('SELECT SUM(amount) as total FROM investors WHERE deleted = 0');
    final sharedRows =
        await db.rawQuery('SELECT SUM(amount) as total FROM profit_shares WHERE deleted = 0');
    return (
      totalInvestedAllTime: (investedRows.first['total'] as num?)?.toDouble() ?? 0.0,
      totalSharedAllTime: (sharedRows.first['total'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
