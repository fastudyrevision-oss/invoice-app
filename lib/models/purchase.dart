class Purchase {
  final String id;
  final int? displayId; // UX-optimized short ID
  final String supplierId;
  final String invoiceNo;
  final double total;
  final double paid;
  final double pending;
  final String date;
  final String createdAt;
  final String updatedAt;

  Purchase({
    required this.id,
    this.displayId,
    required this.supplierId,
    required this.invoiceNo,
    required this.total,
    required this.paid,
    required this.pending,
    required this.date,
    required this.createdAt,
    required this.updatedAt,
  });

  Purchase copyWith({
    String? id,
    int? displayId,
    String? supplierId,
    String? invoiceNo,
    double? total,
    double? paid,
    double? pending,
    String? date,
    String? createdAt,
    String? updatedAt,
  }) {
    return Purchase(
      id: id ?? this.id,
      displayId: displayId ?? this.displayId,
      supplierId: supplierId ?? this.supplierId,
      invoiceNo: invoiceNo ?? this.invoiceNo,
      total: total ?? this.total,
      paid: paid ?? this.paid,
      pending: pending ?? this.pending,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
    "id": id,
    "display_id": displayId,
    "supplier_id": supplierId,
    "invoice_no": invoiceNo,
    "total": total,
    "paid": paid,
    "pending": pending,
    "date": date,
    "created_at": createdAt,
    "updated_at": updatedAt,
  };

  factory Purchase.fromMap(Map<String, dynamic> map) => Purchase(
    id: map["id"],
    displayId: map["display_id"] as int?,
    supplierId: map["supplier_id"],
    invoiceNo: map["invoice_no"],
    total: (map["total"] ?? 0).toDouble(),
    paid: (map["paid"] ?? 0).toDouble(),
    pending: (map["pending"] ?? 0).toDouble(),
    date: map["date"],
    createdAt: map["created_at"],
    updatedAt: map["updated_at"],
  );
}
