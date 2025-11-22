import '../models/invoice.dart';
import 'package:sqflite/sqflite.dart';

class InvoiceDao {
  final DatabaseExecutor db;
  InvoiceDao(this.db);

  // =========================
  // INSERT
  // =========================
  Future<int> insert(Invoice invoice, String customerName) async {
    return await db.insert("invoices", {
      "id": invoice.id,
      "customer_id": invoice.customerId,
      "customer_name": customerName, // <-- provide the name here
      "total": invoice.total,
      "discount": invoice.discount,
      "paid": invoice.paid,
      "pending": invoice.pending,
      "date": invoice.date,
      "created_at": invoice.createdAt,
      "updated_at": invoice.updatedAt,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // =========================
  // GET ALL (simple)
  // =========================
  Future<List<Invoice>> getAll() async {
    final res = await db.query('invoices');
    return res.map((e) => Invoice.fromMap(e)).toList();
  }

  // =========================
  // =========================
  // GET ALL WITH CUSTOMER NAME (for list screen)
  // =========================
  Future<List<Invoice>> getAllInvoices() async {
    // use txn if provided

    final data = await db.rawQuery('''
      SELECT i.*, c.name as customer_name
      FROM invoices i
      LEFT JOIN customers c ON i.customer_id = c.id
      ORDER BY i.date DESC
    ''');

    // ✅ Explicitly map to List<Invoice>
    final invoices = data.map<Invoice>((e) {
      final invoice = Invoice.fromMap(e);
      invoice.customerName = e['customer_name'] as String?;
      return invoice;
    }).toList();

    return invoices;
  }

  // =========================
  // GET BY ID
  // =========================
  Future<Invoice?> getById(String id) async {
    final res = await db.rawQuery(
      '''
      SELECT i.*, c.name as customer_name
      FROM invoices i
      LEFT JOIN customers c ON i.customer_id = c.id
      WHERE i.id = ?
    ''',
      [id],
    );

    if (res.isNotEmpty) {
      final invoice = Invoice.fromMap(res.first);
      invoice.customerName = res.first['customer_name'] as String?;
      return invoice;
    }
    return null;
  }

  // =========================
  // UPDATE
  // =========================
  Future<int> update(Invoice invoice) async {
    return await db.update(
      'invoices',
      invoice.toMap(),
      where: 'id = ?',
      whereArgs: [invoice.id],
    );
  }

  // =========================
  // GET PENDING BY CUSTOMER
  // =========================
  Future<List<Invoice>> getPendingByCustomerId(String customerId) async {
    final data = await db.query(
      'invoices',
      where: 'customer_id = ? AND pending > 0',
      whereArgs: [customerId],
      orderBy: 'date ASC',
    );

    return data.map<Invoice>((e) => Invoice.fromMap(e)).toList();
  }

  // =========================
  // DELETE
  // =========================
  Future<int> delete(String id) async {
    return await db.delete('invoices', where: 'id = ?', whereArgs: [id]);
  }
}
