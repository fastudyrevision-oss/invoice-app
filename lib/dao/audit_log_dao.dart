import '../db/database_helper.dart';
import '../models/audit_log.dart';

class AuditLogDao {
  final dbHelper = DatabaseHelper();

  Future<int> insert(AuditLog log) async =>
      await dbHelper.insert("audit_logs", log.toMap());

  Future<List<AuditLog>> getAll() async {
    final data = await dbHelper.queryAll("audit_logs");
    return data.map((e) => AuditLog.fromMap(e)).toList();
  }

  Future<List<AuditLog>> getByTable(String tableName) async {
    final data = await dbHelper.queryWhere("audit_logs", "table_name = ?", [tableName]);
    return data.map((e) => AuditLog.fromMap(e)).toList();
  }
}
