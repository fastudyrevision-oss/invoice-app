

// =======================
// MODEL: ProductProfit
// =======================
class ProductProfit {
final String productId;
final String name;
final double totalSales;
final double totalCost;
final double profit;
final int totalSoldQty;
final int expiredQty;
final double expiredLoss;


ProductProfit({
required this.productId,
required this.name,
required this.totalSales,
required this.totalCost,
required this.profit,
required this.totalSoldQty,
required this.expiredQty,
required this.expiredLoss,
});
}