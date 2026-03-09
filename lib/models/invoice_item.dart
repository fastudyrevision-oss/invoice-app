import 'dart:convert';

class InvoiceItem {
  final String id;
  String invoiceId;
  final String productId;
  final int qty;
  final double price;
  final double costPrice; // 👈 Current cost at time of sale
  final double? discount;
  final double? tax;
  final String? batchNo; // 👈 for backward compatibility
  final String? createdAt;
  final String? updatedAt;

  /// 👇 NEW: multiple batches reserved for this item
  /// Example: [{'batchId': 'B123', 'qty': 5}, {'batchId': 'B124', 'qty': 2}]
  final List<Map<String, dynamic>>? reservedBatches;

  InvoiceItem({
    required this.id,
    required this.invoiceId,
    required this.productId,
    required this.qty,
    required this.price,
    this.costPrice = 0.0,
    this.discount,
    this.tax,
    this.batchNo,
    this.createdAt,
    this.updatedAt,
    this.reservedBatches,
  });

  // =====================================
  // ✅ Convert to Map for DB operations
  // =====================================
  Map<String, dynamic> toMap() => {
    "id": id,
    "invoice_id": invoiceId,
    "product_id": productId,
    "qty": qty,
    "price": price,
    "cost_price": costPrice,
    "discount": discount ?? 0.0,
    "tax": tax ?? 0.0,
    "batch_no": batchNo,
    "created_at": createdAt,
    "updated_at": updatedAt,

    // 👇 Convert reservedBatches (List<Map>) to JSON string
    "reserved_batches": reservedBatches != null
        ? jsonEncode(reservedBatches)
        : null,
  };

  // =====================================
  // ✅ Create from DB map
  // =====================================
  factory InvoiceItem.fromMap(Map<String, dynamic> map) => InvoiceItem(
    id: map["id"]?.toString() ?? "",
    invoiceId: map["invoice_id"]?.toString() ?? "",
    productId: map["product_id"]?.toString() ?? "",
    qty: map["qty"] is int
        ? map["qty"]
        : int.tryParse(map["qty"]?.toString() ?? "0") ?? 0,
    price: (map["price"] ?? 0.0).toDouble(),
    costPrice: (map["cost_price"] ?? 0.0).toDouble(),
    discount: (map["discount"] ?? 0.0).toDouble(),
    tax: (map["tax"] ?? 0.0).toDouble(),
    batchNo: map["batch_no"]?.toString(),
    createdAt: map["created_at"]?.toString(),
    updatedAt: map["updated_at"]?.toString(),

    // 👇 Decode JSON to List<Map<String, dynamic>>
    reservedBatches: map["reserved_batches"] != null
        ? List<Map<String, dynamic>>.from(
            jsonDecode(map["reserved_batches"].toString()),
          )
        : null,
  );

  // =====================================
  // ✅ CopyWith for updates
  // =====================================
  InvoiceItem copyWith({
    String? id,
    String? invoiceId,
    String? productId,
    int? qty,
    double? price,
    double? costPrice,
    double? discount,
    double? tax,
    String? batchNo,
    String? createdAt,
    String? updatedAt,
    List<Map<String, dynamic>>? reservedBatches,
  }) {
    return InvoiceItem(
      id: id ?? this.id,
      invoiceId: invoiceId ?? this.invoiceId,
      productId: productId ?? this.productId,
      qty: qty ?? this.qty,
      price: price ?? this.price,
      costPrice: costPrice ?? this.costPrice,
      discount: discount ?? this.discount,
      tax: tax ?? this.tax,
      batchNo: batchNo ?? this.batchNo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      reservedBatches: reservedBatches ?? this.reservedBatches,
    );
  }
}
