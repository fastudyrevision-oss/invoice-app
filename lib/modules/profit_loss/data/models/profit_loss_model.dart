import '../models/category_profit.dart';
import '../models/product_profit.dart';
import '../models/profit_loss_summary.dart';
import '../models/supplier_profit.dart';
import '../models/customer_profit.dart';

// =======================
// MODEL: ProfitLossModel (Unified)
// =======================
class ProfitLossModel {
  final double totalSales;
  final double totalPurchaseCost; // This is COGS
  final double totalPurchases; // This is actual purchases made
  final double totalProfit;
  final double totalExpenses;
  final double totalDiscounts;
  final double totalReceived;
  final double pendingFromCustomers;
  final double pendingToSuppliers;
  final double inHandCash;
  final double expiredStockLoss;
  final double expiredStockRefunds;
  final double netExpiredLoss;

  final List<ProductProfit> products;
  final List<CategoryProfit> categories;
  final List<SupplierProfit> suppliers;
  final List<CustomerProfit> customerProfits;
  final List<Map<String, dynamic>> recentTransactions;
  final Map<String, double> expenseBreakdown;
  final Map<String, double> incomeBreakdown; // ✅ Added

  ProfitLossModel({
    this.totalSales = 0.0,
    this.totalPurchaseCost = 0.0,
    this.totalPurchases = 0.0,
    this.totalProfit = 0.0,
    this.totalExpenses = 0.0,
    this.totalDiscounts = 0.0,
    this.totalReceived = 0.0,
    this.pendingFromCustomers = 0.0,
    this.pendingToSuppliers = 0.0,
    this.inHandCash = 0.0,
    this.expiredStockLoss = 0.0,
    this.expiredStockRefunds = 0.0,
    this.netExpiredLoss = 0.0,
    this.products = const [],
    this.categories = const [],
    this.suppliers = const [],
    this.customerProfits = const [],
    this.recentTransactions = const [],
    this.expenseBreakdown = const {},
    this.incomeBreakdown = const {}, // ✅ Added
  });

  // Factory from ProfitLossSummary
  factory ProfitLossModel.fromSummary(ProfitLossSummary s) {
    return ProfitLossModel(
      totalSales: s.totalSales,
      totalPurchaseCost: s.totalCostOfGoods,
      totalPurchases: s.totalPurchases,
      totalProfit: s.netProfit,
      totalExpenses: s.totalExpenses,
      totalDiscounts: s.totalDiscounts,
      totalReceived: s.totalReceived,
      pendingFromCustomers: s.pendingFromCustomers,
      pendingToSuppliers: s.pendingToSuppliers,
      inHandCash: s.inHandCash,
      expiredStockLoss: s.expiredStockLoss,
      expiredStockRefunds: s.expiredStockRefunds,
      netExpiredLoss: s.netExpiredLoss,
      expenseBreakdown: s.expenseBreakdown,
      incomeBreakdown: s.incomeBreakdown, // ✅ Added
    );
  }

  // Factory from ProductProfit list
  factory ProfitLossModel.fromProductList(List<ProductProfit> list) {
    double totalSales = 0;
    double totalCost = 0;
    double totalProfit = 0;

    for (var p in list) {
      totalSales += p.totalSales;
      totalCost += p.totalCost;
      totalProfit += p.profit;
    }

    return ProfitLossModel(
      totalSales: totalSales,
      totalPurchaseCost: totalCost,
      totalProfit: totalProfit,
      products: list,
    );
  }

  // Factory from CategoryProfit list
  factory ProfitLossModel.fromCategoryList(List<CategoryProfit> list) {
    double totalSales = 0;
    double totalCost = 0;
    double totalProfit = 0;

    for (var c in list) {
      totalSales += c.totalSales;
      totalCost += c.totalCost;
      totalProfit += c.profit;
    }

    return ProfitLossModel(
      totalSales: totalSales,
      totalPurchaseCost: totalCost,
      totalProfit: totalProfit,
      categories: list,
    );
  }

  // Factory from SupplierProfit list
  factory ProfitLossModel.fromSupplierList(List<SupplierProfit> list) {
    double totalPurchases = 0;
    double pending = 0;

    for (var s in list) {
      totalPurchases += s.totalPurchases;
      pending += s.pendingToSupplier;
    }

    return ProfitLossModel(
      totalPurchaseCost: totalPurchases,
      pendingToSuppliers: pending,
      suppliers: list,
    );
  }
}
