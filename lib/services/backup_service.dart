import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../db/database_helper.dart';

/// Makes a point-in-time copy of the local database and hands it to the OS share
/// sheet, so the user can save or send it anywhere — Google Drive, email, a file
/// manager's folder, WhatsApp to themselves, etc. — independent of the Firebase
/// sync button. This is the safety net: if the phone is lost, reset, or the app
/// is uninstalled before the next sync, a backup saved elsewhere isn't affected.
class BackupService {
  Future<void> backupDatabase() async {
    // VACUUM INTO writes a consistent, complete copy of the live database to a new
    // file in one step, safely even while the source database is open for use.
    final db = await DatabaseHelper.instance.database;
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyy-MM-dd_HHmmss').format(DateTime.now());
    final fileName = 'lee_sale_monitor_backup_$timestamp.db';
    final path = '${directory.path}/$fileName';

    await db.execute("VACUUM INTO '${path.replaceAll("'", "''")}'");

    await SharePlus.instance.share(ShareParams(
      files: [XFile(path)],
      subject: 'LEE Sale Monitor backup',
      text: 'Backup of LEE Sale Monitor data — $timestamp',
    ));
  }
}
