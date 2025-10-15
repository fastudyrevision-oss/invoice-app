class ExpiryReport {
  final String productName;
  final String batchNo;
  final DateTime expiryDate;
  final double quantity;

  ExpiryReport({
    required this.productName,
    required this.batchNo,
    required this.expiryDate,
    required this.quantity,
  });
}
