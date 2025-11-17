class StockReport {
  // Identification
  final String productId;
  final String productName;
  final String? categoryName;
  final String? companyName;

  // Supplier Info
  final String? supplierId;
  final String? supplierName;

  // Purchase Info
  final int purchasedQty;
  final double costPrice;
  final DateTime? lastPurchaseDate;

  // Sales Info
  final int soldQty;
  final double sellPrice;
  final DateTime? lastSoldDate;

  // Stock Position
  final int remainingQty;
  final int? reorderLevel;

  // Value Calculations
  final double totalCostValue;
  final double totalSellValue;
  final double profitValue;
  final double profitMargin;

  // Derived helper
  double get profitPerUnit => sellPrice - costPrice;

  // Quality / Expiry
  final DateTime? expiryDate;
  final String? batchNo;

  // Batch-level sums
  final double? stockValueCost;
  final double? stockValueSell;

  StockReport({
    required this.productId,
    required this.productName,
    required this.purchasedQty,
    required this.soldQty,
    required this.remainingQty,
    required this.costPrice,
    required this.sellPrice,
    required this.totalCostValue,
    required this.totalSellValue,
    required this.profitValue,
    required this.profitMargin,
    this.categoryName,
    this.companyName,
    this.supplierId,
    this.supplierName,
    this.lastPurchaseDate,
    this.lastSoldDate,
    this.reorderLevel,
    this.expiryDate,
    this.batchNo,
    this.stockValueCost,
    this.stockValueSell,
  });

  factory StockReport.fromMap(Map<String, dynamic> map) {
    // Safe numeric parsing
    double toDouble(dynamic value, [double fallback = 0.0]) {
      if (value == null) return fallback;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      return double.tryParse(value.toString()) ?? fallback;
    }

    int toInt(dynamic value, [int fallback = 0]) {
      if (value == null) return fallback;
      if (value is int) return value;
      return int.tryParse(value.toString()) ?? fallback;
    }

    DateTime? toDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      return DateTime.tryParse(value.toString());
    }

    final double cost = toDouble(map['cost_price']);
    final double sell = toDouble(map['sell_price']);
    final int remaining = toInt(map['remaining_qty']);

    return StockReport(
      productId: map['product_id']?.toString() ?? '',
      productName: map['product_name']?.toString() ?? '',
      categoryName: map['category_name']?.toString(),
      companyName: map['company_name']?.toString(),
      supplierId: map['supplier_id']?.toString(),
      supplierName: map['supplier_name']?.toString(),
      purchasedQty: toInt(map['purchased_qty'] ?? map['original_purchased_qty']),
      soldQty: toInt(map['sold_qty'] ?? map['sold_by_batch']),
      remainingQty: remaining,
      costPrice: cost,
      sellPrice: sell,
      lastPurchaseDate: toDate(map['last_purchase_date'] ?? map['purchase_date']),
      lastSoldDate: toDate(map['last_sold_date']),
      reorderLevel: toInt(map['reorder_level']),
      expiryDate: toDate(map['latest_expiry'] ?? map['expiry_date']),
      batchNo: map['latest_batch_no'] ?? map['batch_no'],
      totalCostValue: cost * remaining,
      totalSellValue: sell * remaining,
      profitValue: (sell - cost) * remaining,
      profitMargin: cost > 0 ? ((sell - cost) / cost) * 100 : 0,
      stockValueCost: toDouble(map['stock_value_cost']),
      stockValueSell: toDouble(map['stock_value_sell']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'product_id': productId,
      'product_name': productName,
      'category_name': categoryName,
      'company_name': companyName,
      'supplier_id': supplierId,
      'supplier_name': supplierName,
      'purchased_qty': purchasedQty,
      'sold_qty': soldQty,
      'remaining_qty': remainingQty,
      'cost_price': costPrice,
      'sell_price': sellPrice,
      'last_purchase_date': lastPurchaseDate?.toIso8601String(),
      'last_sold_date': lastSoldDate?.toIso8601String(),
      'reorder_level': reorderLevel,
      'expiry_date': expiryDate?.toIso8601String(),
      'batch_no': batchNo,
      'total_cost_value': totalCostValue,
      'total_sell_value': totalSellValue,
      'profit_value': profitValue,
      'profit_margin': profitMargin,
      'stock_value_cost': stockValueCost,
      'stock_value_sell': stockValueSell,
    };
  }
}
