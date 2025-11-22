class PaymentReport {
  final String supplierName;
  final String reference; // Invoice No. or Payment Ref
  final double debit; // Purchases
  final double credit; // Payments
  final double balance; // Running balance
  final DateTime date;

  PaymentReport({
    required this.supplierName,
    required this.reference,
    required this.debit,
    required this.credit,
    required this.balance,
    required this.date,
  });

  factory PaymentReport.fromMap(Map<String, dynamic> map) {
    return PaymentReport(
      supplierName: map['supplier_name'] ?? '',
      reference: map['reference'] ?? '',
      debit: (map['debit'] ?? 0).toDouble(),
      credit: (map['credit'] ?? 0).toDouble(),
      balance: (map['balance'] ?? 0).toDouble(),
      date: DateTime.parse(map['date']),
    );
  }
}
