import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:invoice_app/repositories/purchase_repo.dart';
import 'package:invoice_app/repositories/supplier_payment_repo.dart';
import 'package:invoice_app/dao/supplier_payment_dao.dart';
import 'package:invoice_app/dao/supplier_dao.dart';
import 'package:invoice_app/models/purchase.dart';
import 'package:invoice_app/models/purchase_item.dart';
import 'package:invoice_app/models/product_batch.dart';
import 'package:invoice_app/models/supplier.dart';
import 'package:invoice_app/models/product.dart';
import 'package:uuid/uuid.dart';

/// Unit tests for Purchase calculation logic
/// Tests the fix for double-counting bug where upfront payments were added twice
void main() {
  late Database db;
  late PurchaseRepository purchaseRepo;
  late SupplierPaymentRepository paymentRepo;

  setUpAll(() {
    // Initialize FFI for testing
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    // Create in-memory database for each test
    db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (db, version) async {
        // Create minimal schema for testing
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

        // Insert default category
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

  group('Purchase Calculation Tests', () {
    test('Purchase with upfront payment should not double-count', () async {
      // Arrange: Create a supplier
      final supplierId = const Uuid().v4();
      final supplier = Supplier(
        id: supplierId,
        name: 'Test Supplier',
        pendingAmount: 0.0,
        creditLimit: 10000.0,
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      );
      await db.insert('suppliers', supplier.toMap());

      // Create a product
      final productId = const Uuid().v4();
      final product = Product(
        id: productId,
        name: 'Test Product',
        description: 'Test product for unit testing',
        sku: 'TEST-001',
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

      // Act: Simulate the fixed purchase flow
      final purchaseId = const Uuid().v4();
      final total = 7000.0;
      final paidAmount = 6000.0;

      // Step 1: Create purchase with paid=0, pending=total (THE FIX)
      final purchase = Purchase(
        id: purchaseId,
        supplierId: supplierId,
        invoiceNo: purchaseId,
        total: total,
        paid: 0.0, // ✅ Fixed: Start at 0
        pending: total, // ✅ Fixed: Full amount pending
        date: DateTime.now().toIso8601String(),
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      );

      final item = PurchaseItem(
        id: const Uuid().v4(),
        purchaseId: purchaseId,
        productId: productId,
        qty: 10,
        purchasePrice: 700.0,
        sellPrice: 1000.0,
        batchNo: 'BATCH-001',
      );

      final batch = ProductBatch(
        id: const Uuid().v4(),
        productId: productId,
        batchNo: 'BATCH-001',
        supplierId: supplierId,
        qty: 10,
        purchasePrice: 700.0,
        sellPrice: 1000.0,
        purchaseId: purchaseId,
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      );

      await purchaseRepo.insertPurchaseWithItems(
        purchase: purchase,
        items: [item],
        batches: [batch],
      );

      // Step 2: Add upfront payment (this will update purchase.paid and purchase.pending)
      await paymentRepo.addPayment(
        supplierId,
        paidAmount,
        purchaseId: purchaseId,
        method: 'cash',
        note: 'Upfront payment',
      );

      // Assert: Verify purchase record
      final savedPurchase = await purchaseRepo.getPurchaseById(purchaseId);
      expect(savedPurchase, isNotNull);
      expect(savedPurchase!.total, equals(total));
      expect(
        savedPurchase.paid,
        equals(paidAmount),
      ); // Should be 6000, not 12000
      expect(
        savedPurchase.pending,
        equals(total - paidAmount),
      ); // Should be 1000

      // Assert: Verify supplier balance
      final updatedSupplier = await purchaseRepo.getSupplierById(supplierId);
      expect(updatedSupplier, isNotNull);
      expect(
        updatedSupplier!.pendingAmount,
        equals(total - paidAmount),
      ); // Should be 1000

      // Assert: Verify payment record exists
      final payments = await paymentRepo.getPayments(supplierId);
      expect(payments.length, equals(1));
      expect(payments.first.amount, equals(paidAmount));
      expect(payments.first.purchaseId, equals(purchaseId));
    });

    test(
      'Purchase with zero payment should only update supplier debt',
      () async {
        // Arrange
        final supplierId = const Uuid().v4();
        final supplier = Supplier(
          id: supplierId,
          name: 'Test Supplier 2',
          pendingAmount: 0.0,
          creditLimit: 10000.0,
          createdAt: DateTime.now().toIso8601String(),
          updatedAt: DateTime.now().toIso8601String(),
        );
        await db.insert('suppliers', supplier.toMap());

        final productId = const Uuid().v4();
        final product = Product(
          id: productId,
          name: 'Test Product 2',
          description: 'Test product 2 for unit testing',
          sku: 'TEST-002',
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
        final total = 5000.0;

        final purchase = Purchase(
          id: purchaseId,
          supplierId: supplierId,
          invoiceNo: purchaseId,
          total: total,
          paid: 0.0,
          pending: total,
          date: DateTime.now().toIso8601String(),
          createdAt: DateTime.now().toIso8601String(),
          updatedAt: DateTime.now().toIso8601String(),
        );

        final item = PurchaseItem(
          id: const Uuid().v4(),
          purchaseId: purchaseId,
          productId: productId,
          qty: 5,
          purchasePrice: 1000.0,
          sellPrice: 1500.0,
          batchNo: 'BATCH-002',
        );

        final batch = ProductBatch(
          id: const Uuid().v4(),
          productId: productId,
          batchNo: 'BATCH-002',
          supplierId: supplierId,
          qty: 5,
          purchasePrice: 1000.0,
          sellPrice: 1500.0,
          purchaseId: purchaseId,
          createdAt: DateTime.now().toIso8601String(),
          updatedAt: DateTime.now().toIso8601String(),
        );

        await purchaseRepo.insertPurchaseWithItems(
          purchase: purchase,
          items: [item],
          batches: [batch],
        );

        // Manually update supplier balance (simulating the else branch in _save)
        final updatedSupplier = supplier.copyWith(
          pendingAmount: supplier.pendingAmount + total,
        );
        await purchaseRepo.updateSupplier(updatedSupplier);

        // Assert
        final savedPurchase = await purchaseRepo.getPurchaseById(purchaseId);
        expect(savedPurchase!.total, equals(total));
        expect(savedPurchase.paid, equals(0.0));
        expect(savedPurchase.pending, equals(total));

        final finalSupplier = await purchaseRepo.getSupplierById(supplierId);
        expect(finalSupplier!.pendingAmount, equals(total));

        // No payment records should exist
        final payments = await paymentRepo.getPayments(supplierId);
        expect(payments.length, equals(0));
      },
    );

    test(
      'Purchase with overpayment should handle negative pending correctly',
      () async {
        // Arrange
        final supplierId = const Uuid().v4();
        final supplier = Supplier(
          id: supplierId,
          name: 'Test Supplier 3',
          pendingAmount: 0.0,
          creditLimit: 10000.0,
          createdAt: DateTime.now().toIso8601String(),
          updatedAt: DateTime.now().toIso8601String(),
        );
        await db.insert('suppliers', supplier.toMap());

        final productId = const Uuid().v4();
        final product = Product(
          id: productId,
          name: 'Test Product 3',
          description: 'Test product 3 for unit testing',
          sku: 'TEST-003',
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
        final total = 2000.0;
        final paidAmount = 3000.0; // Overpayment

        final purchase = Purchase(
          id: purchaseId,
          supplierId: supplierId,
          invoiceNo: purchaseId,
          total: total,
          paid: 0.0,
          pending: total,
          date: DateTime.now().toIso8601String(),
          createdAt: DateTime.now().toIso8601String(),
          updatedAt: DateTime.now().toIso8601String(),
        );

        final item = PurchaseItem(
          id: const Uuid().v4(),
          purchaseId: purchaseId,
          productId: productId,
          qty: 2,
          purchasePrice: 1000.0,
          sellPrice: 1500.0,
          batchNo: 'BATCH-003',
        );

        final batch = ProductBatch(
          id: const Uuid().v4(),
          productId: productId,
          batchNo: 'BATCH-003',
          supplierId: supplierId,
          qty: 2,
          purchasePrice: 1000.0,
          sellPrice: 1500.0,
          purchaseId: purchaseId,
          createdAt: DateTime.now().toIso8601String(),
          updatedAt: DateTime.now().toIso8601String(),
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
          note: 'Overpayment test',
        );

        // Assert
        final savedPurchase = await purchaseRepo.getPurchaseById(purchaseId);
        expect(savedPurchase!.total, equals(total));
        expect(savedPurchase.paid, equals(paidAmount));
        expect(savedPurchase.pending, equals(total - paidAmount)); // -1000

        final updatedSupplier = await purchaseRepo.getSupplierById(supplierId);
        // Supplier balance should reflect the overpayment (negative = credit)
        expect(updatedSupplier!.pendingAmount, equals(total - paidAmount));
      },
    );

    test(
      'Multiple payments on same purchase should accumulate correctly',
      () async {
        // Arrange
        final supplierId = const Uuid().v4();
        final supplier = Supplier(
          id: supplierId,
          name: 'Test Supplier 4',
          pendingAmount: 0.0,
          creditLimit: 10000.0,
          createdAt: DateTime.now().toIso8601String(),
          updatedAt: DateTime.now().toIso8601String(),
        );
        await db.insert('suppliers', supplier.toMap());

        final productId = const Uuid().v4();
        final product = Product(
          id: productId,
          name: 'Test Product 4',
          description: 'Test product 4 for unit testing',
          sku: 'TEST-004',
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
        final total = 10000.0;

        final purchase = Purchase(
          id: purchaseId,
          supplierId: supplierId,
          invoiceNo: purchaseId,
          total: total,
          paid: 0.0,
          pending: total,
          date: DateTime.now().toIso8601String(),
          createdAt: DateTime.now().toIso8601String(),
          updatedAt: DateTime.now().toIso8601String(),
        );

        final item = PurchaseItem(
          id: const Uuid().v4(),
          purchaseId: purchaseId,
          productId: productId,
          qty: 10,
          purchasePrice: 1000.0,
          sellPrice: 1500.0,
          batchNo: 'BATCH-004',
        );

        final batch = ProductBatch(
          id: const Uuid().v4(),
          productId: productId,
          batchNo: 'BATCH-004',
          supplierId: supplierId,
          qty: 10,
          purchasePrice: 1000.0,
          sellPrice: 1500.0,
          purchaseId: purchaseId,
          createdAt: DateTime.now().toIso8601String(),
          updatedAt: DateTime.now().toIso8601String(),
        );

        await purchaseRepo.insertPurchaseWithItems(
          purchase: purchase,
          items: [item],
          batches: [batch],
        );

        // Make multiple payments
        await paymentRepo.addPayment(
          supplierId,
          3000.0,
          purchaseId: purchaseId,
          method: 'cash',
          note: 'First payment',
        );

        await paymentRepo.addPayment(
          supplierId,
          4000.0,
          purchaseId: purchaseId,
          method: 'bank',
          note: 'Second payment',
        );

        await paymentRepo.addPayment(
          supplierId,
          2000.0,
          purchaseId: purchaseId,
          method: 'card',
          note: 'Third payment',
        );

        // Assert
        final savedPurchase = await purchaseRepo.getPurchaseById(purchaseId);
        expect(savedPurchase!.total, equals(total));
        expect(savedPurchase.paid, equals(9000.0)); // 3000 + 4000 + 2000
        expect(savedPurchase.pending, equals(1000.0)); // 10000 - 9000

        final updatedSupplier = await purchaseRepo.getSupplierById(supplierId);
        expect(updatedSupplier!.pendingAmount, equals(1000.0));

        final payments = await paymentRepo.getPayments(supplierId);
        expect(payments.length, equals(3));
        expect(
          payments.map((p) => p.amount).reduce((a, b) => a + b),
          equals(9000.0),
        );
      },
    );
  });
}
