import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:lee_sale_monitor/core/config/env.dart';
import 'package:lee_sale_monitor/db/database_helper.dart';
import 'package:lee_sale_monitor/services/auth_service.dart';

class CloudBackupResult {
  final Map<String, int> uploaded;
  final int total;
  final DateTime at;
  const CloudBackupResult({required this.uploaded, required this.total, required this.at});
}

class CloudRestoreResult {
  final Map<String, int> merged;
  final int total;
  const CloudRestoreResult({required this.merged, required this.total});
}

class _TableSpec {
  final String local;
  final String remote;
  final List<String> dataColumns; // local columns to send (besides id)
  final List<String> timestampColumns; // local columns that are ISO timestamps
  const _TableSpec(this.local, this.remote, this.dataColumns, this.timestampColumns);
}

class CloudBackupService {
  CloudBackupService._internal();
  static final CloudBackupService instance = CloudBackupService._internal();

  static const _lastBackupKey = 'last_cloud_backup_at';

  static const _tables = <_TableSpec>[
    _TableSpec('category_rates', 'lee_sale_category_rates',
        ['date', 'category', 'rate_per_kg', 'commission_per_kg', 'updated_at', 'deleted'],
        ['updated_at']),
    _TableSpec('sales', 'lee_sale_sales',
        ['date', 'buyer_name', 'category', 'rate_per_kg', 'kilograms', 'amount', 'created_at', 'commission_per_kg', 'updated_at', 'deleted'],
        ['created_at', 'updated_at']),
    _TableSpec('payments', 'lee_sale_payments',
        ['date', 'buyer_name', 'amount_given', 'created_at', 'updated_at', 'deleted'],
        ['created_at', 'updated_at']),
    _TableSpec('investors', 'lee_sale_investors',
        ['name', 'amount', 'date', 'note', 'created_at', 'updated_at', 'deleted'],
        ['created_at', 'updated_at']),
    _TableSpec('expenses', 'lee_sale_expenses',
        ['description', 'amount', 'date', 'created_at', 'updated_at', 'deleted'],
        ['created_at', 'updated_at']),
    _TableSpec('profit_shares', 'lee_sale_profit_shares',
        ['investor_name', 'amount', 'date', 'note', 'created_at', 'updated_at', 'deleted'],
        ['created_at', 'updated_at']),
  ];

  bool get isAvailable => Env.hasSupabaseConfig;

  String? get currentUid => AuthService.instance.currentUid;

  SupabaseClient get _client => Supabase.instance.client;

  String _toUtcIso(String localIso) {
    // Local ISO strings have no offset; parse as local, convert to UTC.
    try {
      return DateTime.parse(localIso).toUtc().toIso8601String();
    } catch (_) {
      return localIso;
    }
  }

  String _toLocalIso(String remoteIso) {
    try {
      return DateTime.parse(remoteIso).toLocal().toIso8601String();
    } catch (_) {
      return remoteIso;
    }
  }

  Future<CloudBackupResult> backup() async {
    final uid = currentUid;
    if (uid == null) throw StateError('Not signed in');
    if (!isAvailable) throw StateError('Supabase not configured');

    final db = await DatabaseHelper.instance.database;
    final uploaded = <String, int>{};
    int total = 0;

    for (final spec in _tables) {
      final rows = await db.query(spec.local);
      final payload = <Map<String, dynamic>>[];
      for (final row in rows) {
        final id = row['id'] as String?;
        if (id == null) continue;
        final map = <String, dynamic>{'owner_uid': uid, 'id': id};
        for (final col in spec.dataColumns) {
          var value = row[col];
          if (value == null) {
            map[col] = null;
            continue;
          }
          if (spec.timestampColumns.contains(col) && value is String) {
            map[col] = _toUtcIso(value);
          } else if (col == 'deleted') {
            map[col] = (value == 1 || value == true);
          } else {
            map[col] = value;
          }
        }
        payload.add(map);
      }

      // Upsert in chunks of 500.
      for (var i = 0; i < payload.length; i += 500) {
        final chunk = payload.sublist(i, (i + 500).clamp(0, payload.length));
        if (chunk.isEmpty) continue;
        await _client
            .from(spec.remote)
            .upsert(chunk, onConflict: 'owner_uid,id');
      }

      // Mark local rows synced.
      await db.update(spec.local, {'synced': 1});

      uploaded[spec.local] = payload.length;
      total += payload.length;
    }

    // Write a backup-run log row.
    final counts = <String, int>{for (final e in uploaded.entries) e.key: e.value};
    await _client.from('lee_sale_backups').insert({
      'owner_uid': uid,
      'app_version': '1.0.2',
      'row_counts': counts,
    });

    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastBackupKey, now.toIso8601String());

    return CloudBackupResult(uploaded: uploaded, total: total, at: now);
  }

  Future<CloudRestoreResult> restore() async {
    final uid = currentUid;
    if (uid == null) throw StateError('Not signed in');
    if (!isAvailable) throw StateError('Supabase not configured');

    final db = await DatabaseHelper.instance.database;
    final merged = <String, int>{};
    int total = 0;

    for (final spec in _tables) {
      int offset = 0;
      int tableMerged = 0;
      while (true) {
        final page = await _client
            .from(spec.remote)
            .select()
            .eq('owner_uid', uid)
            .range(offset, offset + 999);
        final rows = page as List<dynamic>;
        if (rows.isEmpty) break;

        for (final raw in rows) {
          final row = Map<String, dynamic>.from(raw as Map);
          final id = row['id'] as String?;
          if (id == null) continue;

          final remoteUpdated = row['updated_at'] as String?;
          if (remoteUpdated == null) continue;

          final existing = await db.query(spec.local,
              where: 'id = ?', whereArgs: [id], limit: 1);
          final localUpdated = existing.isEmpty
              ? null
              : existing.first['updated_at'] as String?;

          if (localUpdated != null &&
              DateTime.parse(localUpdated)
                  .compareTo(DateTime.parse(remoteUpdated)) >=
                  0) {
            continue;
          }

          final localRow = <String, Object?>{'id': id, 'synced': 1};
          for (final col in spec.dataColumns) {
            if (col == 'updated_at' || col == 'deleted') continue;
            if (row.containsKey(col)) localRow[col] = row[col];
          }
          localRow['updated_at'] = _toLocalIso(remoteUpdated);
          localRow['deleted'] = (row['deleted'] == true) ? 1 : 0;

          await db.insert(spec.local, localRow,
              conflictAlgorithm: ConflictAlgorithm.replace);
          tableMerged++;
        }

        offset += rows.length;
        if (rows.length < 1000) break;
      }
      merged[spec.local] = tableMerged;
      total += tableMerged;
    }

    return CloudRestoreResult(merged: merged, total: total);
  }

  Future<DateTime?> getLastBackupAt() async {
    final prefs = await SharedPreferences.getInstance();
    final iso = prefs.getString(_lastBackupKey);
    return iso == null ? null : DateTime.tryParse(iso);
  }
}