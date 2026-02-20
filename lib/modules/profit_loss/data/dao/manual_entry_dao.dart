import '../../../../db/database_helper.dart';
import '../models/manual_entry.dart';
import '../../../../core/services/audit_logger.dart';
import '../../../../services/auth_service.dart';

class ManualEntryDao {
  final db = DatabaseHelper.instance;

  Future<int> insert(ManualEntry entry) async {
    final id = await db.insert('manual_entries', entry.toMap());
    await AuditLogger.log(
      'CREATE',
      'manual_entries',
      recordId: entry.id,
      userId: AuthService.instance.currentUser?.id ?? 'system',
      newData: entry.toMap(),
    );
    return id;
  }

  Future<List<ManualEntry>> getAll() async {
    final data = await db.queryAll('manual_entries');
    return data.map((e) => ManualEntry.fromMap(e)).cast<ManualEntry>().toList();
  }

  Future<List<ManualEntry>> getByDateRange(DateTime start, DateTime end) async {
    final startStr = start.toIso8601String().split('T')[0];
    final endStr = end.toIso8601String().split('T')[0];
    final data = await db.rawQuery(
      'SELECT * FROM manual_entries WHERE date BETWEEN ? AND ?',
      ['${startStr}T00:00:00', '${endStr}T23:59:59'],
    );
    return data.map((e) => ManualEntry.fromMap(e)).cast<ManualEntry>().toList();
  }

  Future<double> getTotalIncome(DateTime start, DateTime end) async {
    final startStr = start.toIso8601String().split('T')[0];
    final endStr = end.toIso8601String().split('T')[0];
    final result = await db.rawQuery(
      "SELECT SUM(amount) AS total FROM manual_entries WHERE type = 'income' AND date BETWEEN ? AND ?",
      ['${startStr}T00:00:00', '${endStr}T23:59:59'],
    );
    return (result.first['total'] as num? ?? 0) * 1.0;
  }

  Future<double> getTotalExpense(DateTime start, DateTime end) async {
    final startStr = start.toIso8601String().split('T')[0];
    final endStr = end.toIso8601String().split('T')[0];
    final result = await db.rawQuery(
      "SELECT SUM(amount) AS total FROM manual_entries WHERE type = 'expense' AND date BETWEEN ? AND ?",
      ['${startStr}T00:00:00', '${endStr}T23:59:59'],
    );
    return (result.first['total'] as num? ?? 0) * 1.0;
  }

  Future<int> update(ManualEntry entry) async {
    // Fetch old data for audit
    final oldData = await db.queryById('manual_entries', entry.id);

    final count = await db.update('manual_entries', entry.toMap(), entry.id);

    await AuditLogger.log(
      'UPDATE',
      'manual_entries',
      recordId: entry.id,
      userId: AuthService.instance.currentUser?.id ?? 'system',
      oldData: oldData,
      newData: entry.toMap(),
    );
    return count;
  }

  Future<int> delete(String id) async {
    // Fetch old data for audit
    final oldData = await db.queryById('manual_entries', id);

    final count = await db.delete('manual_entries', id);

    if (oldData != null) {
      await AuditLogger.log(
        'DELETE',
        'manual_entries',
        recordId: id,
        userId: AuthService.instance.currentUser?.id ?? 'system',
        oldData: oldData,
      );
    }
    return count;
  }
}
