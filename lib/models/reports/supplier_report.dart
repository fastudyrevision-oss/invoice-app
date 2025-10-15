class SupplierReport {
  final String supplierId;
  final String supplierName;
  final double totalPurchases;
  final double totalPaid;
  final double balance;

  SupplierReport({
    required this.supplierId,
    required this.supplierName,
    required this.totalPurchases,
    required this.totalPaid,
    required this.balance,
  });

  factory SupplierReport.fromMap(Map<String, dynamic> map) {
    return SupplierReport(
      supplierId: map['supplier_id'].toString(),
      supplierName: map['supplier_name'] ?? '',
      totalPurchases: (map['total_purchases'] ?? 0).toDouble(),
      totalPaid: (map['total_paid'] ?? 0).toDouble(),
      balance: (map['balance'] ?? 0).toDouble(),
    );
  }
}
