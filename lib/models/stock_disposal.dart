class StockDisposal {
  final String id;
  final int? displayId; // 🔢 Counting ID (UX display, not UUID)
  final String batchId;
  final String productId;
  final String? supplierId;
  final int qty;
  final String disposalType; // 'write_off' or 'return'
  final double costLoss;
  final String? refundStatus; // 'pending', 'received', 'rejected'
  final double refundAmount;
  final String? notes;
  final String? productName;
  final String? productCode;
  final String? batchNo;
  final String? supplierName;
  final String createdAt;

  StockDisposal({
    required this.id,
    this.displayId,
    required this.batchId,
    required this.productId,
    this.supplierId,
    required this.qty,
    required this.disposalType,
    required this.costLoss,
    this.refundStatus,
    this.refundAmount = 0.0,
    this.notes,
    this.productName,
    this.productCode,
    this.batchNo,
    this.supplierName,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'display_id': displayId,
    'batch_id': batchId,
    'product_id': productId,
    'supplier_id': supplierId,
    'qty': qty,
    'disposal_type': disposalType,
    'cost_loss': costLoss,
    'refund_status': refundStatus,
    'refund_amount': refundAmount,
    'notes': notes,
    'created_at': createdAt,
  };

  factory StockDisposal.fromMap(Map<String, dynamic> map) => StockDisposal(
    id: map['id'],
    displayId: map['display_id'] as int?,
    batchId: map['batch_id'],
    productId: map['product_id'],
    supplierId: map['supplier_id'],
    qty: map['qty'] ?? 0,
    disposalType: map['disposal_type'] ?? 'write_off',
    costLoss: (map['cost_loss'] ?? 0).toDouble(),
    refundStatus: map['refund_status'],
    refundAmount: (map['refund_amount'] ?? 0).toDouble(),
    notes: map['notes'],
    productName: map['product_name'],
    productCode: map['product_code'],
    batchNo: map['batch_no'],
    supplierName: map['supplier_name'],
    createdAt: map['created_at'],
  );

  StockDisposal copyWith({
    String? id,
    int? displayId,
    String? batchId,
    String? productId,
    String? supplierId,
    int? qty,
    String? disposalType,
    double? costLoss,
    String? refundStatus,
    double? refundAmount,
    String? notes,
    String? productName,
    String? productCode,
    String? batchNo,
    String? supplierName,
    String? createdAt,
  }) {
    return StockDisposal(
      id: id ?? this.id,
      displayId: displayId ?? this.displayId,
      batchId: batchId ?? this.batchId,
      productId: productId ?? this.productId,
      supplierId: supplierId ?? this.supplierId,
      qty: qty ?? this.qty,
      disposalType: disposalType ?? this.disposalType,
      costLoss: costLoss ?? this.costLoss,
      refundStatus: refundStatus ?? this.refundStatus,
      refundAmount: refundAmount ?? this.refundAmount,
      notes: notes ?? this.notes,
      productName: productName ?? this.productName,
      productCode: productCode ?? this.productCode,
      batchNo: batchNo ?? this.batchNo,
      supplierName: supplierName ?? this.supplierName,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
