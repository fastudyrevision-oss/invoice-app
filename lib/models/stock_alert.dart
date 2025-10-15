class StockAlert {
  final String productId;
  final String productName;
  final String? batchNo;
  final String? expiryDate;   // null if not applicable
  final int qty;
  final int minStock;
  final bool isExpired;
  final bool isLowStock;

  StockAlert({
    required this.productId,
    required this.productName,
    this.batchNo,
    this.expiryDate,
    required this.qty,
    required this.minStock,
    this.isExpired = false,
    this.isLowStock = false,
  });

  Map<String, dynamic> toMap() => {
        "product_id": productId,
        "product_name": productName,
        "batch_no": batchNo,
        "expiry_date": expiryDate,
        "qty": qty,
        "min_stock": minStock,
        "is_expired": isExpired ? 1 : 0,
        "is_low_stock": isLowStock ? 1 : 0,
      };
}
