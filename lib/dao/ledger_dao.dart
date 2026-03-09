import 'package:sqflite/sqflite.dart';
import '../models/ledger_entry.dart';

class LedgerDao {
  final DatabaseExecutor db;
  LedgerDao(this.db);

  Future<int> insert(LedgerEntry entry) async =>
      await db.insert("ledger", entry.toMap());

  Future<List<LedgerEntry>> getByEntity(
    String entityId,
    String entityType,
  ) async {
    final data = await db.query(
      "ledger",
      where: "entity_id = ? AND entity_type = ?",
      whereArgs: [entityId, entityType],
    );
    return data.map((e) => LedgerEntry.fromMap(e)).toList();
  }

  Future<List<LedgerEntry>> getAll() async {
    final data = await db.query("ledger");
    return data.map((e) => LedgerEntry.fromMap(e)).toList();
  }
}
