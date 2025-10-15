class ProductReport {
  final String productId;
  final String productName;
  final double totalQtyPurchased;
  final double totalSpent;

  ProductReport({
    required this.productId,
    required this.productName,
    required this.totalQtyPurchased,
    required this.totalSpent,
  });

  factory ProductReport.fromMap(Map<String, dynamic> map) {
    return ProductReport(
      productId: map['product_id'].toString(),
      productName: map['product_name'] ?? '',
      totalQtyPurchased: (map['total_qty_purchased'] ?? 0).toDouble(),
      totalSpent: (map['total_spent'] ?? 0).toDouble(),
    );
  }
}
