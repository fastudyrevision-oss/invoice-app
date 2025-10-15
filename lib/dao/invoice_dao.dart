import '../db/database_helper.dart';
import '../models/invoice.dart';

class InvoiceDao {
  final dynamic txn; // optional transaction
  final dbHelper = DatabaseHelper.instance;

  InvoiceDao([this.txn]);

  // =========================
  // INSERT
  // =========================
  Future<int> insert(Invoice invoice, String customerName) async {
  final db = await dbHelper.db;

  return await db.insert(
    "invoices",
    {
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
    },
  );
  }

  // =========================
  // GET ALL (simple)
  // =========================
  Future<List<Invoice>> getAll() async {
    final db = txn ?? await dbHelper.db;
    final res = await db.query('invoices');
    return res.map((e) => Invoice.fromMap(e)).toList();
  }

  // =========================
  // =========================
// GET ALL WITH CUSTOMER NAME (for list screen)
// =========================
  Future<List<Invoice>> getAllInvoices() async {
    final db = txn ?? await dbHelper.db; // use txn if provided

    final data = await db.rawQuery('''
      SELECT i.*, c.name as customer_name
      FROM invoices i
      LEFT JOIN customers c ON i.customer_id = c.id
      ORDER BY i.date DESC
    ''');

    // ✅ Explicitly map to List<Invoice>
    final invoices = data.map<Invoice>((e) {
      final invoice = Invoice.fromMap(e);
      invoice.customerName = e['customer_name'];
      return invoice;
    }).toList();

    return invoices;
  }


  // =========================
  // GET BY ID
  // =========================
  Future<Invoice?> getById(String id) async {
    final db = txn ?? await dbHelper.db;
    final res = await db.rawQuery('''
      SELECT i.*, c.name as customer_name
      FROM invoices i
      LEFT JOIN customers c ON i.customer_id = c.id
      WHERE i.id = ?
    ''', [id]);

    if (res.isNotEmpty) {
      final invoice = Invoice.fromMap(res.first);
      invoice.customerName = res.first['customer_name'];
      return invoice;
    }
    return null;
  }

  // =========================
  // UPDATE
  // =========================
  Future<int> update(Invoice invoice) async {
    final db = txn ?? await dbHelper.db;
    return await db.update(
      'invoices',
      invoice.toMap(),
      where: 'id = ?',
      whereArgs: [invoice.id],
    );
  }

  // =========================
  // DELETE
  // =========================
  Future<int> delete(String id) async {
    final db = txn ?? await dbHelper.db;
    return await db.delete('invoices', where: 'id = ?', whereArgs: [id]);
  }
}
