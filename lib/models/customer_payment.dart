class CustomerPayment {
  final String id;
  final String customerId;
  final double amount;
  final String date;
  final String note;

  CustomerPayment({
    required this.id,
    required this.customerId,
    required this.amount,
    required this.date,
    this.note = "",
  });

  Map<String, dynamic> toMap() => {
    "id": id,
    "customer_id": customerId,
    "amount": amount,
    "date": date,
    "note": note,
  };

  factory CustomerPayment.fromMap(Map<String, dynamic> map) => CustomerPayment(
    id: map["id"],
    customerId: map["customer_id"],
    amount: map["amount"],
    date: map["date"],
    note: map["note"] ?? "",
  );
}
