class StockReport {
  final String productId;
  final String productName;
  final int purchasedQty;
  final int soldQty;
  final int remainingQty;
  final double costPrice;
  final double sellPrice;
  final double totalValue;

  // ✅ Optional new fields
  final String? supplierName;
  final DateTime? expiryDate;

  StockReport({
    required this.productId,
    required this.productName,
    required this.purchasedQty,
    required this.soldQty,
    required this.remainingQty,
    required this.costPrice,
    required this.sellPrice,
    required this.totalValue,
    this.supplierName,
    this.expiryDate,
  });

  factory StockReport.fromMap(Map<String, dynamic> map) {
    return StockReport(
      productId: map['product_id']?.toString() ?? '',
      productName: map['product_name'] ?? '',
      purchasedQty: map['purchased_qty'] ?? 0,
      soldQty: map['sold_qty'] ?? 0,
      remainingQty: map['remaining_qty'] ?? 0,
      costPrice: (map['cost_price'] ?? 0).toDouble(),
      sellPrice: (map['sell_price'] ?? 0).toDouble(),
      totalValue: (map['total_value'] ?? 0).toDouble(),

      // ✅ Optional fields (if available in your DB or join)
      supplierName: map['supplier_name'],
      expiryDate: map['expiry_date'] != null
          ? DateTime.tryParse(map['expiry_date'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'product_id': productId,
      'product_name': productName,
      'purchased_qty': purchasedQty,
      'sold_qty': soldQty,
      'remaining_qty': remainingQty,
      'cost_price': costPrice,
      'sell_price': sellPrice,
      'total_value': totalValue,
      'supplier_name': supplierName,
      'expiry_date': expiryDate?.toIso8601String(),
    };
  }
}
