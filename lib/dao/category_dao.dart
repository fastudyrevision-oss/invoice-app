import 'package:sqflite/sqflite.dart';
import '../db/database_helper.dart';
import '../models/category.dart';

class CategoryDao {
  final DatabaseExecutor db;
  CategoryDao(this.db);

  static Future<CategoryDao> create() async {
    final dbInstance = await DatabaseHelper.instance.db;
    return CategoryDao(dbInstance);
  }

  Future<int> insert(Category c) async {
    return await db.insert(
      'categories',
      c.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> update(Category c) async {
    return await db.update(
      'categories',
      c.toMap(),
      where: 'id = ?',
      whereArgs: [c.id],
    );
  }

  Future<int> delete(String id) async {
    return await db.update(
      'categories',
      {'is_deleted': 1, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
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
}
