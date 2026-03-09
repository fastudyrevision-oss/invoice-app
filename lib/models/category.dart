class Category {
  final String id;
  final String name;
  final String? slug;
  final String? description;
  final String? parentId;
  final bool isActive;
  final bool isDeleted;
  final String? icon;
  final String? color;
  final int sortOrder;
  final String createdAt;
  final String updatedAt;

  Category({
    required this.id,
    required this.name,
    this.slug,
    this.description,
    this.parentId,
    this.isActive = true,
    this.isDeleted = false,
    this.icon,
    this.color,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Category.fromMap(Map<String, dynamic> map) => Category(
    id: map['id']?.toString() ?? "",
    name: map['name']?.toString() ?? "General",
    slug: map['slug']?.toString(),
    description: map['description']?.toString(),
    parentId: map['parent_id']?.toString(),
    isActive: (map['is_active'] ?? 1) == 1,
    isDeleted: (map['is_deleted'] ?? 0) == 1,
    icon: map['icon']?.toString(),
    color: map['color']?.toString(),
    sortOrder: (map['sort_order'] ?? 0) as int,
    createdAt:
        map['created_at']?.toString() ?? DateTime.now().toIso8601String(),
    updatedAt:
        map['updated_at']?.toString() ?? DateTime.now().toIso8601String(),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'slug': slug,
    'description': description,
    'parent_id': parentId,
    'is_active': isActive ? 1 : 0,
    'is_deleted': isDeleted ? 1 : 0,
    'icon': icon,
    'color': color,
    'sort_order': sortOrder,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };

  Category copyWith({
    String? id,
    String? name,
    String? slug,
    String? description,
    String? parentId,
    bool? isActive,
    bool? isDeleted,
    String? icon,
    String? color,
    int? sortOrder,
    String? createdAt,
    String? updatedAt,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      description: description ?? this.description,
      parentId: parentId ?? this.parentId,
      isActive: isActive ?? this.isActive,
      isDeleted: isDeleted ?? this.isDeleted,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
