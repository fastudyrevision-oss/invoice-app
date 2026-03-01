class Invoice {
  final String id;
  final int? displayId; // UX-optimized short ID
  final String? invoiceNo; // Original tracking number
  final String customerId;
  String? customerName; // optional, added for display
  final double total;
  final double discount;
  final double paid;
  final double pending;
  final String status; // 'draft' or 'posted'
  final String date;
  final String createdAt;
  final String updatedAt;

  Invoice({
    required this.id,
    this.displayId,
    this.invoiceNo,
    required this.customerId,
    this.customerName,
    required this.total,
    this.discount = 0.0,
    this.paid = 0.0,
    required this.pending,
    this.status = 'draft',
    required this.date,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
    "id": id,
    "display_id": displayId,
    "invoice_no": invoiceNo,
    "customer_id": customerId,

    "customer_name": customerName, // not stored in DB
    "total": total,
    "discount": discount,
    "paid": paid,
    "pending": pending,
    "status": status,
    "date": date,
    "created_at": createdAt,
    "updated_at": updatedAt,
  };

  factory Invoice.fromMap(Map<String, dynamic> map) => Invoice(
    id: map["id"]?.toString() ?? '',
    displayId: map["display_id"] as int?,
    invoiceNo: map["invoice_no"]?.toString(),
    customerId: map["customer_id"]?.toString() ?? '',
    total: (map["total"] as num?)?.toDouble() ?? 0.0,
    discount: (map["discount"] as num?)?.toDouble() ?? 0.0,
    paid: (map["paid"] as num?)?.toDouble() ?? 0.0,
    pending: (map["pending"] as num?)?.toDouble() ?? 0.0,
    status: map["status"]?.toString() ?? 'draft',
    date: map["date"]?.toString() ?? DateTime.now().toIso8601String(),
    createdAt:
        map["created_at"]?.toString() ?? DateTime.now().toIso8601String(),
    updatedAt:
        map["updated_at"]?.toString() ?? DateTime.now().toIso8601String(),
  );
}
