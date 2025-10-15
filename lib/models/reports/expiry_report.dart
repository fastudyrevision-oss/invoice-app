class ExpiryReport {
  final String productName;
  final String batchNo;
  final DateTime expiryDate;
  final double qty;

  ExpiryReport({
    required this.productName,
    required this.batchNo,
    required this.expiryDate,
    required this.qty,
  });

  factory ExpiryReport.fromMap(Map<String, dynamic> map) {
    return ExpiryReport(
      productName: map['product_name'],
      batchNo: map['batch_no'],
      expiryDate: DateTime.parse(map['expiry_date']),
      qty: (map['qty'] ?? 0).toDouble(),
    );
  }
}
