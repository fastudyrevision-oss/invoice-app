import '../../../../db/database_helper.dart';
import '../models/category_profit.dart';
import '../models/product_profit.dart';
import '../models/supplier_profit.dart';
import '../models/customer_profit.dart';

class ProfitLossDao {
  final db = DatabaseHelper.instance;

  // ---------- Summary Queries ----------
  Future<double> getTotalSales(DateTime start, DateTime end) async {
    final result = await db.rawQuery(
      'SELECT SUM(total) AS total FROM invoices WHERE date BETWEEN ? AND ?',
      [start.toIso8601String(), end.toIso8601String()],
    );
    return (result.first['total'] as num? ?? 0) * 1.0;
  }

  Future<double> getTotalDiscounts(DateTime start, DateTime end) async {
    final result = await db.rawQuery(
      'SELECT SUM(discount) AS discount FROM invoices WHERE date BETWEEN ? AND ?',
      [start.toIso8601String(), end.toIso8601String()],
    );
    return (result.first['discount'] as num? ?? 0) * 1.0;
  }

  Future<double> getTotalExpenses(DateTime start, DateTime end) async {
    final result = await db.rawQuery(
      'SELECT SUM(amount) AS amount FROM expenses WHERE date BETWEEN ? AND ?',
      [start.toIso8601String(), end.toIso8601String()],
    );
    return (result.first['amount'] as num? ?? 0) * 1.0;
  }

  Future<double> getCustomerPendings() async {
    final result = await db.rawQuery(
      'SELECT SUM(pending) AS pending FROM invoices',
    );
    return (result.first['pending'] as num? ?? 0) * 1.0;
  }

  Future<double> getSupplierPendings() async {
    final result = await db.rawQuery(
      'SELECT SUM(pending) AS pending FROM purchases',
    );
    return (result.first['pending'] as num? ?? 0) * 1.0;
  }

  Future<double> getTotalPaidPurchases(DateTime start, DateTime end) async {
    final result = await db.rawQuery(
      'SELECT SUM(paid) AS paid FROM purchases WHERE date BETWEEN ? AND ?',
      [start.toIso8601String(), end.toIso8601String()],
    );
    return (result.first['paid'] as num? ?? 0) * 1.0;
  }

  Future<double> getTotalPurchases(DateTime start, DateTime end) async {
    final result = await db.rawQuery(
      'SELECT SUM(total) AS total FROM purchases WHERE date BETWEEN ? AND ?',
      [start.toIso8601String(), end.toIso8601String()],
    );
    return (result.first['total'] as num? ?? 0) * 1.0;
  }

  Future<double> getInHandCash(DateTime start, DateTime end) async {
    final result = await db.rawQuery(
      'SELECT SUM(paid) AS paid FROM invoices WHERE date BETWEEN ? AND ?',
      [start.toIso8601String(), end.toIso8601String()],
    );
    final paid = (result.first['paid'] as num? ?? 0) * 1.0;
    final expenses = await getTotalExpenses(start, end);
    return paid - expenses;
  }

