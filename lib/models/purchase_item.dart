class PurchaseItem {
  final String id;
  final String purchaseId;
  final String productId;
  final int qty;
  final double purchasePrice; // ✅ required
  final double sellPrice;
  final String? batchNo;
  final String? expiryDate;

  PurchaseItem({
    required this.id,
    required this.purchaseId,
    required this.productId,
    required this.qty,
    required this.purchasePrice,
    required this.sellPrice,
    this.batchNo,
    this.expiryDate,
  });

  factory PurchaseItem.fromMap(Map<String, dynamic> map) {
    return PurchaseItem(
      id: map['id']?.toString() ?? "",
      purchaseId: map['purchase_id']?.toString() ?? "",
      productId: map['product_id']?.toString() ?? "",
      qty: (map['qty'] is int)
          ? map['qty'] as int
          : int.tryParse(map['qty']?.toString() ?? '0') ?? 0,
      purchasePrice: (map['purchase_price'] is num)
          ? (map['purchase_price'] as num).toDouble()
          : double.tryParse(map['purchase_price']?.toString() ?? '0') ?? 0.0,
      sellPrice: (map['sell_price'] is num)
          ? (map['sell_price'] as num).toDouble()
          : double.tryParse(map['sell_price']?.toString() ?? '0') ?? 0.0,
      batchNo: map['batch_no']?.toString() ?? "",
      expiryDate: map['expiry_date']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'purchase_id': purchaseId,
      'product_id': productId,
      'qty': qty,
      'purchase_price': purchasePrice,
      'sell_price': sellPrice,
      'batch_no': batchNo,
      'expiry_date': expiryDate,
    };
  }

  PurchaseItem copyWith({
    String? id,
    String? purchaseId,
    String? productId,
    int? qty,
    double? purchasePrice,
    double? sellPrice,
    String? batchNo,
    String? expiryDate,
  }) {
    return PurchaseItem(
      id: id ?? this.id,
      purchaseId: purchaseId ?? this.purchaseId,
      productId: productId ?? this.productId,
      qty: qty ?? this.qty,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      sellPrice: sellPrice ?? this.sellPrice,
      batchNo: batchNo ?? this.batchNo,
      expiryDate: expiryDate ?? this.expiryDate,
    );
  }
}
