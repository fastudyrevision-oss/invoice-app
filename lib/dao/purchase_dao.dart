import 'package:sqflite/sqflite.dart';
import '../models/purchase.dart';
import '../core/services/audit_logger.dart';
import '../db/database_helper.dart';
import '../services/auth_service.dart';

class PurchaseDao {
  final DatabaseExecutor? db;
  PurchaseDao([this.db]);

  Future<DatabaseExecutor> get _db async =>
      db ?? await DatabaseHelper.instance.db;

  Future<int> insertPurchase(Purchase purchase) async {
    final dbClient = await _db;
    await dbClient.insert(
      "purchases",
      purchase.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await AuditLogger.log(
      'CREATE',
      'purchases',
      recordId: purchase.id,
      userId: AuthService.instance.currentUser?.id ?? 'system',
      newData: purchase.toMap(),
      txn: dbClient,
    );

    return 1;
  }

  Future<Purchase?> getPurchaseById(String id) async {
    final dbClient = await _db;
    final result = await dbClient.query(
      "purchases",
      where: "id = ?",
      whereArgs: [id],
    );
    if (result.isNotEmpty) {
      return Purchase.fromMap(result.first);
    }
    return null;
  }

  Future<List<Purchase>> getAllPurchases() async {
    final dbClient = await _db;
    final result = await dbClient.query("purchases", orderBy: "date DESC");
    return result.map<Purchase>((row) => Purchase.fromMap(row)).toList();
  }

  Future<int> updatePurchase(Purchase purchase) async {
    final dbClient = await _db;
    // Fetch old data
    final oldData = await getPurchaseById(purchase.id);

    final count = await dbClient.update(
      "purchases",
      purchase.toMap(),
      where: "id = ?",
      whereArgs: [purchase.id],
    );

    await AuditLogger.log(
      'UPDATE',
      'purchases',
      recordId: purchase.id,
      userId: AuthService.instance.currentUser?.id ?? 'system',
      oldData: oldData?.toMap(),
      newData: purchase.toMap(),
      txn: dbClient,
    );

    return count;
  }

  Future<int> deletePurchase(String id) async {
    final dbClient = await _db;
    // Fetch old data
    final oldData = await getPurchaseById(id);

    final count = await dbClient.delete(
      "purchases",
      where: "id = ?",
      whereArgs: [id],
    );

    if (oldData != null) {
      await AuditLogger.log(
        'DELETE',
        'purchases',
        recordId: id,
        userId: AuthService.instance.currentUser?.id ?? 'system',
        oldData: oldData.toMap(),
        txn: dbClient,
      );
    }

    return count;
  }
}
