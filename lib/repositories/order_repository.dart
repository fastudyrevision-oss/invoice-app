import '../dao/invoice_dao.dart';
import '../dao/invoice_item_dao.dart';
import '../dao/product_dao.dart';
import '../dao/customer_dao.dart';
import '../db/database_helper.dart';
import '../models/invoice.dart';
import '../models/invoice_item.dart';
import '../utils/id_generator.dart'; // optional helper for UUIDs or timestamp IDs

class OrderRepository {
  final dbHelper = DatabaseHelper.instance;

  /// ✅ Fetch all orders (invoices)
  Future<List<Invoice>> getAllOrders() async {
    final db = await dbHelper.db;
    final invoiceDao = InvoiceDao(db);
    return await invoiceDao.getAll();
  }

  /// ✅ Create new order (Invoice + Items + Stock + Pending)
  Future<void> createOrder({
    required String customerId,
    required String customerName,
    required List<InvoiceItem> items,
    required double total,
    required double discount,
    required double paid,
    required double pending,
  }) async {
    final db = await dbHelper.db;
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      // 🧾 Create Invoice
      final invoice = Invoice(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        customerId: customerId,
        total: total,
        discount: discount,
        paid: paid,
        pending: pending,
        date: now,
        createdAt: now,
        updatedAt: now,
      );

      final invoiceDao = InvoiceDao(txn);
      await invoiceDao.insert(invoice, customerName); // pass customerName

      // 💰 Add items
      final itemDao = InvoiceItemDao(txn);
      final productDao = ProductDao(txn);
      for (final item in items) {
        await itemDao.insert(item);

        // 📉 Decrease stock safely
        await productDao.decreaseStock(item.productId, item.qty);
      }

      // 🧍‍♂️ Update customer's pending balance
      final customerDao = CustomerDao( txn);
      await customerDao.updatePendingAmount(customerId, pending);
    });
  }

  /// Save an order (invoice + items + stock adjustments)
  Future<void> saveOrder(Invoice invoice, String customerName, List<InvoiceItem> items) async {
    await dbHelper.runInTransaction((txn) async {
      final invoiceDao = InvoiceDao(txn);
      final itemDao = InvoiceItemDao(txn);
      final productDao = ProductDao(txn);
      final customerDao = CustomerDao( txn);

      // ------------------------------
      // 1️⃣ Insert invoice
      // ------------------------------
      await invoiceDao.insert(invoice, customerName);

      // ------------------------------
      // 2️⃣ For each item: handle batches + stock deduction
      // ------------------------------
      for (final item in items) {
        double remainingQty = item.qty.toDouble();

        // --- Fetch available batches (FIFO / earliest expiry first)
        final availableBatches = await txn.rawQuery('''
          SELECT id, qty, batch_no, expiry_date
          FROM product_batches
          WHERE product_id = ? AND qty > 0
          ORDER BY expiry_date ASC, created_at ASC
        ''', [item.productId]);

        if (availableBatches.isEmpty) {
          throw Exception('No available stock batches for product ${item.productId}');
        }

        for (final batch in availableBatches) {
          if (remainingQty <= 0) break;

          final batchQty = (batch['qty'] ?? 0) as num;
          final usedQty = batchQty >= remainingQty ? remainingQty : batchQty;

          // --- Insert invoice item (per batch)
          final batchItem = item.copyWith(
            id: generateId(),
            qty: usedQty.toInt(),
            batchNo: batch['batch_no']?.toString(),
          );

          await itemDao.insert(batchItem);

          // --- Deduct from batch stock
          await txn.rawUpdate(
            'UPDATE product_batches SET qty = qty - ? WHERE id = ?',
            [usedQty, batch['id']],
          );

          remainingQty -= usedQty;
        }

        // --- Ensure full allocation happened
        if (remainingQty > 0) {
          throw Exception(
              'Insufficient stock for product ${item.productId}, short by $remainingQty units');
        }

        // --- Update total product quantity
        await productDao.decreaseStock(item.productId, item.qty);
      }

      // ------------------------------
      // 3️⃣ Update customer pending balance
      // ------------------------------
      await customerDao.updatePendingAmount(invoice.customerId, invoice.pending);

      // ------------------------------
      // 4️⃣ Ledger & Audit logging hooks (optional)
      // ------------------------------
      // await insertLedgerEntry(invoice);
      // await insertAuditLog('CREATE_ORDER', 'invoices', invoice.id);
    });
  }

  /// Fetch all available batches for a product (for UI / selection)
  Future<List<Map<String, dynamic>>> getAvailableBatches(String productId) async {
    final db = await dbHelper.db;
    return await db.rawQuery('''
      SELECT id, batch_no, qty, expiry_date, sell_price
      FROM product_batches
      WHERE product_id = ? AND qty > 0
      ORDER BY expiry_date ASC, created_at ASC
    ''', [productId]);
  }
}
