import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:invoice_app/repositories/purchase_repo.dart';
import 'package:invoice_app/repositories/supplier_payment_repo.dart';
import 'package:invoice_app/dao/supplier_payment_dao.dart';
import 'package:invoice_app/dao/supplier_dao.dart';
import 'package:invoice_app/models/supplier.dart';
import 'package:invoice_app/models/purchase.dart';
import 'package:invoice_app/models/purchase_item.dart';
import 'package:invoice_app/models/product_batch.dart';
import 'package:invoice_app/models/product.dart';
import 'package:uuid/uuid.dart';

/// Integration tests for the complete purchase flow
/// Simulates the exact flow that happens in PurchaseForm._save()
void main() {
  late Database db;
  late PurchaseRepository purchaseRepo;
  late SupplierPaymentRepository paymentRepo;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (db, version) async {
        // Create full schema
        await db.execute('''
          CREATE TABLE suppliers (
            id TEXT PRIMARY KEY,
            name TEXT,
            phone TEXT,
            contact_person TEXT,
            company_id TEXT,
            address TEXT,
            pending_amount REAL DEFAULT 0,
            credit_limit REAL DEFAULT 0,
            created_at TEXT,
            updated_at TEXT,
            deleted INTEGER DEFAULT 0,
            is_synced INTEGER DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE purchases (
            id TEXT PRIMARY KEY,
            supplier_id TEXT,
            invoice_no TEXT,
            total REAL,
            paid REAL DEFAULT 0,
            pending REAL DEFAULT 0,
            date TEXT,
            created_at TEXT,
            updated_at TEXT,
            is_synced INTEGER DEFAULT 0,
            FOREIGN KEY(supplier_id) REFERENCES suppliers(id) ON DELETE SET NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE purchase_items (
            id TEXT PRIMARY KEY,
            purchase_id TEXT,
            product_id TEXT,
            qty INTEGER NOT NULL,
            purchase_price REAL NOT NULL,
            sell_price REAL,
            batch_no TEXT,
            expiry_date TEXT,
            product_name TEXT,
            cost_price REAL DEFAULT 0,
            created_at TEXT,
            updated_at TEXT,
            is_synced INTEGER DEFAULT 0,
            FOREIGN KEY(purchase_id) REFERENCES purchases(id) ON DELETE CASCADE,
            FOREIGN KEY(product_id) REFERENCES products(id) ON DELETE SET NULL
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
            is_synced INTEGER DEFAULT 0,
            FOREIGN KEY(product_id) REFERENCES products(id) ON DELETE CASCADE,
            FOREIGN KEY(supplier_id) REFERENCES suppliers(id) ON DELETE SET NULL,
            FOREIGN KEY(purchase_id) REFERENCES purchases(id) ON DELETE SET NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE supplier_payments (
            id TEXT PRIMARY KEY,
            supplier_id TEXT NOT NULL,
            purchase_id TEXT,
            amount REAL NOT NULL,
            method TEXT DEFAULT 'cash',
            transaction_ref TEXT,
            note TEXT,
            date TEXT,
            deleted INTEGER DEFAULT 0,
            created_at TEXT,
            updated_at TEXT,
            is_synced INTEGER DEFAULT 0,
            FOREIGN KEY(supplier_id) REFERENCES suppliers(id) ON DELETE CASCADE,
            FOREIGN KEY(purchase_id) REFERENCES purchases(id) ON DELETE SET NULL
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
            is_deleted INTEGER DEFAULT 0,
            FOREIGN KEY(supplier_id) REFERENCES suppliers(id) ON DELETE SET NULL
          )
        ''');

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
            is_deleted INTEGER DEFAULT 0,
            FOREIGN KEY(parent_id) REFERENCES categories(id) ON DELETE SET NULL
          )
        ''');

        await db.insert('categories', {
          'id': 'cat-001',
          'name': 'Uncategorized',
          'slug': 'uncategorized',
          'description': 'Default category',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          'is_active': 1,
          'is_deleted': 0,
        });
      },
    );

    purchaseRepo = PurchaseRepository(db);
    paymentRepo = SupplierPaymentRepository(
      SupplierPaymentDao(db),
      SupplierDao(db),
      purchaseRepo,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('Purchase Flow Integration Tests', () {
    test(
      'Complete purchase flow: Total 7000, Paid 6000 should result in Pending 1000',
      () async {
        // This test simulates the exact bug scenario reported by the user

        // Arrange: Create supplier and product
        final supplierId = const Uuid().v4();
        final supplier = Supplier(
          id: supplierId,
          name: 'Integration Test Supplier',
          pendingAmount: 0.0,
          creditLimit: 50000.0,
          createdAt: DateTime.now().toIso8601String(),
          updatedAt: DateTime.now().toIso8601String(),
        );
        await db.insert('suppliers', supplier.toMap());

        final productId = const Uuid().v4();
        final product = Product(
          id: productId,
          name: 'Integration Test Product',
          description: "Testing product",
          sku: 'INT-001',
          defaultUnit: 'pcs',
          costPrice: 0.0,
          sellPrice: 0.0,
          quantity: 0,
          minStock: 0,
          trackExpiry: false,
          supplierId: supplierId,
          categoryId: 'cat-001',
          createdAt: DateTime.now().toIso8601String(),
          updatedAt: DateTime.now().toIso8601String(),
        );
        await db.insert('products', product.toMap());

        // Act: Simulate the FIXED purchase flow from PurchaseForm._save()
        final purchaseId = const Uuid().v4();
        final now = DateTime.now().toIso8601String();
        final total = 7000.0;
        final paidAmount = 6000.0;

        // Step 1: Create purchase with paid=0, pending=total (THE FIX)
        final purchase = Purchase(
          id: purchaseId,
          supplierId: supplierId,
          invoiceNo: purchaseId,
          total: total,
          paid: 0.0, // ✅ Fixed
          pending: total, // ✅ Fixed
          date: now,
          createdAt: now,
          updatedAt: now,
        );

        final item = PurchaseItem(
          id: const Uuid().v4(),
          purchaseId: purchaseId,
          productId: productId,
          qty: 7,
          purchasePrice: 1000.0,
          sellPrice: 1500.0,
          batchNo: 'BATCH-INT-001',
        );

        final batch = ProductBatch(
          id: const Uuid().v4(),
          productId: productId,
          batchNo: 'BATCH-INT-001',
          supplierId: supplierId,
          qty: 7,
          purchasePrice: 1000.0,
          sellPrice: 1500.0,
          purchaseId: purchaseId,
          createdAt: now,
          updatedAt: now,
        );

        // Step 2: Insert purchase with items
        await purchaseRepo.insertPurchaseWithItems(
          purchase: purchase,
          items: [item],
          batches: [batch],
        );

        // Step 3: Add upfront payment (simulating the if (paidAmount > 0) branch)
        await paymentRepo.addPayment(
          supplierId,
          paidAmount,
          purchaseId: purchaseId,
          method: 'cash',
          transactionRef: 'TEST-REF-001',
          note: 'Upfront payment for Purchase #$purchaseId',
        );

        // Assert: Verify the EXACT expected values
        final savedPurchase = await purchaseRepo.getPurchaseById(purchaseId);
        expect(savedPurchase, isNotNull, reason: 'Purchase should be saved');
        expect(
          savedPurchase!.total,
          equals(7000.0),
          reason: 'Total should be 7000',
        );
        expect(
          savedPurchase.paid,
          equals(6000.0),
          reason: 'Paid should be 6000 (NOT 12000 from double-counting)',
        );
        expect(
          savedPurchase.pending,
          equals(1000.0),
          reason: 'Pending should be 1000 (7000 - 6000)',
        );

        // Verify supplier balance
        final updatedSupplier = await purchaseRepo.getSupplierById(supplierId);
        expect(updatedSupplier, isNotNull);
        expect(
          updatedSupplier!.pendingAmount,
          equals(1000.0),
          reason: 'Supplier pending should be 1000',
        );

        // Verify payment record
        final payments = await paymentRepo.getPayments(supplierId);
        expect(
          payments.length,
          equals(1),
          reason: 'Should have exactly 1 payment',
        );
        expect(payments.first.amount, equals(6000.0));
        expect(payments.first.purchaseId, equals(purchaseId));
        expect(payments.first.method, equals('cash'));
      },
    );

    test(
      'Purchase flow with existing supplier debt should accumulate correctly',
      () async {
        // Arrange: Create supplier with existing debt represented by an actual purchase
        final supplierId = const Uuid().v4();
        final existingDebt = 5000.0;
        final supplier = Supplier(
          id: supplierId,
          name: 'Supplier With Debt',
          pendingAmount: 0.0, // Will be set by the existing purchase
          creditLimit: 50000.0,
          createdAt: DateTime.now().toIso8601String(),
          updatedAt: DateTime.now().toIso8601String(),
        );
        await db.insert('suppliers', supplier.toMap());

        final productId = const Uuid().v4();
        final product = Product(
          id: productId,
          name: 'Test Product',
          description: 'Product for debt testing',
          sku: 'TEST-DEBT-001',
          defaultUnit: 'pcs',
          costPrice: 0.0,
          sellPrice: 0.0,
          quantity: 0,
          minStock: 0,
          trackExpiry: false,
          supplierId: supplierId,
          categoryId: 'cat-001',
          createdAt: DateTime.now().toIso8601String(),
          updatedAt: DateTime.now().toIso8601String(),
        );
        await db.insert('products', product.toMap());

        // ✅ Create an existing purchase to represent the 5000 debt
        final existingPurchaseId = const Uuid().v4();
        final existingPurchase = Purchase(
          id: existingPurchaseId,
          supplierId: supplierId,
          invoiceNo: existingPurchaseId,
          total: existingDebt,
          paid: 0.0,
          pending: existingDebt, // Full debt unpaid
          date: DateTime.now().toIso8601String(),
          createdAt: DateTime.now().toIso8601String(),
          updatedAt: DateTime.now().toIso8601String(),
        );
        await db.insert('purchases', existingPurchase.toMap());

        // Recalculate supplier balance to reflect the existing purchase
        await paymentRepo.recalculateSupplierBalance(supplierId);

        // Act: Create new purchase
        final purchaseId = const Uuid().v4();
        final now = DateTime.now().toIso8601String();
        final total = 3000.0;
        final paidAmount = 1000.0;

        final purchase = Purchase(
          id: purchaseId,
          supplierId: supplierId,
          invoiceNo: purchaseId,
          total: total,
          paid: 0.0,
          pending: total,
          date: now,
          createdAt: now,
          updatedAt: now,
        );

        final item = PurchaseItem(
          id: const Uuid().v4(),
          purchaseId: purchaseId,
          productId: productId,
          qty: 3,
          purchasePrice: 1000.0,
          sellPrice: 1500.0,
          batchNo: 'BATCH-DEBT-001',
        );

        final batch = ProductBatch(
          id: const Uuid().v4(),
          productId: productId,
          batchNo: 'BATCH-DEBT-001',
          supplierId: supplierId,
          qty: 3,
          purchasePrice: 1000.0,
          sellPrice: 1500.0,
          purchaseId: purchaseId,
          createdAt: now,
          updatedAt: now,
        );

        await purchaseRepo.insertPurchaseWithItems(
          purchase: purchase,
          items: [item],
          batches: [batch],
        );

        await paymentRepo.addPayment(
          supplierId,
          paidAmount,
          purchaseId: purchaseId,
          method: 'bank',
          note: 'Partial payment',
        );

        // Assert
        final savedPurchase = await purchaseRepo.getPurchaseById(purchaseId);
        expect(savedPurchase!.paid, equals(1000.0));
        expect(savedPurchase.pending, equals(2000.0)); // 3000 - 1000

        final updatedSupplier = await purchaseRepo.getSupplierById(supplierId);
        // New debt = existing purchase pending (5000) + new purchase pending (2000) = 7000
        expect(
          updatedSupplier!.pendingAmount,
          equals(7000.0),
          reason: 'Should be existing debt + new pending',
        );
      },
    );

    test(
      'Purchase flow with full payment should result in zero pending',
      () async {
        // Arrange
        final supplierId = const Uuid().v4();
        final supplier = Supplier(
          id: supplierId,
          name: 'Full Payment Supplier',
          pendingAmount: 0.0,
          creditLimit: 50000.0,
          createdAt: DateTime.now().toIso8601String(),
          updatedAt: DateTime.now().toIso8601String(),
        );
        await db.insert('suppliers', supplier.toMap());

        final productId = const Uuid().v4();
        final product = Product(
          id: productId,
          name: 'Full Payment Product',
          description: 'Product for full payment testing',
          sku: 'FULL-001',
          defaultUnit: 'pcs',
          costPrice: 0.0,
          sellPrice: 0.0,
          quantity: 0,
          minStock: 0,
          trackExpiry: false,
          supplierId: supplierId,
          categoryId: 'cat-001',
          createdAt: DateTime.now().toIso8601String(),
          updatedAt: DateTime.now().toIso8601String(),
        );
        await db.insert('products', product.toMap());

        // Act
        final purchaseId = const Uuid().v4();
        final now = DateTime.now().toIso8601String();
        final total = 5000.0;
        final paidAmount = 5000.0; // Full payment

        final purchase = Purchase(
          id: purchaseId,
          supplierId: supplierId,
          invoiceNo: purchaseId,
          total: total,
          paid: 0.0,
          pending: total,
          date: now,
          createdAt: now,
          updatedAt: now,
        );

        final item = PurchaseItem(
          id: const Uuid().v4(),
          purchaseId: purchaseId,
          productId: productId,
          qty: 5,
          purchasePrice: 1000.0,
          sellPrice: 1500.0,
          batchNo: 'BATCH-FULL-001',
        );

        final batch = ProductBatch(
          id: const Uuid().v4(),
          productId: productId,
          batchNo: 'BATCH-FULL-001',
          supplierId: supplierId,
          qty: 5,
          purchasePrice: 1000.0,
          sellPrice: 1500.0,
          purchaseId: purchaseId,
          createdAt: now,
          updatedAt: now,
        );

        await purchaseRepo.insertPurchaseWithItems(
          purchase: purchase,
          items: [item],
          batches: [batch],
        );

        await paymentRepo.addPayment(
          supplierId,
          paidAmount,
          purchaseId: purchaseId,
          method: 'cash',
          note: 'Full payment',
        );

        // Assert
        final savedPurchase = await purchaseRepo.getPurchaseById(purchaseId);
        expect(savedPurchase!.total, equals(5000.0));
        expect(savedPurchase.paid, equals(5000.0));
        expect(
          savedPurchase.pending,
          equals(0.0),
          reason: 'Should be fully paid',
        );

        final updatedSupplier = await purchaseRepo.getSupplierById(supplierId);
        expect(
          updatedSupplier!.pendingAmount,
          equals(0.0),
          reason: 'Supplier should have no pending amount',
        );
      },
    );
  });
}
