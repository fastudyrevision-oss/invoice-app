class SupplierPayment {
  final String id;
  final String supplierId;
  final String? purchaseId;
  final double amount;
  final String? method;
  final String? transactionRef;
  final String? note;
  final String date;
  final String? createdAt;
  final String? updatedAt;
  final int deleted;

  const SupplierPayment({
    required this.id,
    required this.supplierId,
    this.purchaseId,
    required this.amount,
    this.method,
    this.transactionRef,
    this.note,
    required this.date,
    this.createdAt,
    this.updatedAt,
    this.deleted = 0,
  });

  /// ✅ copyWith method
  SupplierPayment copyWith({
    String? id,
    String? supplierId,
    String? purchaseId,
    double? amount,
    String? method,
    String? transactionRef,
    String? note,
    String? date,
    String? createdAt,
    String? updatedAt,
    int? deleted,
  }) {
    return SupplierPayment(
      id: id ?? this.id,
      supplierId: supplierId ?? this.supplierId,
      purchaseId: purchaseId ?? this.purchaseId,
      amount: amount ?? this.amount,
      method: method ?? this.method,
      transactionRef: transactionRef ?? this.transactionRef,
      note: note ?? this.note,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      "id": id,
      "supplier_id": supplierId,
      "purchase_id": purchaseId,
      "amount": amount,
      "method": method,
      "transaction_ref": transactionRef,
      "note": note,
      "date": date,
      "created_at": createdAt,
      "updated_at": updatedAt,
      "deleted": deleted,
    };
  }

  factory SupplierPayment.fromMap(Map<String, dynamic> map) {
    double parseAmount(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }

    int parseInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }

    return SupplierPayment(
      id: map["id"] as String,
      supplierId: map["supplier_id"] as String,
      purchaseId: map["purchase_id"] as String?,
      amount: parseAmount(map["amount"]),
      method: map["method"] as String?,
      transactionRef: map["transaction_ref"] as String?,
      note: map["note"] as String?,
      date: (map["date"] as String?) ?? DateTime.now().toIso8601String(),
      createdAt: map["created_at"] as String?,
      updatedAt: map["updated_at"] as String?,
      deleted: parseInt(map["deleted"]),
    );
  }
}
