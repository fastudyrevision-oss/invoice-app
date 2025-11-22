class ProductBatch {
  final String id;
  final String productId;
  final String? supplierId; // new: to track supplier per batch
  final String? batchNo;
  final String? expiryDate;
  int qty;
  final double? purchasePrice;
  final double? sellPrice;
  final String? purchaseId;
  final String createdAt;
  final String updatedAt;
  final int isSynced; // new: for sync tracking (0 = local, 1 = synced)

  ProductBatch({
    required this.id,
    required this.productId,
    this.supplierId,
    this.batchNo,
    this.expiryDate,
    required this.qty,
    this.purchasePrice,
    this.sellPrice,
    this.purchaseId,
    required this.createdAt,
    required this.updatedAt,
    this.isSynced = 0,
  });

  ProductBatch copyWith({
    String? id,
    String? productId,
    String? supplierId,
    String? batchNo,
    String? expiryDate,
    int? qty,
    double? purchasePrice,
    double? sellPrice,
    String? purchaseId,
    String? createdAt,
    String? updatedAt,
    int? isSynced,
  }) {
    return ProductBatch(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      supplierId: supplierId ?? this.supplierId,
      batchNo: batchNo ?? this.batchNo,
      expiryDate: expiryDate ?? this.expiryDate,
      qty: qty ?? this.qty,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      sellPrice: sellPrice ?? this.sellPrice,
      purchaseId: purchaseId ?? this.purchaseId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  Map<String, dynamic> toMap() => {
    "id": id,
    "product_id": productId,
    "supplier_id": supplierId,
    "batch_no": batchNo,
    "expiry_date": expiryDate,
    "qty": qty,
    "purchase_price": purchasePrice,
    "sell_price": sellPrice,
    "purchase_id": purchaseId,
    "created_at": createdAt,
    "updated_at": updatedAt,
    "is_synced": isSynced,
  };

  factory ProductBatch.fromMap(Map<String, dynamic> map) => ProductBatch(
    id: map["id"],
    productId: map["product_id"],
    supplierId: map["supplier_id"],
    batchNo: map["batch_no"],
    expiryDate: map["expiry_date"],
    qty: map["qty"] ?? 0,
    purchasePrice: (map["purchase_price"] ?? 0).toDouble(),
    sellPrice: (map["sell_price"] ?? 0).toDouble(),
    purchaseId: map["purchase_id"],
    createdAt: map["created_at"],
    updatedAt: map["updated_at"],
    isSynced: map["is_synced"] ?? 0,
  );
}
