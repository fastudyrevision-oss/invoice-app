import 'package:sqflite/sqflite.dart';
import '../../../../db/database_helper.dart';
import '../models/audit_log_entry.dart';

class AuditLogDao {
  final db = DatabaseHelper.instance;

  Future<int> insert(AuditLogEntry entry, {DatabaseExecutor? txn}) async {
    if (txn != null) {
      return await txn.insert('audit_logs', entry.toMap());
    }
    return await db.insert('audit_logs', entry.toMap());
  }

  Future<List<AuditLogEntry>> getAll({int limit = 50, int offset = 0}) async {
    final data = await db.rawQuery(
      'SELECT * FROM audit_logs ORDER BY timestamp DESC LIMIT ? OFFSET ?',
      [limit, offset],
    );
    return data.map((e) => AuditLogEntry.fromMap(e)).toList();
  }

  Future<List<AuditLogEntry>> getByFilter({
    DateTime? start,
    DateTime? end,
    String? action,
    String? tableName,
    String? userId,
    int limit = 50,
    int offset = 0,
  }) async {
    String query = 'SELECT * FROM audit_logs WHERE 1=1';
    List<dynamic> args = [];

    if (start != null) {
      query += ' AND timestamp >= ?';
      args.add(start.toIso8601String());
    }
    if (end != null) {
      query += ' AND timestamp <= ?';
      args.add(end.toIso8601String());
    }
    if (action != null && action.isNotEmpty) {
      query += ' AND action = ?';
      args.add(action);
    }
    if (tableName != null && tableName.isNotEmpty) {
      query += ' AND table_name = ?';
      args.add(tableName);
    }
    if (userId != null && userId.isNotEmpty) {
      query += ' AND user_id = ?';
      args.add(userId);
    }

    query += ' ORDER BY timestamp DESC LIMIT ? OFFSET ?';
    args.add(limit);
    args.add(offset);

    final data = await db.rawQuery(query, args);
    return data.map((e) => AuditLogEntry.fromMap(e)).toList();
  }
}
