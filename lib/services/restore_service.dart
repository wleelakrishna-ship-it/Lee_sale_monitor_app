import 'package:sqflite/sqflite.dart';

import '../db/database_helper.dart';

class RestoreResult {
  final int merged;

  const RestoreResult({required this.merged});
}

/// Thrown when the picked file doesn't look like one of this app's own backups.
class InvalidBackupException implements Exception {}

/// Merges another device's backup file (created by [BackupService]) into the local
/// database — the counterpart to the Sync button's download step, but reading from a
/// file instead of Firestore. Uses the exact same "newer wins" rule: a row from the
/// backup only overwrites a local row if its `updated_at` is actually newer, so
/// nothing already on this phone is ever lost by restoring someone else's backup.
class RestoreService {
  static const _tables = [
    'category_rates',
    'sales',
    'payments',
    'investors',
    'expenses',
    'profit_shares',
  ];

  Future<RestoreResult> restoreFrom(String backupFilePath) async {
    final localDb = await DatabaseHelper.instance.database;
    final backupDb = await openDatabase(backupFilePath, readOnly: true);

    var merged = 0;
    try {
      final tableCheck = await backupDb.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name IN "
        "('category_rates', 'sales', 'payments', 'investors', 'expenses', 'profit_shares')",
      );
      if (tableCheck.length < _tables.length) {
        throw InvalidBackupException();
      }

      for (final table in _tables) {
        final backupRows = await backupDb.query(table);
        for (final row in backupRows) {
          final id = row['id'] as String?;
          final updatedAt = row['updated_at'] as String?;
          if (id == null || updatedAt == null) continue;

          final existing =
              await localDb.query(table, where: 'id = ?', whereArgs: [id], limit: 1);
          final localUpdatedAt =
              existing.isEmpty ? null : existing.first['updated_at'] as String?;
          if (localUpdatedAt != null && localUpdatedAt.compareTo(updatedAt) >= 0) {
            continue;
          }

          final localRow = <String, Object?>{
            for (final entry in row.entries) entry.key: entry.value,
          };
          // Came in from a file, not confirmed in Firestore yet from this device's
          // point of view — mark dirty so the next Sync pushes it up too.
          localRow['synced'] = 0;

          await localDb.insert(table, localRow, conflictAlgorithm: ConflictAlgorithm.replace);
          merged++;
        }
      }
    } finally {
      await backupDb.close();
    }

    return RestoreResult(merged: merged);
  }
}
