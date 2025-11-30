import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../dao/audit_log_dao.dart';
import '../models/audit_log_entry.dart';

class AuditLogRepository {
  final AuditLogDao _dao;

  AuditLogRepository(this._dao);

  Future<void> logAction({
    required String action, // CREATE, UPDATE, DELETE
    required String tableName,
    required String recordId,
    required String userId,
    Map<String, dynamic>? oldData,
    Map<String, dynamic>? newData,
    DatabaseExecutor? txn,
  }) async {
    final entry = AuditLogEntry(
      id: const Uuid().v4(),
      action: action,
      tableName: tableName,
      recordId: recordId,
      userId: userId,
      oldData: oldData,
      newData: newData,
      timestamp: DateTime.now(),
    );
    await _dao.insert(entry, txn: txn);
  }

  Future<List<AuditLogEntry>> getLogs({
    DateTime? start,
    DateTime? end,
    String? action,
    String? tableName,
    int limit = 50,
    int offset = 0,
  }) async {
    return await _dao.getByFilter(
      start: start,
      end: end,
      action: action,
      tableName: tableName,
      limit: limit,
      offset: offset,
    );
  }
}
