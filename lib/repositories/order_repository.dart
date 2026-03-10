import '../dao/invoice_dao.dart';
import '../dao/invoice_item_dao.dart';
import '../dao/product_dao.dart';
import '../dao/customer_dao.dart';
import '../db/database_helper.dart';
import '../models/invoice.dart';
import '../models/invoice_item.dart';
import '../dao/product_batch_dao.dart';

class OrderRepository {
  final dbHelper = DatabaseHelper.instance;

  /// ✅ Fetch all orders (invoices)
  Future<List<Invoice>> getAllOrders() async {
    final db = await dbHelper.db;
    final invoiceDao = InvoiceDao(db);
    return await invoiceDao.getAll();
  }

  /// Save a new order (invoice + items + stock adjustments)
  Future<void> saveOrder(
    Invoice invoice,
    String customerName,
    List<InvoiceItem> items,
  ) async {
    await dbHelper.runInTransaction((txn) async {
      final invoiceDao = InvoiceDao(txn);
      final itemDao = InvoiceItemDao(txn);
      final batchDao = ProductBatchDao(txn);
      final productDao = ProductDao(txn);
      final customerDao = CustomerDao(txn);

      // --- 1. INSERT INVOICE ---
      await invoiceDao.insert(invoice, customerName);

      // --- 2. DEDUCT STOCK (FIFO) ---
      for (final item in items) {
        int remainingQty = item.qty;
        final batches = await batchDao.getAvailableBatches(
          item.productId,
          beforeDate: invoice.date,
        );

        if (batches.isEmpty) {
          throw Exception(
            'No available stock batches for product ${item.productId}',
          );
        }

        final reserved = <Map<String, dynamic>>[];
        for (final batch in batches) {
          if (remainingQty <= 0) break;

          final int deductQty = remainingQty > batch.qty
              ? batch.qty
              : remainingQty;
          final int newBatchQty = batch.qty - deductQty;

          await txn.rawUpdate(
            'UPDATE product_batches SET qty = ?, updated_at = ? WHERE id = ?',
            [newBatchQty, DateTime.now().toIso8601String(), batch.id],
          );

          reserved.add({
            "batchId": batch.id,
            "supplierId": batch.supplierId,
            "qty": deductQty,
            "purchasePrice": batch.purchasePrice,
          });

          remainingQty -= deductQty;
        }

        if (remainingQty > 0) {
          throw Exception(
            'Insufficient stock for product ${item.productId}, short by $remainingQty units',
          );
        }

        // Insert item with reserved batches
        final newItem = item.copyWith(
          invoiceId: invoice.id,
          reservedBatches: reserved,
        );
        await itemDao.insert(newItem);

        // Update total product quantity
        await productDao.decreaseStock(item.productId, item.qty);
      }

      // --- 3. UPDATE CUSTOMER BALANCE ---
      await customerDao.updatePendingAmount(
        invoice.customerId,
        invoice.pending,
      );
    });
  }

