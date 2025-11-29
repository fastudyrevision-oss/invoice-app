import '../dao/profit_loss_dao.dart';
import '../dao/manual_entry_dao.dart';
import '../models/category_profit.dart';
import '../models/product_profit.dart';
import '../models/profit_loss_summary.dart';
import '../models/supplier_profit.dart';
import '../models/manual_entry.dart';

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

    return ProfitLossSummary(
      totalSales: totalIncome,
      totalCostOfGoods: cogs,
      grossProfit: grossProfit,
      totalExpenses: totalExpenses,
      netProfit: net,
      totalDiscounts: discounts,
      pendingFromCustomers: pendingCustomers,
      pendingToSuppliers: pendingSuppliers,
      totalPurchases: totalPurchases,
      inHandCash: inHand,
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
}
