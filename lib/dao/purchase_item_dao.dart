import 'package:sqflite/sqflite.dart';
import '../models/purchase_item.dart';

class PurchaseItemDao {
  final DatabaseExecutor db; // ✅ Accepts Database OR Transaction
  PurchaseItemDao(this.db);

  /// Insert a purchase item
  Future<void> insertPurchaseItem(PurchaseItem item) async {
    await db.insert(
      "purchase_items",
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get items by purchase ID
  Future<List<PurchaseItem>> getItemsByPurchaseId(String purchaseId) async {
    final result = await db.query(
      "purchase_items",
      where: "purchase_id = ?",
      whereArgs: [purchaseId],
    );

    return result.map((row) => PurchaseItem.fromMap(row)).toList();
  }

  /// Delete items by purchase ID
  Future<int> deleteItemsByPurchaseId(String purchaseId) async {
    return await db.delete(
      "purchase_items",
      where: "purchase_id = ?",
      whereArgs: [purchaseId],
    );
  }
}
