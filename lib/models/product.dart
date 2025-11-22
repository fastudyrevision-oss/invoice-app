class Product {
  final String id;
  final String name;
  final String description;
  final String sku;
  final String defaultUnit;
  final double costPrice;
  final double sellPrice;
  final int quantity;
  final int minStock;
  final bool trackExpiry;
  final String? supplierId;

  final String createdAt;
  final String updatedAt;
  final bool isDeleted; // ✅ NEW field
  String? categoryId; // NEW

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.sku,
    required this.defaultUnit,
    required this.costPrice,
    required this.sellPrice,
    required this.quantity,
    required this.minStock,
    required this.trackExpiry,
    required this.supplierId,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false, // default is false
    this.categoryId, // NEW
  });

  Product copyWith({
    String? id,
    String? name,
    String? description,
    String? sku,
    String? defaultUnit,
    double? costPrice,
    double? sellPrice,
    int? quantity,
    int? minStock,
    bool? trackExpiry,
    String? supplierId,
    String? createdAt,
    String? updatedAt,
    bool? isDeleted,
    String? categoryId, // NEW
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      sku: sku ?? this.sku,
      defaultUnit: defaultUnit ?? this.defaultUnit,
      costPrice: costPrice ?? this.costPrice,
      sellPrice: sellPrice ?? this.sellPrice,
      quantity: quantity ?? this.quantity,
      minStock: minStock ?? this.minStock,
      trackExpiry: trackExpiry ?? this.trackExpiry,
      supplierId: supplierId ?? this.supplierId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      categoryId: categoryId ?? this.categoryId, // NEW
    );
  }

  Map<String, dynamic> toMap() {
    return {
      "id": id,
      "name": name,
      "description": description,
      "sku": sku,
      "default_unit": defaultUnit,
      "cost_price": costPrice,
      "sell_price": sellPrice,
      "quantity": quantity,
      "min_stock": minStock,
      "track_expiry": trackExpiry ? 1 : 0,
      "supplier_id": supplierId,
      "created_at": createdAt,
      "updated_at": updatedAt,
      "is_deleted": isDeleted ? 1 : 0, // ✅ store as integer
      'category_id': categoryId, // NEW
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map["id"] ?? "",
      name: map["name"] ?? "",
      description: map["description"] ?? "",
      sku: map["sku"] ?? "N/A",
      defaultUnit: map["default_unit"] ?? "pcs",
      costPrice: (map["cost_price"] ?? 0).toDouble(),
      sellPrice: (map["sell_price"] ?? 0).toDouble(),
      quantity: (map["quantity"] ?? 0).toInt(),
      minStock: (map["min_stock"] ?? 0).toInt(),
      trackExpiry: (map["track_expiry"] ?? 0) == 1,
      supplierId: map["supplier_id"],
      createdAt: map["created_at"] ?? DateTime.now().toIso8601String(),
      updatedAt: map["updated_at"] ?? DateTime.now().toIso8601String(),
      isDeleted: (map["is_deleted"] ?? 0) == 1, // ✅ default false
      categoryId: map['category_id'], // NEW
    );
  }
}
