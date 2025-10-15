class ProductBatch {
  final String id;
  final String productId;
  final String batchNo;
  final String? expiryDate;
  int qty;
  final double purchasePrice;
  final double sellPrice;
  final String purchaseId;
  final String createdAt;
  final String updatedAt;

  ProductBatch({
    required this.id,
    required this.productId,
    required this.batchNo,
    this.expiryDate,
    required this.qty,
    required this.purchasePrice,
    required this.sellPrice,
    required this.purchaseId,
    required this.createdAt,
    required this.updatedAt,
  });

  ProductBatch copyWith({
    String? id,
    String? productId,
    String? batchNo,
    String? expiryDate,
    int? qty,
    double? purchasePrice,
    double? sellPrice,
    String? purchaseId,
    String? createdAt,
    String? updatedAt,
  }) {
    return ProductBatch(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      batchNo: batchNo ?? this.batchNo,
      expiryDate: expiryDate ?? this.expiryDate,
      qty: qty ?? this.qty,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      sellPrice: sellPrice ?? this.sellPrice,
      purchaseId: purchaseId ?? this.purchaseId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        "id": id,
        "product_id": productId,
        "batch_no": batchNo,
        "expiry_date": expiryDate,
        "qty": qty,
        "purchase_price": purchasePrice,
        "sell_price": sellPrice,
        "purchase_id": purchaseId,
        "created_at": createdAt,
        "updated_at": updatedAt,
      };

  factory ProductBatch.fromMap(Map<String, dynamic> map) => ProductBatch(
        id: map["id"],
        productId: map["product_id"],
        batchNo: map["batch_no"],
        expiryDate: map["expiry_date"],
        qty: map["qty"],
        purchasePrice: (map["purchase_price"] ?? 0).toDouble(),
        sellPrice: (map["sell_price"] ?? 0).toDouble(),
        purchaseId: map["purchase_id"],
        createdAt: map["created_at"],
        updatedAt: map["updated_at"],
      );
}