  /// Update an existing order (invoice + items + stock adjustments with reversion)
  Future<void> updateOrder(
    Invoice invoice,
    String customerName,
    List<InvoiceItem> newItems,
    List<InvoiceItem> oldItems,
  ) async {
    await dbHelper.runInTransaction((txn) async {
      final invoiceDao = InvoiceDao(txn);
      final itemDao = InvoiceItemDao(txn);
      final batchDao = ProductBatchDao(txn);
      final productDao = ProductDao(txn);
      final customerDao = CustomerDao(txn);

      // --- 1. REVERT OLD STOCK EFFECTS ---
      for (final oldItem in oldItems) {
        if (oldItem.reservedBatches != null) {
          for (final reservation in oldItem.reservedBatches!) {
            final String batchId = reservation['batchId'];
            final int reservedQty = (reservation['qty'] as num).toInt();

            // Return quantity to the specific batch
            await txn.rawUpdate(
              'UPDATE product_batches SET qty = qty + ?, updated_at = ? WHERE id = ?',
              [reservedQty, DateTime.now().toIso8601String(), batchId],
            );
          }
        }

        // Return total product quantity
        await productDao.updateQuantity(
          oldItem.productId,
          (await productDao.getById(oldItem.productId))!.quantity + oldItem.qty,
        );
      }

      // Delete old items
      await itemDao.deleteByInvoiceId(invoice.id);

      // --- 2. UPDATE INVOICE ---
      final oldInvoice = await invoiceDao.getById(invoice.id);
      await invoiceDao.update(invoice, isExplicitEdit: true);

      // --- 3. DEDUCT NEW STOCK (FIFO) ---
      for (final item in newItems) {
        int remainingQty = item.qty;
        final batches = await batchDao.getAvailableBatches(
          item.productId,
          beforeDate: invoice.date,
        );

        if (batches.isEmpty) {
          throw Exception(
            'No available stock batches for product ${item.productId}',
          );
        }

        final reserved = <Map<String, dynamic>>[];
        for (final batch in batches) {
          if (remainingQty <= 0) break;

          final int deductQty = remainingQty > batch.qty
              ? batch.qty
              : remainingQty;
          final int newBatchQty = batch.qty - deductQty;

          await txn.rawUpdate(
            'UPDATE product_batches SET qty = ?, updated_at = ? WHERE id = ?',
            [newBatchQty, DateTime.now().toIso8601String(), batch.id],
          );

          reserved.add({
            "batchId": batch.id,
            "supplierId": batch.supplierId,
            "qty": deductQty,
            "purchasePrice": batch.purchasePrice,
          });

          remainingQty -= deductQty;
        }

        if (remainingQty > 0) {
          throw Exception(
            'Insufficient stock for product ${item.productId}, short by $remainingQty units',
          );
        }

        // Insert new item with reserved batches
        final newItem = item.copyWith(
          invoiceId: invoice.id,
          reservedBatches: reserved,
        );
        await itemDao.insert(newItem);

        // Update total product quantity
        await productDao.decreaseStock(item.productId, item.qty);
      }

      // --- 4. UPDATE CUSTOMER BALANCE ---
      if (oldInvoice != null) {
        if (invoice.customerId == oldInvoice.customerId) {
          final pendingDelta = invoice.pending - oldInvoice.pending;
          await customerDao.updatePendingAmount(
            invoice.customerId,
            pendingDelta,
          );
        } else {
          // 💡 Customer changed!
          // 1. Revert full pending amount from the OLD customer
          await customerDao.updatePendingAmount(
            oldInvoice.customerId,
            -oldInvoice.pending,
          );
          // 2. Apply full pending amount to the NEW customer
          await customerDao.updatePendingAmount(
            invoice.customerId,
            invoice.pending,
          );
        }
      }
    });
  }

  /// Fetch all available batches for a product (for UI / selection)
  Future<List<Map<String, dynamic>>> getAvailableBatches(
    String productId,
  ) async {
    final db = await dbHelper.db;
    return await db.rawQuery(
      '''
      SELECT id, batch_no, qty, expiry_date, sell_price
      FROM product_batches
      WHERE product_id = ? AND qty > 0
      ORDER BY expiry_date ASC, created_at ASC
    ''',
      [productId],
    );
  }

  /// Delete an order and return stock
  Future<void> deleteOrder(Invoice invoice) async {
    await dbHelper.runInTransaction((txn) async {
      final invoiceDao = InvoiceDao(txn);
      final itemDao = InvoiceItemDao(txn);
      final batchDao = ProductBatchDao(txn);
      final customerDao = CustomerDao(txn);
      final productDao = ProductDao(txn);

      // 1. Get items to return stock
      final items = await itemDao.getByInvoiceId(invoice.id);
      for (final item in items) {
        if (item.reservedBatches != null) {
          for (final b in item.reservedBatches!) {
            await batchDao.addBackToBatch(
              (b['batchId']?.toString() ?? ""),
              (b['qty'] as num? ?? 0).toInt(),
            );
          }
        }
        await productDao.refreshProductQuantityFromBatches(item.productId);
      }

      // 2. Delete invoice and items
      await itemDao.deleteByInvoiceId(invoice.id);
      await invoiceDao.delete(invoice.id);

      // 3. Update customer balance
      final realPending = invoice.total - invoice.discount - invoice.paid;
      await customerDao.updatePendingAmount(invoice.customerId, -realPending);
    });
  }
}
