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
      id: map['id'],
      purchaseId: map['purchase_id'],
      productId: map['product_id'],
      qty: map['qty'],
      purchasePrice: map['purchase_price'] * 1.0,
      sellPrice: map['sell_price'] * 1.0,
      batchNo: map['batch_no'],
      expiryDate: map['expiry_date'],
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
