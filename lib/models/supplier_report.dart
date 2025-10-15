class SupplierReport {
  final String supplierId;
  final String supplierName;
  final String? companyName;
  final double totalPurchases;
  final double totalPaid;
  final double totalPending;

  SupplierReport({
    required this.supplierId,
    required this.supplierName,
    this.companyName,
    this.totalPurchases = 0.0,
    this.totalPaid = 0.0,
    this.totalPending = 0.0,
  });

  Map<String, dynamic> toMap() => {
        "supplier_id": supplierId,
        "supplier_name": supplierName,
        "company_name": companyName,
        "total_purchases": totalPurchases,
        "total_paid": totalPaid,
        "total_pending": totalPending,
      };

  factory SupplierReport.fromMap(Map<String, dynamic> map) => SupplierReport(
        supplierId: map["supplier_id"].toString(),
        supplierName: map["supplier_name"],
        companyName: map["company_name"],
        totalPurchases: map["total_purchases"] ?? 0.0,
        totalPaid: map["total_paid"] ?? 0.0,
        totalPending: map["total_pending"] ?? 0.0,
      );
}
