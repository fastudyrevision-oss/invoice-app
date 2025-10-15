import '../db/database_helper.dart';
import '../models/stock_alert.dart';

class StockAlertDao {
  final dbHelper = DatabaseHelper();

  /// 🔥 Get products below min stock
  Future<List<StockAlert>> getLowStockAlerts() async {
    final data = await dbHelper.rawQuery("""
      SELECT p.id as product_id, p.name as product_name, 
             b.batch_no, b.expiry_date, b.qty, p.min_stock
      FROM products p
      LEFT JOIN product_batches b ON b.product_id = p.id
      WHERE b.qty < p.min_stock
    """);

    return data.map((e) => StockAlert(
      productId: e["product_id"].toString(),
      productName: e["product_name"],
      batchNo: e["batch_no"],
      expiryDate: e["expiry_date"],
      qty: e["qty"] ?? 0,
      minStock: e["min_stock"] ?? 0,
      isLowStock: true,
    )).toList();
  }

  /// 🔥 Get expired products
  Future<List<StockAlert>> getExpiredProducts() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);

    final data = await dbHelper.rawQuery("""
      SELECT p.id as product_id, p.name as product_name, 
             b.batch_no, b.expiry_date, b.qty, p.min_stock
      FROM product_batches b
      JOIN products p ON p.id = b.product_id
      WHERE b.expiry_date IS NOT NULL AND b.expiry_date < ?
    """, [today]);

    return data.map((e) => StockAlert(
      productId: e["product_id"].toString(),
      productName: e["product_name"],
      batchNo: e["batch_no"],
      expiryDate: e["expiry_date"],
      qty: e["qty"] ?? 0,
      minStock: e["min_stock"] ?? 0,
      isExpired: true,
    )).toList();
  }

  /// 🔥 Combined Alerts (low stock + expired)
  Future<List<StockAlert>> getAllAlerts() async {
    final lowStock = await getLowStockAlerts();
    final expired = await getExpiredProducts();
    return [...lowStock, ...expired];
  }
}
