import '../db/database_helper.dart';
import '../models/ledger_entry.dart';

class LedgerDao {
  final dbHelper = DatabaseHelper();

  Future<int> insert(LedgerEntry entry) async =>
      await dbHelper.insert("ledger", entry.toMap());

  Future<List<LedgerEntry>> getByEntity(
    String entityId,
    String entityType,
  ) async {
    final data = await dbHelper.queryWhere(
      "ledger",
      "entity_id = ? AND entity_type = ?",
      [entityId, entityType],
    );
    return data.map((e) => LedgerEntry.fromMap(e)).toList();
  }

  Future<List<LedgerEntry>> getAll() async {
    final data = await dbHelper.queryAll("ledger");
    return data.map((e) => LedgerEntry.fromMap(e)).toList();
  }
}
