import 'package:sqflite/sqflite.dart';
import '../models/purchase.dart';

class PurchaseDao {
    final DatabaseExecutor db;
    PurchaseDao(this.db);


  Future<void> insertPurchase(Purchase purchase) async {
    await db.insert(
      "purchases",
      purchase.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Purchase?> getPurchaseById(String id) async {
    final result = await db.query("purchases", where: "id = ?", whereArgs: [id]);
    if (result.isNotEmpty) {
      return Purchase.fromMap(result.first);
    }
    return null;
  }

  Future<List<Purchase>> getAllPurchases() async {
    final result = await db.query("purchases", orderBy: "date DESC");
    return result.map<Purchase>((row) => Purchase.fromMap(row)).toList();
    }


  Future<int> updatePurchase(Purchase purchase) async {
    return await db.update(
      "purchases",
      purchase.toMap(),
      where: "id = ?",
      whereArgs: [purchase.id],
    );
  }

  Future<int> deletePurchase(String id) async {
    return await db.delete("purchases", where: "id = ?", whereArgs: [id]);
  }
}
