import 'package:sqflite/sqflite.dart';
import '../db/database_helper.dart';
import '../models/category.dart';
import '../core/services/audit_logger.dart';
import '../services/auth_service.dart';

class CategoryDao {
  final DatabaseExecutor db;
  CategoryDao(this.db);

  static Future<CategoryDao> create() async {
    final dbInstance = await DatabaseHelper.instance.db;
    return CategoryDao(dbInstance);
  }

  Future<int> insert(Category c) async {
    final id = await db.insert(
      'categories',
      c.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await AuditLogger.log(
      'CREATE',
      'categories',
      recordId: c.id,
      userId: AuthService.instance.currentUser?.id ?? 'system',
      newData: c.toMap(),
      txn: db,
    );

    return id;
  }

  Future<int> update(Category c) async {
    // Fetch old data
    final oldData = await getById(c.id, includeDeleted: true);

    final count = await db.update(
      'categories',
      c.toMap(),
      where: 'id = ?',
      whereArgs: [c.id],
    );

    await AuditLogger.log(
      'UPDATE',
      'categories',
      recordId: c.id,
      userId: AuthService.instance.currentUser?.id ?? 'system',
      oldData: oldData?.toMap(),
      newData: c.toMap(),
      txn: db,
    );

    return count;
  }

  Future<int> delete(String id) async {
    // Fetch old data
    final oldData = await getById(id, includeDeleted: true);

    final count = await db.update(
      'categories',
      {'is_deleted': 1, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );

    if (oldData != null) {
      await AuditLogger.log(
        'DELETE',
        'categories',
        recordId: id,
        userId: AuthService.instance.currentUser?.id ?? 'system',
        oldData: oldData.toMap(),
        txn: db,
      );
    }

    return count;
  }

  Future<Category?> getById(String id, {bool includeDeleted = false}) async {
    final res = await db.query(
      'categories',
      where: includeDeleted ? 'id = ?' : 'id = ? AND is_deleted = 0',
      whereArgs: [id],
      limit: 1,
    );
    return res.isNotEmpty ? Category.fromMap(res.first) : null;
  }

  Future<List<Category>> getAll({bool includeDeleted = false}) async {
    final res = await db.query(
      'categories',
      where: includeDeleted ? null : 'is_deleted = 0',
      orderBy: 'sort_order ASC, name ASC',
    );
    return res.map((e) => Category.fromMap(e)).toList();
  }

  Future<List<Category>> getAllPaged(
    int offset,
    int limit, {
    bool includeDeleted = false,
    String? searchQuery,
  }) async {
    // Better WHERE logic
    final List<String> whereClauses = [];
    final List<dynamic> args = [];

    if (!includeDeleted) {
      whereClauses.add('is_deleted = 0');
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = '%${searchQuery.trim()}%';
      whereClauses.add('(name LIKE ? OR slug LIKE ? OR description LIKE ?)');
      args.addAll([q, q, q]);
    }

    final finalWhere = whereClauses.isEmpty ? null : whereClauses.join(' AND ');

    final res = await db.query(
      'categories',
      where: finalWhere,
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'sort_order ASC, name ASC',
      limit: limit,
      offset: offset,
    );
    return res.map((e) => Category.fromMap(e)).toList();
  }
}
