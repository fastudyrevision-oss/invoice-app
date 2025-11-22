import '../db/database_helper.dart';
import '../models/profit_loss_report.dart';

class ProfitLossDao {
  final dbHelper = DatabaseHelper();

  Future<ProfitLossReport> generateReport(
    String startDate,
    String endDate,
  ) async {
    // --- Total Sales (Invoices) ---
    final salesData = await dbHelper.rawQuery(
      "SELECT SUM(total) as total_sales FROM invoices WHERE date BETWEEN ? AND ?",
      [startDate, endDate],
    );
    double totalSales = salesData.first["total_sales"] ?? 0.0;

    // --- COGS (Purchase Price × Qty sold) ---
    final cogsData = await dbHelper.rawQuery(
      """
      SELECT SUM(ii.qty * pi.purchase_price) as total_cogs
      FROM invoice_items ii
      JOIN purchase_items pi ON ii.product_id = pi.product_id
      WHERE ii.invoice_id IN (
        SELECT id FROM invoices WHERE date BETWEEN ? AND ?
      )
    """,
      [startDate, endDate],
    );
    double totalCOGS = cogsData.first["total_cogs"] ?? 0.0;

    // --- Expenses ---
    final expensesData = await dbHelper.rawQuery(
      "SELECT SUM(amount) as total_expenses FROM expenses WHERE date BETWEEN ? AND ?",
      [startDate, endDate],
    );
    double totalExpenses = expensesData.first["total_expenses"] ?? 0.0;

    // --- Calculations ---
    double grossProfit = totalSales - totalCOGS;
    double netProfit = grossProfit - totalExpenses;

    return ProfitLossReport(
      totalSales: totalSales,
      totalCOGS: totalCOGS,
      totalExpenses: totalExpenses,
      grossProfit: grossProfit,
      netProfit: netProfit,
    );
  }
}
