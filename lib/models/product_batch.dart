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
    id: map["id"]?.toString() ?? "",
    productId: map["product_id"]?.toString() ?? "",
    supplierId: map["supplier_id"]?.toString(),
    batchNo: map["batch_no"]?.toString() ?? "",
    expiryDate: map["expiry_date"]?.toString(),
    qty: (map["qty"] is int)
        ? map["qty"] as int
        : int.tryParse(map["qty"]?.toString() ?? '0') ?? 0,
    purchasePrice: (map["purchase_price"] is num)
        ? (map["purchase_price"] as num).toDouble()
        : double.tryParse(map["purchase_price"]?.toString() ?? '0') ?? 0.0,
    sellPrice: (map["sell_price"] is num)
        ? (map["sell_price"] as num).toDouble()
        : double.tryParse(map["sell_price"]?.toString() ?? '0') ?? 0.0,
    purchaseId: map["purchase_id"]?.toString(),
    createdAt:
        map["created_at"]?.toString() ?? DateTime.now().toIso8601String(),
    updatedAt:
        map["updated_at"]?.toString() ?? DateTime.now().toIso8601String(),
    isSynced: (map["is_synced"] is int)
        ? map["is_synced"] as int
        : int.tryParse(map["is_synced"]?.toString() ?? '0') ?? 0,
  );
}
