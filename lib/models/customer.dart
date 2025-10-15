class Customer {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final String? address;
  double pendingAmount;
  final String createdAt;
  final String updatedAt;
  final bool isSynced;

  Customer({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.address,
    this.pendingAmount = 0.0,
    required this.createdAt,
    required this.updatedAt,
    this.isSynced = false,
  });

  Map<String, dynamic> toMap() {
    return {
      "id": id,
      "name": name,
      "phone": phone,
      "email": email,
      "address": address,
      "pending_amount": pendingAmount,
      "created_at": createdAt,
      "updated_at": updatedAt,
      "is_synced": isSynced ? 1 : 0,
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map["id"],
      name: map["name"],
      phone: map["phone"],
      email: map["email"],
      address: map["address"],
      pendingAmount: map["pending_amount"] ?? 0.0,
      createdAt: map["created_at"],
      updatedAt: map["updated_at"],
      isSynced: map["is_synced"] == 1,
    );
  }
}
