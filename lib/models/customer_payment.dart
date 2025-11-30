class CustomerPayment {
  final String id;
  final String customerId;
  final String? invoiceId;
  final double amount;
  final String method; // cash, card, bank_transfer, etc.
  final String? transactionRef;
  final String? note;
  final String date;
  final String? createdAt;
  final String? updatedAt;

  CustomerPayment({
    required this.id,
    required this.customerId,
    this.invoiceId,
    required this.amount,
    this.method = 'cash',
    this.transactionRef,
    this.note,
    required this.date,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
    "id": id,
    "customer_id": customerId,
    "invoice_id": invoiceId,
    "amount": amount,
    "method": method,
    "transaction_ref": transactionRef,
    "note": note,
    "date": date,
    "created_at": createdAt ?? DateTime.now().toIso8601String(),
    "updated_at": updatedAt ?? DateTime.now().toIso8601String(),
  };

  factory CustomerPayment.fromMap(Map<String, dynamic> map) => CustomerPayment(
    id: map["id"],
    customerId: map["customer_id"],
    invoiceId: map["invoice_id"],
    amount: (map["amount"] as num).toDouble(),
    method: map["method"] ?? 'cash',
    transactionRef: map["transaction_ref"],
    note: map["note"],
    date: map["date"],
    createdAt: map["created_at"],
    updatedAt: map["updated_at"],
  );

  CustomerPayment copyWith({
    String? id,
    String? customerId,
    String? invoiceId,
    double? amount,
    String? method,
    String? transactionRef,
    String? note,
    String? date,
    String? createdAt,
    String? updatedAt,
  }) {
    return CustomerPayment(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      invoiceId: invoiceId ?? this.invoiceId,
      amount: amount ?? this.amount,
      method: method ?? this.method,
      transactionRef: transactionRef ?? this.transactionRef,
      note: note ?? this.note,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
