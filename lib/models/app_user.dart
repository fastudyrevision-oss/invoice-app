class AppUser {
  final String id;
  final String username;
  final String passwordHash;
  final String role; // 'developer', 'staff'
  final List<String> permissions;
  final DateTime? createdAt;

  AppUser({
    required this.id,
    required this.username,
    required this.passwordHash,
    required this.role,
    required this.permissions,
    this.createdAt,
  });

  bool get isDeveloper => role == 'developer';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'password_hash': passwordHash,
      'role': role,
      'permissions': permissions.join(','), // Store as CSV
      'created_at': createdAt?.toIso8601String(),
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'] ?? '',
      username: map['username'] ?? '',
      passwordHash: map['password_hash'] ?? '',
      role: map['role'] ?? 'staff',
      permissions: (map['permissions'] as String?)?.split(',') ?? [],
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : null,
    );
  }
}
