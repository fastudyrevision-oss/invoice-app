class Invoice {
  final String id;
  final String customerId;
  String? customerName; // optional, added for display
  final double total;
  final double discount;
  final double paid;
  final double pending;
  final String date;
  final String createdAt;
  final String updatedAt;

  Invoice({
    required this.id,
    required this.customerId,
    this.customerName,
    required this.total,
    this.discount = 0.0,
    this.paid = 0.0,
    required this.pending,
    required this.date,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
    "id": id,
    "customer_id": customerId,

    "customer_name": customerName, // not stored in DB
    "total": total,
    "discount": discount,
    "paid": paid,
    "pending": pending,
    "date": date,
    "created_at": createdAt,
    "updated_at": updatedAt,
  };

  factory Invoice.fromMap(Map<String, dynamic> map) => Invoice(
    id: map["id"],
    customerId: map["customer_id"],
    total: map["total"],
    discount: map["discount"] ?? 0.0,
    paid: map["paid"] ?? 0.0,
    pending: map["pending"],
    date: map["date"],
    createdAt: map["created_at"],
    updatedAt: map["updated_at"],
  );
}