  Future<double> getTotalCostOfGoodsSold(DateTime start, DateTime end) async {
    // Using weighted average cost to avoid Cartesian product from LEFT JOIN
    final result = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(ii.qty * p.weighted_avg_cost), 0) AS cogs
      FROM invoice_items ii
      LEFT JOIN invoices inv ON ii.invoice_id = inv.id
      LEFT JOIN (
        SELECT product_id, 
          SUM(qty * purchase_price) / NULLIF(SUM(qty), 0) as weighted_avg_cost
        FROM purchase_items
        GROUP BY product_id
      ) p ON ii.product_id = p.product_id
      WHERE inv.date BETWEEN ? AND ?
    ''',
      [start.toIso8601String(), end.toIso8601String()],
    );
    return (result.first['cogs'] as num? ?? 0) * 1.0;
  }

  Future<Map<String, double>> getExpenseCategoryBreakdown(
    DateTime start,
    DateTime end,
  ) async {
    final result = await db.rawQuery(
      'SELECT category, SUM(amount) AS total FROM expenses WHERE date BETWEEN ? AND ? GROUP BY category',
      [start.toIso8601String(), end.toIso8601String()],
    );
    Map<String, double> breakdown = {};
    for (var row in result) {
      breakdown[row['category'] as String? ?? 'General'] =
          (row['total'] as num? ?? 0) * 1.0;
    }
    return breakdown;
  }

  // ---------- Product Profits ----------
  Future<List<ProductProfit>> getProductWiseProfit(
    DateTime start,
    DateTime end,
  ) async {
    final result = await db.rawQuery(
      '''
      SELECT 
        p.id AS product_id,
        p.name AS product_name,
        SUM(ii.qty * ii.price) AS total_sales,
        SUM(ii.qty * COALESCE(wa.weighted_avg_cost, 0)) AS total_cost,
        SUM(ii.qty) AS sold_qty
      FROM products p
      LEFT JOIN invoice_items ii ON ii.product_id = p.id
      LEFT JOIN invoices inv ON ii.invoice_id = inv.id
      LEFT JOIN (
        SELECT product_id, 
          SUM(qty * purchase_price) / NULLIF(SUM(qty), 0) as weighted_avg_cost
        FROM purchase_items
        GROUP BY product_id
      ) wa ON p.id = wa.product_id
      WHERE inv.date BETWEEN ? AND ?
      GROUP BY p.id
    ''',
      [start.toIso8601String(), end.toIso8601String()],
    );

    return result.map((row) {
      final totalSales = (row['total_sales'] as num? ?? 0) * 1.0;
      final totalCost = (row['total_cost'] as num? ?? 0) * 1.0;
      return ProductProfit(
        productId: row['product_id'] as String? ?? '',
        name: row['product_name'] as String? ?? 'Unknown',
        totalSales: totalSales,
        totalCost: totalCost,
        profit: totalSales - totalCost,
        totalSoldQty: (row['sold_qty'] as num? ?? 0).toInt(),
        expiredQty: 0,
        expiredLoss: 0,
      );
    }).toList();
  }

  // ---------- Category Profits ----------
  Future<List<CategoryProfit>> getCategoryWiseProfit(
    DateTime start,
    DateTime end,
  ) async {
    final result = await db.rawQuery(
      '''
      SELECT 
        c.id AS category_id,
        c.name AS category_name,
        SUM(ii.qty * ii.price) AS total_sales,
        SUM(ii.qty * COALESCE(wa.weighted_avg_cost, 0)) AS total_cost
      FROM categories c
      LEFT JOIN products p ON p.category_id = c.id
      LEFT JOIN invoice_items ii ON ii.product_id = p.id
      LEFT JOIN invoices inv ON ii.invoice_id = inv.id
      LEFT JOIN (
        SELECT product_id, 
          SUM(qty * purchase_price) / NULLIF(SUM(qty), 0) as weighted_avg_cost
        FROM purchase_items
        GROUP BY product_id
      ) wa ON p.id = wa.product_id
      WHERE inv.date BETWEEN ? AND ?
      GROUP BY c.id
    ''',
      [start.toIso8601String(), end.toIso8601String()],
    );

    return result.map((row) {
      final totalSales = (row['total_sales'] as num? ?? 0) * 1.0;
      final totalCost = (row['total_cost'] as num? ?? 0) * 1.0;
      return CategoryProfit(
        categoryId: row['category_id'] as String? ?? '',
        name: row['category_name'] as String? ?? 'Unknown',
        totalSales: totalSales,
        totalCost: totalCost,
        profit: totalSales - totalCost,
      );
    }).toList();
  }

  // ---------- Supplier Profits ----------
  Future<List<SupplierProfit>> getSupplierWiseProfit(
    DateTime start,
    DateTime end,
  ) async {
    final result = await db.rawQuery(
      '''
      SELECT 
        s.id AS supplier_id,
        s.name AS supplier_name,
        SUM(pur.total) AS total_purchases,
        SUM(pur.pending) AS pending_to_supplier
      FROM suppliers s
      LEFT JOIN purchases pur ON pur.supplier_id = s.id
      WHERE pur.date BETWEEN ? AND ?
      GROUP BY s.id
    ''',
      [start.toIso8601String(), end.toIso8601String()],
    );

    return result.map((row) {
      return SupplierProfit(
        supplierId: row['supplier_id'] as String? ?? '',
        name: row['supplier_name'] as String? ?? 'Unknown',
        totalPurchases: (row['total_purchases'] as num? ?? 0) * 1.0,
        pendingToSupplier: (row['pending_to_supplier'] as num? ?? 0) * 1.0,
      );
    }).toList();
  }

  // ---------- Recent Transactions ----------
  Future<List<Map<String, dynamic>>> getRecentTransactions(int limit) async {
    final invoices = await db.rawQuery(
      'SELECT id, "sale" as type, total, date FROM invoices ORDER BY date DESC LIMIT ?',
      [limit],
    );
    final purchases = await db.rawQuery(
      'SELECT id, "purchase" as type, total, date FROM purchases ORDER BY date DESC LIMIT ?',
      [limit],
    );

    final all = [...invoices, ...purchases];
    all.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
    return all.take(limit).toList();
  }

  // ---------- Customer Profits ----------
  Future<List<CustomerProfit>> getCustomerWiseProfit(
    DateTime start,
    DateTime end,
  ) async {
    final result = await db.rawQuery(
      '''
      SELECT 
        COALESCE(inv.customer_id, 'walk-in') AS customer_id,
        COALESCE(inv.customer_name, 'Walk-in Customer') AS customer_name,
        SUM(ii.qty * ii.price) AS total_sales,
        SUM(ii.qty * COALESCE(wa.weighted_avg_cost, 0)) AS total_cost
      FROM invoices inv
      JOIN invoice_items ii ON ii.invoice_id = inv.id
      LEFT JOIN (
        SELECT product_id, 
          SUM(qty * purchase_price) / NULLIF(SUM(qty), 0) as weighted_avg_cost
        FROM purchase_items
        GROUP BY product_id
      ) wa ON ii.product_id = wa.product_id
      WHERE inv.date BETWEEN ? AND ?
      GROUP BY inv.customer_id, inv.customer_name
    ''',
      [start.toIso8601String(), end.toIso8601String()],
    );

    return result.map((row) {
      final totalSales = (row['total_sales'] as num? ?? 0) * 1.0;
      final totalCost = (row['total_cost'] as num? ?? 0) * 1.0;
      return CustomerProfit(
        customerId: row['customer_id'] as String? ?? 'walk-in',
        name: row['customer_name'] as String? ?? 'Walk-in Customer',
        totalSales: totalSales,
        totalCost: totalCost,
        profit: totalSales - totalCost,
      );
    }).toList();
  }
}
