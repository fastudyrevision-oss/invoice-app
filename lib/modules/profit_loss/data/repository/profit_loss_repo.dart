import '../dao/profit_loss_dao.dart';
import '../dao/manual_entry_dao.dart';
import '../models/category_profit.dart';
import '../models/product_profit.dart';
import '../models/profit_loss_summary.dart';
import '../models/supplier_profit.dart';
import '../models/customer_profit.dart';
import '../models/manual_entry.dart';
import '../../../../dao/stock_disposal_dao.dart';
import '../../../../db/database_helper.dart';
import '../../../../services/logger_service.dart';

// =======================
// REPOSITORY: ProfitLossRepository
// =======================
class ProfitLossRepository {
  final ProfitLossDao dao;
  final ManualEntryDao manualEntryDao;

  ProfitLossRepository(this.dao, this.manualEntryDao);

  /// Fetch Profit & Loss summary within date range
  Future<ProfitLossSummary> loadSummary(DateTime start, DateTime end) async {
    final sales = await dao.getTotalSales(start, end);
    final discounts = await dao.getTotalDiscounts(start, end);
    final cogs = await dao.getTotalCostOfGoodsSold(start, end);

    final expenses = await dao.getTotalExpenses(start, end);

    // Add manual entries
    final manualIncome = await manualEntryDao.getTotalIncome(start, end);
    final manualExpense = await manualEntryDao.getTotalExpense(start, end);

    // ✅ Gross Profit Correction: Manual Income IS revenue, so it should be part of Gross Profit
    // Gross Profit = (Sales - Discounts - COGS) + Manual Income
    final grossProfit = (sales - discounts - cogs) + manualIncome;

    final totalExpenses = expenses + manualExpense;
    // We now return GROSS sales in totalSales to better reflect "Total Sales" on UI
    // The UI or Net Profit calc will handle filtering discounts
    final totalIncome = sales + manualIncome;

    // ✅ Net Profit Correction: Gross - Expenses
    final net = grossProfit - totalExpenses;

    final pendingCustomers = await dao.getCustomerPendings();
    final pendingSuppliers = await dao.getSupplierPendings();

    // Get purchase data
    final paidPurchases = await dao.getTotalPaidPurchases(start, end);
    final totalPurchases = await dao.getTotalPurchases(start, end);

    // Calculate In-Hand Cash
    // dao.getInHandCash returns (paidInvoices - expenses)
    final netInvoicesMinusExpenses = await dao.getInHandCash(start, end);
    final paidInvoices = netInvoicesMinusExpenses + expenses;

    final inHand = paidInvoices + manualIncome - paidPurchases - totalExpenses;

    // Calculate expired stock losses (with error handling for missing table)
    double expiredStockLoss = 0.0;
    double expiredStockRefunds = 0.0;
    double netExpiredLoss = 0.0;

    try {
      final db = await DatabaseHelper.instance.db;
      final disposalDao = StockDisposalDao(db);
      final disposalLosses = await disposalDao.getTotalLoss(
        start: start,
        end: end,
      );

      expiredStockLoss =
          disposalLosses['write_offs']! + disposalLosses['rejected_returns']!;
      expiredStockRefunds = disposalLosses['received_refunds']!;
      netExpiredLoss = disposalLosses['net_loss']!;
    } catch (e) {
      // Table might not exist yet, ignore and use default values (0.0)
      logger.warning(
        'ProfitLoss',
        '⚠️ Could not load stock disposal data',
        error: e,
      );
    }

    // Get expense breakdown
    final breakdown = await dao.getExpenseCategoryBreakdown(start, end);
    final incomeBreakdown = <String, double>{};

    // Add manual entries to breakdown
    final manualEntries = await manualEntryDao.getByDateRange(start, end);
    for (var entry in manualEntries) {
      if (entry.type == 'expense') {
        breakdown[entry.category] =
            (breakdown[entry.category] ?? 0) + entry.amount;
      } else if (entry.type == 'income') {
        incomeBreakdown[entry.category] =
            (incomeBreakdown[entry.category] ?? 0) + entry.amount;
      }
    }

    // Final Net Profit Calculation:
    // net = grossProfit - totalExpenses - netExpiredLoss;
    final finalNet = net - netExpiredLoss;

    return ProfitLossSummary(
      totalSales: totalIncome, // NOW GROSS
      totalCostOfGoods: cogs,
      grossProfit: grossProfit,
      totalExpenses: totalExpenses,
      netProfit: finalNet,
      totalDiscounts: discounts,
      totalReceived: paidInvoices + manualIncome,
      pendingFromCustomers: pendingCustomers,
      pendingToSuppliers: pendingSuppliers,
      totalPurchases: totalPurchases,
      inHandCash: inHand,
      expiredStockLoss: expiredStockLoss,
      expiredStockRefunds: expiredStockRefunds,
      netExpiredLoss: netExpiredLoss,
      expenseBreakdown: breakdown,
      incomeBreakdown: incomeBreakdown,
    );
  }

  Future<List<ProductProfit>> loadProductProfit(DateTime start, DateTime end) =>
      dao.getProductWiseProfit(start, end);

  Future<List<CategoryProfit>> loadCategoryProfit(
    DateTime start,
    DateTime end,
  ) async {
    // 1. Get database categories
    final list = await dao.getCategoryWiseProfit(start, end);
    final manualEntries = await manualEntryDao.getByDateRange(start, end);

    // 2. Wrap in a map for easy merging
    final Map<String, CategoryProfit> map = {for (var c in list) c.name: c};

    // 3. Merge manual items
    for (var entry in manualEntries) {
      final name = entry.category;
      final existing = map[name];

      if (existing != null) {
        final newSales = entry.type == 'income'
            ? existing.totalSales + entry.amount
            : existing.totalSales;
        final newCost = entry.type == 'expense'
            ? existing.totalCost + entry.amount
            : existing.totalCost;
        map[name] = CategoryProfit(
          categoryId: existing.categoryId,
          name: name,
          totalSales: newSales,
          totalCost: newCost,
          profit: newSales - newCost,
        );
      } else {
        // Create new virtual category if it doesn't exist in DB categories
        final sales = entry.type == 'income' ? entry.amount : 0.0;
        final cost = entry.type == 'expense' ? entry.amount : 0.0;
        map[name] = CategoryProfit(
          categoryId: 'manual_$name',
          name: name,
          totalSales: sales,
          totalCost: cost,
          profit: sales - cost,
        );
      }
    }

    return map.values.toList()
      ..sort((a, b) => b.profit.compareTo(a.profit)); // Sort by profit
  }

  Future<List<SupplierProfit>> loadSupplierProfit(
    DateTime start,
    DateTime end,
  ) => dao.getSupplierWiseProfit(start, end);

  Future<List<ManualEntry>> loadManualEntries(DateTime start, DateTime end) =>
      manualEntryDao.getByDateRange(start, end);

  Future<List<Map<String, dynamic>>> loadRecentTransactions(int limit) =>
      dao.getRecentTransactions(limit);

  Future<List<CustomerProfit>> loadCustomerProfit(
    DateTime start,
    DateTime end,
  ) => dao.getCustomerWiseProfit(start, end);
}
