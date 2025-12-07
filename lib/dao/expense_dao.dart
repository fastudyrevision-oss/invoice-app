import '../db/database_helper.dart';
import '../models/expense.dart';

import 'package:sqflite/sqflite.dart';
import '../core/services/audit_logger.dart';
import '../services/auth_service.dart';

class ExpenseDao {
  final DatabaseExecutor? db;

  ExpenseDao([this.db]);

  Future<DatabaseExecutor> get _db async =>
      db ?? await DatabaseHelper.instance.db;

  Future<int> insert(Expense expense) async {
    final dbClient = await _db;
    final id = await dbClient.insert("expenses", expense.toMap());

    await AuditLogger.log(
      'CREATE',
      'expenses',
      recordId: expense.id,
      userId: AuthService.instance.currentUser?.id ?? 'system',
      newData: expense.toMap(),
      txn: dbClient,
    );

    return id;
  }

  Future<List<Expense>> getAll() async {
    final dbClient = await _db;
    final data = await dbClient.query("expenses");
    return data.map((e) => Expense.fromMap(e)).toList();
  }

  Future<int> update(Expense expense) async {
    final dbClient = await _db;

    // Fetch old data
    final oldDataList = await dbClient.query(
      "expenses",
      where: "id = ?",
      whereArgs: [expense.id],
    );
    final oldData = oldDataList.isNotEmpty ? oldDataList.first : null;

    final count = await dbClient.update(
      "expenses",
      expense.toMap(),
      where: "id = ?",
      whereArgs: [expense.id],
    );

    await AuditLogger.log(
      'UPDATE',
      'expenses',
      recordId: expense.id,
      userId: AuthService.instance.currentUser?.id ?? 'system',
      oldData: oldData,
      newData: expense.toMap(),
      txn: dbClient,
    );

    return count;
  }

  Future<int> delete(String id) async {
    final dbClient = await _db;

    // Fetch old data
    final oldDataList = await dbClient.query(
      "expenses",
      where: "id = ?",
      whereArgs: [id],
    );
    final oldData = oldDataList.isNotEmpty ? oldDataList.first : null;

    final count = await dbClient.delete(
      "expenses",
      where: "id = ?",
      whereArgs: [id],
    );

    if (oldData != null) {
      await AuditLogger.log(
        'DELETE',
        'expenses',
        recordId: id,
        userId: AuthService.instance.currentUser?.id ?? 'system',
        oldData: oldData,
        txn: dbClient,
      );
    }

    return count;
  }
}
