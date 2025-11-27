import '../dao/profit_loss_dao.dart';
import '../models/category_profit.dart';
import '../models/product_profit.dart';
import '../models/profit_loss_summary.dart';
import '../models/supplier_profit.dart';

// =======================
// REPOSITORY: ProfitLossRepository
// =======================
class ProfitLossRepository {
  final ProfitLossDao dao;

  ProfitLossRepository(this.dao);

  /// Fetch Profit & Loss summary within date range
  Future<ProfitLossSummary> loadSummary(DateTime start, DateTime end) async {
    final sales = await dao.getTotalSales(start, end);
    final discounts = await dao.getTotalDiscounts(start, end);
    final cogs = await dao.getTotalCostOfGoodsSold(start, end);
    final grossProfit = sales - cogs;
    final expenses = await dao.getTotalExpenses(start, end);
    final net = grossProfit - expenses;

    final pendingCustomers = await dao.getCustomerPendings();
    final pendingSuppliers = await dao.getSupplierPendings();
    final inHand = await dao.getInHandCash(start, end);

    return ProfitLossSummary(
      totalSales: sales,
      totalCostOfGoods: cogs,
      grossProfit: grossProfit,
      totalExpenses: expenses,
      netProfit: net,
      totalDiscounts: discounts,
      pendingFromCustomers: pendingCustomers,
      pendingToSuppliers: pendingSuppliers,
      inHandCash: inHand,
    );
  }

  Future<List<ProductProfit>> loadProductProfit(DateTime start, DateTime end) =>
      dao.getProductWiseProfit(start, end);

  Future<List<CategoryProfit>> loadCategoryProfit(DateTime start, DateTime end) =>
      dao.getCategoryWiseProfit(start, end);

  Future<List<SupplierProfit>> loadSupplierProfit(DateTime start, DateTime end) =>
      dao.getSupplierWiseProfit(start, end);
}
