class CombinedPaymentEntry {
  final DateTime date;
  final String entityName; // Supplier or Customer name
  final String reference;
  final double moneyOut; // Payments to suppliers
  final double moneyIn; // Payments from customers
  final String type; // 'supplier' or 'customer'
  final String description;

  CombinedPaymentEntry({
    required this.date,
    required this.entityName,
    required this.reference,
    required this.moneyOut,
    required this.moneyIn,
    required this.type,
    required this.description,
  });
}
