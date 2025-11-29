import '../models/category_profit.dart';
import '../models/product_profit.dart';
import '../models/profit_loss_summary.dart';
import '../models/supplier_profit.dart';

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
  final double pendingFromCustomers;
  final double pendingToSuppliers;
  final double inHandCash;

  final List<ProductProfit> products;
  final List<CategoryProfit> categories;
  final List<SupplierProfit> suppliers;

  ProfitLossModel({
    this.totalSales = 0.0,
    this.totalPurchaseCost = 0.0,
    this.totalPurchases = 0.0,
    this.totalProfit = 0.0,
    this.totalExpenses = 0.0,
    this.totalDiscounts = 0.0,
    this.pendingFromCustomers = 0.0,
    this.pendingToSuppliers = 0.0,
    this.inHandCash = 0.0,
    this.products = const [],
    this.categories = const [],
    this.suppliers = const [],
  });

  // Factory from ProfitLossSummary
  factory ProfitLossModel.fromSummary(
    ProfitLossSummary s, {
    double totalPurchases = 0.0,
  }) {
    return ProfitLossModel(
      totalSales: s.totalSales,
      totalPurchaseCost: s.totalCostOfGoods,
      totalPurchases: totalPurchases,
      totalProfit: s.netProfit,
      totalExpenses: s.totalExpenses,
      totalDiscounts: s.totalDiscounts,
      pendingFromCustomers: s.pendingFromCustomers,
      pendingToSuppliers: s.pendingToSuppliers,
      inHandCash: s.inHandCash,
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
