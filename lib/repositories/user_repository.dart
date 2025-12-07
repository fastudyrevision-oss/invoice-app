import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/app_user.dart';
import '../db/database_helper.dart';
import '../core/services/audit_logger.dart';
import '../services/auth_service.dart';

class UserRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final String _table = 'users';

  Future<List<AppUser>> getAllUsers() async {
    final db = await _dbHelper.db;
    final List<Map<String, dynamic>> maps = await db.query(_table);
    return List.generate(maps.length, (i) {
      return AppUser.fromMap(maps[i]);
    });
  }

  Future<AppUser?> getUserByUsername(String username) async {
    final db = await _dbHelper.db;
    final List<Map<String, dynamic>> maps = await db.query(
      _table,
      where: 'username = ?',
      whereArgs: [username],
    );
    if (maps.isNotEmpty) {
      return AppUser.fromMap(maps.first);
    }
    return null;
  }

  Future<AppUser?> getUserById(String id) async {
    final db = await _dbHelper.db;
    final List<Map<String, dynamic>> maps = await db.query(
      _table,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return AppUser.fromMap(maps.first);
    }
    return null;
  }

  Future<void> createUser(AppUser user, {String? executorId}) async {
    debugPrint(
      "DEBUG: UserRepository.createUser - Received executorId: $executorId",
    );
    final db = await _dbHelper.db;
    await db.insert(
      _table,
      user.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await AuditLogger.log(
      'CREATE',
      _table,
      recordId: user.id,
      userId: executorId ?? AuthService.instance.currentUser?.id ?? 'system',
      newData: user.toMap(),
    );
  }

  Future<void> updateUser(AppUser user, {String? executorId}) async {
    final db = await _dbHelper.db;
    final oldUser = await getUserById(user.id);

    await db.update(
      _table,
      user.toMap(),
      where: 'id = ?',
      whereArgs: [user.id],
    );

    await AuditLogger.log(
      'UPDATE',
      _table,
      recordId: user.id,
      userId: executorId ?? AuthService.instance.currentUser?.id ?? 'system',
      oldData: oldUser?.toMap(),
      newData: user.toMap(),
    );
  }

  Future<void> deleteUser(String id, {String? executorId}) async {
    final db = await _dbHelper.db;
    final oldUser = await getUserById(id);

    await db.delete(_table, where: 'id = ?', whereArgs: [id]);

    await AuditLogger.log(
      'DELETE',
      _table,
      recordId: id,
      userId: executorId ?? AuthService.instance.currentUser?.id ?? 'system',
      oldData: oldUser?.toMap(),
    );
  }

  // Helper to ensure admin exists. Returns true if created.
  Future<bool> ensureAdminExists() async {
    final admin = await getUserByUsername('admin');
    if (admin == null) {
      final newAdmin = AppUser(
        id: const Uuid().v4(),
        username: 'admin',
        passwordHash: 'admin123', // Default, should be changed
        role: 'developer',
        permissions: ['all'],
        createdAt: DateTime.now(),
      );
      await createUser(newAdmin);
      return true;
    }
    return false;
  }
}
