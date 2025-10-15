class Supplier {
  final String id;
  final String name;
  final String? phone;
  final String? address;
  final String? contactPerson;
  final String? companyId;
  final double pendingAmount;
  final double creditLimit;
  final String createdAt;
  final String updatedAt;
  final bool isSynced;
  final int deleted; // 0 = active, 1 = deleted

  Supplier({
    required this.id,
    required this.name,
    this.phone,
    this.address,
    this.contactPerson,
    this.companyId,
    this.pendingAmount = 0.0,
    this.creditLimit = 0.0,
    required this.createdAt,
    required this.updatedAt,
    this.isSynced = false,
    this.deleted = 0, // default active
  });

  Supplier copyWith({
    String? id,
    String? name,
    String? phone,
    String? address,
    String? contactPerson,
    String? companyId,
    double? pendingAmount,
    double? creditLimit,
    String? createdAt,
    String? updatedAt,
    bool? isSynced,
    int? deleted,
  }) {
    return Supplier(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      contactPerson: contactPerson ?? this.contactPerson,
      companyId: companyId ?? this.companyId,
      pendingAmount: pendingAmount ?? this.pendingAmount,
      creditLimit: creditLimit ?? this.creditLimit,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
      deleted: deleted ?? this.deleted,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      "id": id,
      "name": name,
      "phone": phone,
      "address": address,
      "contact_person": contactPerson,
      "company_id": companyId,
      "pending_amount": pendingAmount,
      "credit_limit": creditLimit,
      "created_at": createdAt,
      "updated_at": updatedAt,
      "is_synced": isSynced ? 1 : 0,
      "deleted": deleted, // include deleted
    };
  }

  factory Supplier.fromMap(Map<String, dynamic> map) {
    return Supplier(
      id: map["id"],
      name: map["name"],
      phone: map["phone"],
      address: map["address"],
      contactPerson: map["contact_person"],
      companyId: map["company_id"],
      pendingAmount: (map["pending_amount"] ?? 0.0).toDouble(),
      creditLimit: (map["credit_limit"] ?? 0.0).toDouble(),
      createdAt: map["created_at"],
      updatedAt: map["updated_at"],
      isSynced: map["is_synced"] == 1,
      deleted: map["deleted"] ?? 0, // parse deleted
    );
  }
}
