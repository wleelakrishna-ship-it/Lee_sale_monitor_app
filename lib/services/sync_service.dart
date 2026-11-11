import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../db/database_helper.dart';

class SyncResult {
  final int uploaded;
  final int downloaded;

  const SyncResult({required this.uploaded, required this.downloaded});
}

/// Two-way sync between the local SQLite store and Firestore, run only when the user
/// taps the sync button (never automatically). Each local row carries `updated_at`,
/// `deleted` (soft-delete) and `synced` (0 = has local changes not yet pushed); see
/// database_helper.dart for the schema this depends on.
///
/// Algorithm per table:
/// 1. Upload every locally dirty row (`synced = 0`) to `collection(table).doc(id)`,
///    then mark it synced (and hard-delete it locally if it was a soft-deleted row —
///    the deletion has now been pushed, so there's no reason to keep the tombstone).
/// 2. Download anything changed remotely since the last sync (`updated_at` greater
///    than the stored checkpoint, or the whole collection on the very first sync) and
///    upsert it locally — but only when the remote copy is actually newer than the
///    local one, which is the whole of the last-write-wins conflict rule. Docs this
///    device just uploaded are skipped on the way back down to avoid redundant churn.
class SyncService {
  SyncService._internal();
  static final SyncService instance = SyncService._internal();

  static const _lastSyncedKey = 'last_synced_at';
  static const _timeout = Duration(seconds: 20);
  static const _tables = [
    'category_rates',
    'sales',
    'payments',
    'investors',
    'expenses',
    'profit_shares',
  ];

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<DateTime?> getLastSyncedAt() async {
    final prefs = await SharedPreferences.getInstance();
    final iso = prefs.getString(_lastSyncedKey);
    return iso == null ? null : DateTime.tryParse(iso);
  }

  Future<void> _setLastSyncedAt(String iso) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSyncedKey, iso);
  }

  Future<SyncResult> sync() async {
    final db = await DatabaseHelper.instance.database;
    final prefs = await SharedPreferences.getInstance();
    final lastSyncedAt = prefs.getString(_lastSyncedKey);

    var uploaded = 0;
    var downloaded = 0;
    String? newCheckpoint = lastSyncedAt;

    void noteCheckpoint(String updatedAt) {
      if (newCheckpoint == null || updatedAt.compareTo(newCheckpoint!) > 0) {
        newCheckpoint = updatedAt;
      }
    }

    for (final table in _tables) {
      final uploadedIds = <String>{};

      // ---- Upload: push every locally dirty row ----
      final dirtyRows = await db.query(table, where: 'synced = 0');
      for (final row in dirtyRows) {
        final id = row['id'] as String;
        final updatedAt = row['updated_at'] as String;
        final payload = <String, Object?>{
          for (final entry in row.entries)
            if (entry.key != 'id' && entry.key != 'synced') entry.key: entry.value,
        };
        payload['deleted'] = row['deleted'] == 1;

        await _firestore.collection(table).doc(id).set(payload).timeout(_timeout);
        uploadedIds.add(id);
        noteCheckpoint(updatedAt);
        uploaded++;

        if (row['deleted'] == 1) {
          await db.delete(table, where: 'id = ?', whereArgs: [id]);
        } else {
          await db.update(table, {'synced': 1}, where: 'id = ?', whereArgs: [id]);
        }
      }

      // ---- Download: pull anything changed remotely since the last sync ----
      final query = lastSyncedAt == null
          ? _firestore.collection(table)
          : _firestore.collection(table).where('updated_at', isGreaterThan: lastSyncedAt);
      final snapshot = await query.get().timeout(_timeout);

      for (final doc in snapshot.docs) {
        if (uploadedIds.contains(doc.id)) continue;
        final data = doc.data();
        // Docs written before this sync feature existed may have neither field — treat
        // them as very old so they still come down on the first sync instead of being
        // skipped, without ever blocking a genuinely newer local edit.
        final remoteUpdatedAt = (data['updated_at'] as String?) ??
            (data['created_at'] as String?) ??
            '1970-01-01T00:00:00.000';

        final existing = await db.query(table, where: 'id = ?', whereArgs: [doc.id], limit: 1);
        final localUpdatedAt = existing.isEmpty ? null : existing.first['updated_at'] as String?;
        if (localUpdatedAt != null && localUpdatedAt.compareTo(remoteUpdatedAt) >= 0) {
          continue;
        }

        final localRow = <String, Object?>{
          for (final entry in data.entries) entry.key: entry.value,
        };
        localRow['id'] = doc.id;
        localRow['updated_at'] = remoteUpdatedAt;
        localRow['deleted'] = data['deleted'] == true ? 1 : 0;
        localRow['synced'] = 1;

        await db.insert(table, localRow, conflictAlgorithm: ConflictAlgorithm.replace);
        noteCheckpoint(remoteUpdatedAt);
        downloaded++;
      }
    }

    if (newCheckpoint != null) {
      await _setLastSyncedAt(newCheckpoint!);
    }

    return SyncResult(uploaded: uploaded, downloaded: downloaded);
  }
}
