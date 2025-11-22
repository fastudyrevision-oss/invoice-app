import 'package:sqflite/sqflite.dart';
import '../db/database_helper.dart';

class SyncTimeService {
  final dbHelper = DatabaseHelper.instance;

  Future<DateTime?> getLastSync(String table) async {
    final db = await dbHelper.db;
    final result = await db.query(
      'sync_meta',
      where: 'table_name = ?',
      whereArgs: [table],
    );
    if (result.isNotEmpty) {
      return DateTime.tryParse(result.first['last_synced_at'] ?? '');
    }
    return null;
  }

  Future<void> setLastSync(String table, DateTime time) async {
    final db = await dbHelper.db;
    await db.insert('sync_meta', {
      'table_name': table,
      'last_synced_at': time.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
