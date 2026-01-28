class ExpiringBatchDetail {
  final String batchId;
  final String batchNo;
  final DateTime expiryDate;
  final int qty;
  final String productId;
  final String productName;
  final String? supplierId;
  final String? supplierName;
  final String? supplierPhone;
  final String? supplierAddress;
  final String purchaseId;
  final double? purchasePrice;

  ExpiringBatchDetail({
    required this.batchId,
    required this.batchNo,
    required this.expiryDate,
    required this.qty,
    required this.productId,
    required this.productName,
    this.supplierId,
    this.supplierName,
    this.supplierPhone,
    this.supplierAddress,
    required this.purchaseId,
    this.purchasePrice,
  });

  factory ExpiringBatchDetail.fromMap(Map<String, dynamic> map) {
    return ExpiringBatchDetail(
      batchId: map['batch_id'] ?? map['id'] ?? '',
      batchNo: map['batch_no'] ?? '',
      expiryDate: DateTime.tryParse(map['expiry_date'] ?? '') ?? DateTime.now(),
      qty: map['qty'] ?? 0,
      productId: map['product_id'] ?? '',
      productName: map['product_name'] ?? 'Unknown',
      supplierId: map['supplier_id'],
      supplierName: map['supplier_name'],
      supplierPhone: map['supplier_phone'],
      supplierAddress: map['supplier_address'],
      purchaseId: map['purchase_id'] ?? '',
      purchasePrice: (map['purchase_price'] as num?)?.toDouble(),
    );
  }
}
