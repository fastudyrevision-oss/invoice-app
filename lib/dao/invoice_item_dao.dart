import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../db/database_helper.dart';
import '../models/invoice_item.dart';

class InvoiceItemDao {
  final dynamic txn; // can be Database or Transaction
  final dbHelper = DatabaseHelper.instance;

  InvoiceItemDao([this.txn]);

  // =========================
  // INSERT
  // =========================
  Future<int> insert(InvoiceItem item) async {
    final db = txn ?? await dbHelper.db;

    // Encode reservedBatches before insert
    final data = item.toMap();
    data['reserved_batches'] = item.reservedBatches != null
        ? jsonEncode(item.reservedBatches)
        : null;

    return await db.insert(
      "invoice_items",
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // =========================
  // BULK INSERT (Optional)
  // =========================
  Future<void> insertAll(List<InvoiceItem> items) async {
    final db = txn ?? await dbHelper.db;
    final batch = db.batch();
    for (final item in items) {
      final data = item.toMap();
      data['reserved_batches'] = item.reservedBatches != null
          ? jsonEncode(item.reservedBatches)
          : null;
      batch.insert(
        "invoice_items",
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  // =========================
  // GET BY INVOICE ID
  // =========================
  Future<List<InvoiceItem>> getByInvoiceId(String invoiceId) async {
    final db = txn ?? await dbHelper.db;
    final res = await db.query(
      "invoice_items",
      where: "invoice_id = ?",
      whereArgs: [invoiceId],
    );

    return res.map((e) {
      // Decode reserved_batches JSON if present
      if (e['reserved_batches'] != null && e['reserved_batches'] is String) {
        try {
          e['reserved_batches'] = List<Map<String, dynamic>>.from(
            jsonDecode(e['reserved_batches']),
          );
        } catch (_) {
          e['reserved_batches'] = [];
        }
      }
      return InvoiceItem.fromMap(e);
    }).toList();
  }

  // =========================
  // GET ALL ITEMS
  // =========================
  Future<List<InvoiceItem>> getAll() async {
    final db = txn ?? await dbHelper.db;
    final res = await db.query("invoice_items");

    return res.map((e) {
      if (e['reserved_batches'] != null && e['reserved_batches'] is String) {
        try {
          e['reserved_batches'] = List<Map<String, dynamic>>.from(
            jsonDecode(e['reserved_batches']),
          );
        } catch (_) {
          e['reserved_batches'] = [];
        }
      }
      return InvoiceItem.fromMap(e);
    }).toList();
  }

  // =========================
  // UPDATE
  // =========================
  Future<int> update(InvoiceItem item) async {
    final db = txn ?? await dbHelper.db;
    final data = item.toMap();
    data['reserved_batches'] = item.reservedBatches != null
        ? jsonEncode(item.reservedBatches)
        : null;

    return await db.update(
      "invoice_items",
      data,
      where: "id = ?",
      whereArgs: [item.id],
    );
  }

  // =========================
  // DELETE BY ID
  // =========================
  Future<int> delete(String id) async {
    final db = txn ?? await dbHelper.db;
    return await db.delete("invoice_items", where: "id = ?", whereArgs: [id]);
  }

  // =========================
  // DELETE ALL BY INVOICE ID
  // =========================
  Future<int> deleteByInvoiceId(String invoiceId) async {
    final db = txn ?? await dbHelper.db;
    return await db.delete(
      "invoice_items",
      where: "invoice_id = ?",
      whereArgs: [invoiceId],
    );
  }

  // =========================
  // CHECK IF BATCH IS USED IN ANY INVOICE ITEM
  // =========================
  Future<bool> isBatchUsed(String batchId) async {
    final db = txn ?? await dbHelper.db;

    final res = await db.rawQuery(
      '''
      SELECT COUNT(*) as count FROM invoice_items
      WHERE reserved_batches LIKE ?
    ''',
      ['%"batchId":"$batchId"%'],
    ); // 👈 checks JSON text for that batch ID

    return (Sqflite.firstIntValue(res) ?? 0) > 0;
  }

  // =========================
  // GET ALL ITEMS USING A SPECIFIC BATCH
  // =========================
  Future<List<InvoiceItem>> getItemsByBatch(String batchId) async {
    final db = txn ?? await dbHelper.db;
    final res = await db.rawQuery(
      '''
      SELECT * FROM invoice_items
      WHERE reserved_batches LIKE ?
    ''',
      ['%"batchId":"$batchId"%'],
    );

    return res.map((e) => InvoiceItem.fromMap(e)).toList();
  }
}
