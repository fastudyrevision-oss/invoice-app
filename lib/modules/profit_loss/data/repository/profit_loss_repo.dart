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
    final grossProfit = sales - cogs;
    final expenses = await dao.getTotalExpenses(start, end);

    // Add manual entries
    final manualIncome = await manualEntryDao.getTotalIncome(start, end);
    final manualExpense = await manualEntryDao.getTotalExpense(start, end);

    final totalExpenses = expenses + manualExpense;
    final totalIncome = sales + manualIncome;
    final net = grossProfit + manualIncome - totalExpenses;

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
    // Add manual entries to breakdown
    final manualEntries = await manualEntryDao.getByDateRange(start, end);
    for (var entry in manualEntries) {
      if (entry.type == 'expense') {
        breakdown[entry.category] =
            (breakdown[entry.category] ?? 0) + entry.amount;
      }
    }

    return ProfitLossSummary(
      totalSales: totalIncome,
      totalCostOfGoods: cogs,
      grossProfit: grossProfit,
      totalExpenses: totalExpenses,
      netProfit: net,
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
    );
  }

  Future<List<ProductProfit>> loadProductProfit(DateTime start, DateTime end) =>
      dao.getProductWiseProfit(start, end);

  Future<List<CategoryProfit>> loadCategoryProfit(
    DateTime start,
    DateTime end,
  ) => dao.getCategoryWiseProfit(start, end);

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
