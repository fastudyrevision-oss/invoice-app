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
        id: map['id'],
        name: map['name'],
        slug: map['slug'],
        description: map['description'],
        parentId: map['parent_id'],
        isActive: (map['is_active'] ?? 1) == 1,
        isDeleted: (map['is_deleted'] ?? 0) == 1,
        icon: map['icon'],
        color: map['color'],
        sortOrder: map['sort_order'] ?? 0,
        createdAt: map['created_at'],
        updatedAt: map['updated_at'],
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
