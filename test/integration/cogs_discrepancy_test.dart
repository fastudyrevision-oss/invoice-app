import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:invoice_app/dao/invoice_dao.dart';
import 'package:invoice_app/dao/invoice_item_dao.dart';
import 'package:invoice_app/dao/product_dao.dart';
import 'package:invoice_app/dao/product_batch_dao.dart';
import 'package:invoice_app/dao/customer_dao.dart';
import 'package:invoice_app/models/invoice.dart';
import 'package:invoice_app/models/invoice_item.dart';
import 'package:invoice_app/models/customer.dart';
import 'package:invoice_app/models/product.dart';
import 'package:invoice_app/models/product_batch.dart';

void main() {
  late Database db;
  late InvoiceDao invoiceDao;
  late InvoiceItemDao invoiceItemDao;
  late ProductBatchDao batchDao;
  late CustomerDao customerDao;
  late ProductDao productDao;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (db, version) async {
        // Create necessary tables
        await db.execute(
          'CREATE TABLE invoices (id TEXT PRIMARY KEY, customer_id TEXT, customer_name TEXT, total REAL, discount REAL, paid REAL, pending REAL, status TEXT, date TEXT, created_at TEXT, updated_at TEXT)',
        );
        await db.execute(
          'CREATE TABLE invoice_items (id TEXT PRIMARY KEY, invoice_id TEXT, product_id TEXT, qty INTEGER, price REAL, cost_price REAL, discount REAL, reserved_batches TEXT, created_at TEXT, updated_at TEXT)',
        );
        await db.execute(
          'CREATE TABLE products (id TEXT PRIMARY KEY, name TEXT, brand TEXT, category_id TEXT, supplier_id TEXT, barcode TEXT, description TEXT, image TEXT, cost_price REAL, sell_price REAL, quantity INTEGER, alert_quantity INTEGER, created_at TEXT, updated_at TEXT)',
        );
        await db.execute(
          'CREATE TABLE product_batches (id TEXT PRIMARY KEY, product_id TEXT, supplier_id TEXT, qty INTEGER, purchase_price REAL, sell_price REAL, mfg_date TEXT, exp_date TEXT, created_at TEXT, updated_at TEXT)',
        );
        await db.execute(
          'CREATE TABLE customers (id TEXT PRIMARY KEY, name TEXT, phone TEXT, address TEXT, pending REAL, created_at TEXT, updated_at TEXT)',
        );
        await db.execute(
          'CREATE TABLE expenses (id TEXT PRIMARY KEY, description TEXT, amount REAL, category TEXT, date TEXT, created_at TEXT, updated_at TEXT)',
        );
        await db.execute(
          'CREATE TABLE purchases (id TEXT PRIMARY KEY, supplier_id TEXT, total REAL, paid REAL, pending REAL, date TEXT, status TEXT, created_at TEXT, updated_at TEXT)',
        );
        await db.execute(
          'CREATE TABLE suppliers (id TEXT PRIMARY KEY, name TEXT, phone TEXT, company TEXT, email TEXT, address TEXT, created_at TEXT, updated_at TEXT)',
        );

        // Audit logs for AuditLogger
        await db.execute(
          'CREATE TABLE audit_logs (id TEXT PRIMARY KEY, action TEXT, table_name TEXT, record_id TEXT, user_id TEXT, old_data TEXT, new_data TEXT, timestamp TEXT)',
        );
      },
    );

    invoiceDao = InvoiceDao(db);
    invoiceItemDao = InvoiceItemDao(db);
    batchDao = ProductBatchDao(db);
    customerDao = CustomerDao(db);
    productDao = ProductDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  // Calculate weighted average cost helper
  double calculateWeightedCost(List<Map<String, dynamic>> reservedBatches) {
    double totalCost = 0;
    int totalQty = 0;
    for (final batch in reservedBatches) {
      final batchQty = (batch['qty'] as num).toInt();
      final batchCost = (batch['purchasePrice'] as num).toDouble();
      totalCost += batchQty * batchCost;
      totalQty += batchQty;
    }
    return totalQty > 0 ? totalCost / totalQty : 0.0;
  }

  test('COGS Accuracy and Immutability Test', () async {
    // 1. Setup Data
    final pId = 'p1';
    await productDao.insert(
      Product(
        id: pId,
        name: 'Prod1',
        costPrice: 0,
        sellPrice: 0,
        quantity: 0,
        minStock: 0,
        trackExpiry: true,
        description: '',
        sku: '',
        supplierId: 'hg',
        defaultUnit: 'ml',

        createdAt: '',
        updatedAt: '',
      ),
    );

    final cId = 'c1';
    await customerDao.insertCustomer(
      Customer(
        id: cId,
        name: 'Cust1',
        phone: '',
        address: '',
        pendingAmount: 0,
        createdAt: '',
        updatedAt: '',
      ),
    );

    // Batch 1: 10 units @ 500
    await batchDao.insertBatch(
      ProductBatch(
        id: 'b1',
        productId: pId,
        qty: 10,
        purchasePrice: 500,
        sellPrice: 600,
        createdAt: '',
        updatedAt: '',
      ),
    );

    // 2. First Sale: 5 units
    // Deduct batches
    final reserved1 = await batchDao.deductFromBatches(pId, 5);
    final weightedCost1 = calculateWeightedCost(reserved1);
    expect(weightedCost1, 500.0);

    final inv1Id = 'inv1';
    final now = DateTime.now().toIso8601String();

    // Create Posted Invoice
    await invoiceDao.insert(
      Invoice(
        id: inv1Id,
        customerId: cId,
        total: 3000,
        paid: 3000,
        pending: 0,
        status: 'posted',
        date: now,
        createdAt: now,
        updatedAt: now,
      ),
      'Cust1',
    );

    await invoiceItemDao.insert(
      InvoiceItem(
        id: 'ii1',
        invoiceId: inv1Id,
        productId: pId,
        qty: 5,
        price: 600,
        costPrice: weightedCost1,
        reservedBatches: reserved1,
        createdAt: now,
        updatedAt: now,
      ),
    );

    // 3. Batch 2: 15 units @ 700
    await batchDao.insertBatch(
      ProductBatch(
        id: 'b2',
        productId: pId,
        qty: 15,
        purchasePrice: 700,
        sellPrice: 817.5,
        createdAt: '',
        updatedAt: '',
      ),
    );

    // 4. Second Sale: 15 units
    // Deduct batches
    final reserved2 = await batchDao.deductFromBatches(pId, 15);
    // Should contain 5 from b1 (@500) and 10 from b2 (@700)
    // 5*500 + 10*700 = 2500 + 7000 = 9500 / 15 = 633.333...
    final weightedCost2 = calculateWeightedCost(reserved2);
    expect(weightedCost2, closeTo(633.33, 0.01));

    final inv2Id = 'inv2';
    await invoiceDao.insert(
      Invoice(
        id: inv2Id,
        customerId: cId,
        total: 12262.5,
        paid: 12262.5,
        pending: 0,
        status: 'posted',
        date: now,
        createdAt: now,
        updatedAt: now,
      ),
      'Cust1',
    );

    await invoiceItemDao.insert(
      InvoiceItem(
        id: 'ii2',
        invoiceId: inv2Id,
        productId: pId,
        qty: 15,
        price: 817.5,
        costPrice: weightedCost2,
        reservedBatches: reserved2,
        createdAt: now,
        updatedAt: now,
      ),
    );

    // 5. Verify Immutability of First Sale
    // Attempt to update cost_price of first item
    final item1 = (await invoiceItemDao.getByInvoiceId(inv1Id)).first;
    final newItem1 = InvoiceItem(
      id: item1.id,
      invoiceId: item1.invoiceId,
      productId: item1.productId,
      qty: item1.qty,
      price: item1.price,
      costPrice: 9999.0, // Malicious update
      reservedBatches: item1.reservedBatches,
      createdAt: item1.createdAt,
      updatedAt: item1.updatedAt,
    );
    await invoiceItemDao.update(newItem1);

    // Reload and check
    final reloadedItem1 = (await invoiceItemDao.getByInvoiceId(inv1Id)).first;
    expect(
      reloadedItem1.costPrice,
      500.0,
      reason: "Cost price should be immutable for posted invoice",
    );

    // 6. Verify Reporting (via raw queries to mock ProfitLossDao logic since we can't inject db easily)
    // Total COGS
    final cogs = await db.rawQuery(
      "SELECT SUM(qty * cost_price) as cogs FROM invoice_items",
    );
    final totalCogs = cogs.first['cogs'] as double;
    // Expected: (5*500) + (15*633.33) = 2500 + 9500 = 12000
    expect(totalCogs, closeTo(12000, 1.0));
  });
}
