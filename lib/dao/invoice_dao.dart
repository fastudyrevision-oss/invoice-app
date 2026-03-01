import '../models/invoice.dart';
import 'package:sqflite/sqflite.dart';
import '../core/services/audit_logger.dart';
import '../services/auth_service.dart';

class InvoiceDao {
  final DatabaseExecutor db;
  InvoiceDao(this.db);

  // =========================
  // INSERT
  // =========================
  Future<int> insert(Invoice invoice, String customerName) async {
    // 🔢 Calculate next short ID (UX column)
    final lastIdRes = await db.rawQuery(
      "SELECT MAX(display_id) as last_id FROM invoices",
    );
    final nextDisplayId = (lastIdRes.first['last_id'] as int? ?? 0) + 1;

    final id = await db.insert("invoices", {
      "id": invoice.id,
      "display_id": invoice.displayId ?? nextDisplayId,
      "invoice_no": invoice.invoiceNo,
      "customer_id": invoice.customerId,
      "customer_name": customerName, // <-- provide the name here
      "total": invoice.total,
      "discount": invoice.discount,
      "paid": invoice.paid,
      "pending": invoice.pending,
      "status": invoice.status, // 👈 Persist status field
      "date": invoice.date,
      "created_at": invoice.createdAt,
      "updated_at": invoice.updatedAt,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    await AuditLogger.log(
      'CREATE',
      'invoices',
      recordId: invoice.id,
      userId: AuthService.instance.currentUser?.id ?? 'system',
      newData: invoice.toMap(),
      txn: db,
    );

    return id;
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
    // Fetch old data
    final oldData = await getById(invoice.id);

    // 🔒 Financial Immutability: Lock financial fields for posted invoices
    final map = invoice.toMap();
    if (oldData?.status == 'posted') {
      map.remove('total');
      map.remove('discount');
      map.remove('paid');
      map.remove('tax');
      map.remove('status'); // Prevent status change
    }

    final count = await db.update(
      'invoices',
      map,
      where: 'id = ?',
      whereArgs: [invoice.id],
    );

    await AuditLogger.log(
      'UPDATE',
      'invoices',
      recordId: invoice.id,
      userId: AuthService.instance.currentUser?.id ?? 'system',
      oldData: oldData?.toMap(),
      newData: invoice.toMap(),
      txn: db,
    );

    return count;
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
  // UPDATE PENDING AMOUNT (SAFE TRANSACTION)
  // =========================
  Future<void> updatePendingAmount(String id, double delta) async {
    final result = await db.query(
      'invoices',
      columns: ['pending', 'paid'],
      where: 'id = ?',
      whereArgs: [id],
    );

    if (result.isNotEmpty) {
      final currentPending = (result.first['pending'] as num).toDouble();
      final currentPaid = (result.first['paid'] as num).toDouble();

      final newPending = currentPending + delta;
      final newPaid = currentPaid - delta;

      await db.update(
        'invoices',
        {
          'pending': newPending,
          'paid': newPaid,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  // =========================
  // DELETE
  // =========================
  Future<int> delete(String id) async {
    // Fetch old data
    final oldData = await getById(id);

    final count = await db.delete('invoices', where: 'id = ?', whereArgs: [id]);

    if (oldData != null) {
      await AuditLogger.log(
        'DELETE',
        'invoices',
        recordId: id,
        userId: AuthService.instance.currentUser?.id ?? 'system',
        oldData: oldData.toMap(),
        txn: db,
      );
    }

    return count;
  }
}
