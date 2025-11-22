class SupplierCompany {
  final String id;
  final String name;
  final String? address;
  final String? phone;
  final String? notes; // ✅ new field
  final String createdAt;
  final String updatedAt;
  final bool isSynced;
  final int deleted; // 0 = active, 1 = deleted

  SupplierCompany({
    required this.id,
    required this.name,
    this.address,
    this.phone,
    this.notes, // ✅ constructor
    required this.createdAt,
    required this.updatedAt,
    this.isSynced = false,
    this.deleted = 0, // default is active
  });

  Map<String, dynamic> toMap() {
    return {
      "id": id,
      "name": name,
      "address": address,
      "phone": phone,
      "notes": notes, // ✅ include
      "created_at": createdAt,
      "updated_at": updatedAt,
      "is_synced": isSynced ? 1 : 0,
      "deleted": deleted, // ✅ include
    };
  }

  factory SupplierCompany.fromMap(Map<String, dynamic> map) {
    return SupplierCompany(
      id: map["id"],
      name: map["name"],
      address: map["address"],
      phone: map["phone"],
      notes: map["notes"], // ✅ parse
      createdAt: map["created_at"],
      updatedAt: map["updated_at"],
      isSynced: map["is_synced"] == 1,
      deleted: map["deleted"] ?? 0, // default to 0 if missing
    );
  }

  /// ✅ Add copyWith here
  SupplierCompany copyWith({
    String? id,
    String? name,
    String? address,
    String? phone,
    String? notes,
    String? createdAt,
    String? updatedAt,
    bool? isSynced,
    int? deleted, // ✅ add deleted to copyWith
  }) {
    return SupplierCompany(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
      deleted: deleted ?? this.deleted,
    );
  }
}
