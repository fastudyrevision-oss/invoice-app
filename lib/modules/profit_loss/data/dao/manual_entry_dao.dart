import '../../../../db/database_helper.dart';
import '../models/manual_entry.dart';

class ManualEntryDao {
  final db = DatabaseHelper.instance;

  Future<int> insert(ManualEntry entry) async {
    return await db.insert('manual_entries', entry.toMap());
  }

  Future<List<ManualEntry>> getAll() async {
    final data = await db.queryAll('manual_entries');
    return data.map((e) => ManualEntry.fromMap(e)).toList();
  }

  Future<List<ManualEntry>> getByDateRange(DateTime start, DateTime end) async {
    final data = await db.rawQuery(
      'SELECT * FROM manual_entries WHERE date BETWEEN ? AND ?',
      [start.toIso8601String(), end.toIso8601String()],
    );
    return data.map((e) => ManualEntry.fromMap(e)).toList();
  }

  Future<double> getTotalIncome(DateTime start, DateTime end) async {
    final result = await db.rawQuery(
      "SELECT SUM(amount) AS total FROM manual_entries WHERE type = 'income' AND date BETWEEN ? AND ?",
      [start.toIso8601String(), end.toIso8601String()],
    );
    return (result.first['total'] as num? ?? 0) * 1.0;
  }

  Future<double> getTotalExpense(DateTime start, DateTime end) async {
    final result = await db.rawQuery(
      "SELECT SUM(amount) AS total FROM manual_entries WHERE type = 'expense' AND date BETWEEN ? AND ?",
      [start.toIso8601String(), end.toIso8601String()],
    );
    return (result.first['total'] as num? ?? 0) * 1.0;
  }

  Future<int> update(ManualEntry entry) async {
    return await db.update('manual_entries', entry.toMap(), entry.id);
  }

  Future<int> delete(String id) async {
    return await db.delete('manual_entries', id);
  }
}
