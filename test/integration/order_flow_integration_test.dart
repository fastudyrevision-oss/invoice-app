import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:invoice_app/dao/customer_dao.dart';
import 'package:invoice_app/dao/product_dao.dart';
import 'package:invoice_app/dao/product_batch_dao.dart';
import 'package:invoice_app/dao/invoice_dao.dart';
import 'package:invoice_app/dao/invoice_item_dao.dart';
import 'package:invoice_app/models/customer.dart';
import 'package:invoice_app/models/product.dart';
import 'package:invoice_app/models/product_batch.dart';
import 'package:invoice_app/models/invoice.dart';
import 'package:invoice_app/models/invoice_item.dart';
import 'package:uuid/uuid.dart';

void main() {
  late Database db;
  final uuid = const Uuid();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE categories (
            id TEXT PRIMARY KEY,
            name TEXT UNIQUE NOT NULL,
            slug TEXT UNIQUE,
            description TEXT,
            parent_id TEXT,
            icon TEXT,
            color TEXT,
            sort_order INTEGER DEFAULT 0,
            is_active INTEGER DEFAULT 1,
            created_at TEXT,
            updated_at TEXT,
            is_deleted INTEGER DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE customers (
            id TEXT PRIMARY KEY,
            name TEXT,
            phone TEXT,
            email TEXT,
            address TEXT,
            pending_amount REAL DEFAULT 0,
            status TEXT DEFAULT 'active',
            created_at TEXT,
            updated_at TEXT,
            is_synced INTEGER DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE products (
            id TEXT PRIMARY KEY,
            name TEXT,
            description TEXT,
            sku TEXT,
            default_unit TEXT,
            cost_price REAL,
            sell_price REAL,
            quantity INTEGER DEFAULT 0,
            min_stock INTEGER DEFAULT 0,
            track_expiry INTEGER DEFAULT 0,
            supplier_id TEXT,
            category_id TEXT DEFAULT 'cat-001',
            created_at TEXT,
            updated_at TEXT,
            is_synced INTEGER DEFAULT 0,
            is_deleted INTEGER DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE product_batches (
            id TEXT PRIMARY KEY,
            product_id TEXT NOT NULL,
            supplier_id TEXT,
            batch_no TEXT,
            expiry_date TEXT,
            qty INTEGER NOT NULL DEFAULT 0,
            purchase_price REAL,
            sell_price REAL,
            purchase_id TEXT,
            created_at TEXT,
            updated_at TEXT,
            is_synced INTEGER DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE invoices (
            id TEXT PRIMARY KEY,
            customer_id TEXT,
            customer_name TEXT,
            invoice_no TEXT,
            total REAL,
            discount REAL DEFAULT 0,
            tax REAL DEFAULT 0,
            paid REAL DEFAULT 0,
            pending REAL DEFAULT 0,
            status TEXT DEFAULT 'draft',
            date TEXT,
            created_at TEXT,
            updated_at TEXT,
            is_synced INTEGER DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE invoice_items (
            id TEXT PRIMARY KEY,
            invoice_id TEXT,
            product_id TEXT,
            qty INTEGER NOT NULL,
            price REAL NOT NULL,
            discount REAL DEFAULT 0,
            tax REAL DEFAULT 0,
            batch_no TEXT,
            reserved_batches TEXT,
            cost_price REAL NOT NULL DEFAULT 0,
            created_at TEXT,
            updated_at TEXT,
            is_synced INTEGER DEFAULT 0
          )
        ''');
      },
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('Order Creation Flow Integration Test', () async {
    final customerDao = CustomerDao(db);
    final productDao = ProductDao(db);
    final batchDao = ProductBatchDao(db);
    final invoiceDao = InvoiceDao(db);
    final itemDao = InvoiceItemDao(db);

    // 1. Setup Data
    final customer = Customer(
      id: uuid.v4(),
      name: 'Walk-in Customer',
      phone: '1234567890',
      pendingAmount: 0,
      createdAt: DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
    );
    await customerDao.insertCustomer(customer);

    final product = Product(
      id: uuid.v4(),
      name: 'Test Product',
      description: 'Test',
      sku: 'TP-001',
      defaultUnit: 'pcs',
      costPrice: 50,
      sellPrice: 100,
      quantity: 10,
      minStock: 2,
      trackExpiry: false,
      supplierId: null,
      createdAt: DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
    );
    await productDao.insert(product);

    final batch = ProductBatch(
      id: uuid.v4(),
      productId: product.id,
      qty: 10,
      purchasePrice: 50,
      sellPrice: 100,
      createdAt: DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
    );
    await batchDao.insertBatch(batch);

    // 2. Perform Order Action (Simulate _saveOrder)
    final invoiceId = uuid.v4();
    final total = 200.0; // 2 items at 100 each
    final discount = 20.0;
    final paid = 150.0;
    final realPending = total - discount - paid; // 30.0
    final invoicePending = realPending.clamp(0, double.infinity).toDouble();

    final invoice = Invoice(
      id: invoiceId,
      customerId: customer.id,
      total: total,
      discount: discount,
      paid: paid,
      pending: invoicePending,
      status: 'posted',
      date: DateTime.now().toIso8601String(),
      createdAt: DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
    );

    await invoiceDao.insert(invoice, customer.name);

    final reservedBatches = await batchDao.deductFromBatches(product.id, 2);
    final item = InvoiceItem(
      id: uuid.v4(),
      invoiceId: invoiceId,
      productId: product.id,
      qty: 2,
      price: product.sellPrice,
      costPrice: product.costPrice,
      discount: discount, // Simplified for test
      reservedBatches: reservedBatches,
      createdAt: DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
    );
    await itemDao.insert(item);
    await productDao.refreshProductQuantityFromBatches(product.id);
    await customerDao.updatePendingAmount(customer.id, realPending.toDouble());

    // 3. Verify Results
    final updatedProduct = await productDao.getById(product.id);
    expect(updatedProduct!.quantity, equals(8));

    final updatedCustomer = await customerDao.getCustomerById(customer.id);
    expect(updatedCustomer!.pendingAmount, equals(30.0));

    final savedInvoice = await invoiceDao.getById(invoiceId);
    expect(savedInvoice!.pending, equals(30.0));
  });
}
