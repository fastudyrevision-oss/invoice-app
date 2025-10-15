import '../db/database_helper.dart';
import '../models/stock_report_model.dart';

class StockDao {
  final dbHelper = DatabaseHelper.instance;

  Future<List<StockReport>> getStockReport() async {
    final db = await dbHelper.db;

    final sql = '''
      SELECT 
        p.id as product_id,
        p.name as product_name,
        IFNULL(SUM(pi.qty), 0) as purchased_qty,
        IFNULL((SELECT SUM(ii.qty) FROM invoice_items ii WHERE ii.product_id = p.id), 0) as sold_qty,
        (IFNULL(SUM(pi.qty), 0) - IFNULL((SELECT SUM(ii.qty) FROM invoice_items ii WHERE ii.product_id = p.id), 0)) as remaining_qty,
        p.cost_price,
        p.sell_price,
        ((IFNULL(SUM(pi.qty), 0) - IFNULL((SELECT SUM(ii.qty) FROM invoice_items ii WHERE ii.product_id = p.id), 0)) * p.cost_price) as total_value
      FROM products p
      LEFT JOIN purchase_items pi ON pi.product_id = p.id
      GROUP BY p.id, p.name
      ORDER BY p.name ASC
    ''';

    final results = await dbHelper.rawQuery(sql);
    return results.map((r) => StockReport.fromMap(r)).toList();
  }
}
