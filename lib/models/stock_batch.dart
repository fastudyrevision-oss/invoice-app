class StockBatch {
  final String batchNo;
  final int productId;
  final String productName;
  final int purchasedQty;
  final double costPrice;
  final double sellPrice;
  final DateTime? expiryDate;
  final String? supplierName;
  final int? supplierId;
  final String? companyName;
  final DateTime? purchaseDate;
  final DateTime? lastSoldDate;

  // Optional runtime fields for report calculations (not from DB)
  final int? soldByBatch;
  final int? totalSoldForProduct;
  final int? currentQty;

  StockBatch({
    required this.batchNo,
    required this.productId,
    required this.productName,
    required this.purchasedQty,
    required this.costPrice,
    required this.sellPrice,
    this.expiryDate,
    this.supplierName,
    this.supplierId,
    this.companyName,
    this.purchaseDate,
    this.lastSoldDate,
    this.soldByBatch,
    this.totalSoldForProduct,
    this.currentQty,
  });

  factory StockBatch.fromMap(Map<String, dynamic> map) {
    // 🧠 Safe helper to parse numbers regardless of type
    int toInt(dynamic value, [int fallback = 0]) {
      if (value == null) return fallback;
      if (value is int) return value;
      return int.tryParse(value.toString()) ?? fallback;
    }

    double toDouble(dynamic value, [double fallback = 0.0]) {
      if (value == null) return fallback;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      return double.tryParse(value.toString()) ?? fallback;
    }

    DateTime? toDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      return DateTime.tryParse(value.toString());
    }

    return StockBatch(
      batchNo: map['batch_no']?.toString() ?? '',
      productId: toInt(map['product_id']),
      productName: map['product_name']?.toString() ?? '',
      purchasedQty: toInt(map['purchased_qty'] ??
          map['original_purchased_qty'] ??
          map['qty']),
      costPrice: toDouble(map['cost_price']),
      sellPrice: toDouble(map['sell_price']),
      expiryDate: toDate(map['expiry_date']),
      supplierName: map['supplier_name']?.toString(),
      supplierId: toInt(map['supplier_id']),
      companyName: map['company_name']?.toString(),
      purchaseDate: toDate(map['purchase_date'] ?? map['batch_created_at']),
      lastSoldDate: toDate(map['last_sold_date']),
      soldByBatch: toInt(map['sold_by_batch']),
      totalSoldForProduct: toInt(map['total_sold_for_product']),
      currentQty: toInt(map['current_qty']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'batch_no': batchNo,
      'product_id': productId,
      'product_name': productName,
      'purchased_qty': purchasedQty,
      'cost_price': costPrice,
      'sell_price': sellPrice,
      'expiry_date': expiryDate?.toIso8601String(),
      'supplier_name': supplierName,
      'supplier_id': supplierId,
      'company_name': companyName,
      'purchase_date': purchaseDate?.toIso8601String(),
      'last_sold_date': lastSoldDate?.toIso8601String(),
      'sold_by_batch': soldByBatch,
      'total_sold_for_product': totalSoldForProduct,
      'current_qty': currentQty,
    };
  }
}
