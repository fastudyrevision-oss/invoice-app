import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';
import '../../modules/audit_log/data/dao/audit_log_dao.dart';
import '../../modules/audit_log/data/repository/audit_log_repository.dart';

class AuditLogger {
  static final AuditLogger _instance = AuditLogger._internal();
  late final AuditLogRepository _repository;

  factory AuditLogger() {
    return _instance;
  }

  AuditLogger._internal() {
    _repository = AuditLogRepository(AuditLogDao());
  }

  static Future<void> log(
    String action,
    String tableName, {
    required String recordId,
    required String userId,
    Map<String, dynamic>? oldData,
    Map<String, dynamic>? newData,
    DatabaseExecutor? txn,
  }) async {
    try {
      await _instance._repository.logAction(
        action: action,
        tableName: tableName,
        recordId: recordId,
        userId: userId,
        oldData: oldData,
        newData: newData,
        txn: txn,
      );
    } catch (e) {
      // Fail silently or log to console, don't crash the app for logging
      debugPrint('Failed to write audit log: $e');
    }
  }
}
