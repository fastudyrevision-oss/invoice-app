import 'dart:math';
import 'package:uuid/uuid.dart';
import '../db/database_helper.dart';
import '../models/customer.dart';
import '../models/supplier.dart';
import '../models/supplier_company.dart';
import '../models/category.dart';
import '../models/product.dart';
import '../models/product_batch.dart';
import '../models/purchase.dart';
import '../models/purchase_item.dart';
import '../models/invoice.dart';
import '../models/invoice_item.dart';

class DatabaseSeederService {
  final _uuid = const Uuid();
  final _random = Random();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<void> seedAll({
    int customers = 200,
    int suppliers = 20,
    int products = 500,
    int purchases = 100,
    int invoices = 200,
    Function(String status)? onProgress,
  }) async {
    final db = await _dbHelper.db;

    await db.transaction((txn) async {
      // 1. Seed Categories (Fixed set + random)
      if (onProgress != null) onProgress("Seeding Categories...");
      final categoryIds = await _seedCategories(txn);

      // 2. Seed Supplier Companies & Suppliers
      if (onProgress != null) onProgress("Seeding Suppliers...");
      final supplierIds = await _seedSuppliers(txn, count: suppliers);

      // 3. Seed Customers
      if (onProgress != null) onProgress("Seeding Customers...");
      final customerIds = await _seedCustomers(txn, count: customers);

      // 4. Seed Products
      if (onProgress != null) onProgress("Seeding Products...");
      final productIds = await _seedProducts(
        txn,
        count: products,
        supplierIds: supplierIds,
        categoryIds: categoryIds,
      );

      // 5. Seed Purchases (and batches)
      if (onProgress != null) onProgress("Seeding Purchases (${purchases})...");
      await _seedPurchases(
        txn,
        count: purchases,
        supplierIds: supplierIds,
        productIds: productIds,
      );

      // 6. Seed Invoices
      if (onProgress != null) onProgress("Seeding Invoices (${invoices})...");
      await _seedInvoices(
        txn,
        count: invoices,
        customerIds: customerIds,
        productIds: productIds,
      );
    });

    if (onProgress != null) onProgress("Seeding Completed!");
  }

  Future<List<String>> _seedCategories(dynamic txn) async {
    final ids = <String>[];
    final names = [
      "Electronics",
      "Groceries",
      "Clothing",
      "Hardware",
      "Stationery",
      "Automotive",
      "Books",
      "Furniture",
      "Toys",
      "Sports",
    ];

    for (var name in names) {
      final id = _uuid.v4();
      ids.add(id);
      await txn.insert(
        'categories',
        Category(
          id: id,
          name: name,
          slug:
              "${name.toLowerCase()}-${_uuid.v4().substring(0, 4)}", // Ensure unique slug
          createdAt: DateTime.now().toIso8601String(),
          updatedAt: DateTime.now().toIso8601String(),
          isActive: true,
        ).toMap(),
      );
    }
    return ids;
  }

  Future<List<String>> _seedSuppliers(dynamic txn, {required int count}) async {
    final ids = <String>[];

    // Create one default company
    final companyId = _uuid.v4();
    await txn.insert(
      'supplier_companies',
      SupplierCompany(
        id: companyId,
        name: "Default Company ${_uuid.v4().substring(0, 4)}",
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
        deleted: 0,
      ).toMap(),
    );

    for (int i = 0; i < count; i++) {
      final id = _uuid.v4();
      ids.add(id);
      await txn.insert(
        'suppliers',
        Supplier(
          id: id,
          name: "Supplier ${i + 1}",
          phone: "555-000-${1000 + i}",
          companyId: companyId,
          address: "Address ${i + 1}",
          contactPerson: "Contact ${i + 1}",
          createdAt: DateTime.now().toIso8601String(),
          updatedAt: DateTime.now().toIso8601String(),
          isSynced: false,
        ).toMap(),
      );
    }
    return ids;
  }

  Future<List<String>> _seedCustomers(dynamic txn, {required int count}) async {
    final ids = <String>[];
    for (int i = 0; i < count; i++) {
      final id = _uuid.v4();
      ids.add(id);
      await txn.insert(
        'customers',
        Customer(
          id: id,
          name: "Customer ${i + 1}",
          phone: "555-100-${1000 + i}",
          address: "Customer Address ${i + 1}",
          pendingAmount: _random.nextDouble() * 1000,
          createdAt: DateTime.now().toIso8601String(),
          updatedAt: DateTime.now().toIso8601String(),
        ).toMap(),
      );
    }
    return ids;
  }

  Future<List<String>> _seedProducts(
    dynamic txn, {
    required int count,
    required List<String> supplierIds,
    required List<String> categoryIds,
  }) async {
    if (supplierIds.isEmpty || categoryIds.isEmpty) return [];

    final ids = <String>[];
    for (int i = 0; i < count; i++) {
      final id = _uuid.v4();
      ids.add(id);
      final cost = 10.0 + _random.nextInt(500);
      final price = cost * 1.5;

      await txn.insert(
        'products',
        Product(
          id: id,
          name: "Product ${i + 1}",
          description: "Description for product ${i + 1}",
          sku: "SKU-${10000 + i}",
          defaultUnit: "pcs",
          costPrice: cost,
          sellPrice: price,
          quantity: _random.nextInt(100),
          minStock: 10,
          trackExpiry: _random.nextBool(),
          supplierId: supplierIds[_random.nextInt(supplierIds.length)],
          categoryId: categoryIds[_random.nextInt(categoryIds.length)],
          createdAt: DateTime.now().toIso8601String(),
          updatedAt: DateTime.now().toIso8601String(),
          isDeleted: false,
        ).toMap(),
      );
    }
    return ids;
  }

  Future<void> _seedPurchases(
    dynamic txn, {
    required int count,
    required List<String> supplierIds,
    required List<String> productIds,
  }) async {
    if (supplierIds.isEmpty || productIds.isEmpty) return;

    for (int i = 0; i < count; i++) {
      final purchaseId = _uuid.v4();
      final supplierId = supplierIds[_random.nextInt(supplierIds.length)];
      final date = DateTime.now().subtract(
        Duration(days: _random.nextInt(365)),
      );

      // Items
      double total = 0;
      final itemCount = 1 + _random.nextInt(5);

      await txn.insert(
        'purchases',
        Purchase(
          id: purchaseId,
          supplierId: supplierId,
          invoiceNo: "PUR-${1000 + i}",
          total: 0, // update later
          paid: 0,
          pending: 0,
          date: date.toIso8601String(),
          createdAt: date.toIso8601String(),
          updatedAt: date.toIso8601String(),
        ).toMap(),
      );

      for (int j = 0; j < itemCount; j++) {
        final itemId = _uuid.v4();
        final productId = productIds[_random.nextInt(productIds.length)];
        final qty = 1 + _random.nextInt(20);
        final cost = 10.0 + _random.nextInt(100);
        final lineTotal = cost * qty;
        total += lineTotal;

        // Purchase Item - Manually construct map to include fields missing from model
        final itemMap = PurchaseItem(
          id: itemId,
          purchaseId: purchaseId,
          productId: productId,
          qty: qty,
          purchasePrice: cost,
          sellPrice: cost * 1.5,
          // Model doesn't support extra fields
        ).toMap();

        // Inject extra fields supported by DB schema
        itemMap['product_name'] = "Product (Seeded)";
        itemMap['cost_price'] = cost;
        itemMap['created_at'] = date.toIso8601String();
        itemMap['updated_at'] = date.toIso8601String();

        await txn.insert('purchase_items', itemMap);

        // Batch
        final batchId = _uuid.v4();
        await txn.insert(
          'product_batches',
          ProductBatch(
            id: batchId,
            productId: productId,
            supplierId: supplierId,
            batchNo: "BATCH-${_random.nextInt(9999)}",
            expiryDate: date
                .add(Duration(days: 30 + _random.nextInt(300)))
                .toIso8601String(),
            qty: qty,
            purchasePrice: cost,
            sellPrice: cost * 1.5,
            purchaseId: purchaseId,
            createdAt: date.toIso8601String(),
            updatedAt: date.toIso8601String(),
          ).toMap(),
        );

        // Update product qty
        await txn.rawUpdate(
          'UPDATE products SET quantity = quantity + ? WHERE id = ?',
          [qty, productId],
        );
      }

      // Update purchase totals
      await txn.update(
        'purchases',
        {
          'total': total,
          'paid': total, // assume fully paid
          'pending': 0,
        },
        where: 'id = ?',
        whereArgs: [purchaseId],
      );
    }
  }

  Future<void> _seedInvoices(
    dynamic txn, {
    required int count,
    required List<String> customerIds,
    required List<String> productIds,
  }) async {
    if (customerIds.isEmpty || productIds.isEmpty) return;

    for (int i = 0; i < count; i++) {
      final invoiceId = _uuid.v4();
      final customerId = customerIds[_random.nextInt(customerIds.length)];
      final date = DateTime.now().subtract(
        Duration(days: _random.nextInt(365)),
      );

      double total = 0;
      final itemCount = 1 + _random.nextInt(5);

      await txn.insert(
        'invoices',
        Invoice(
          id: invoiceId,
          customerId: customerId,
          total: 0,
          pending: 0,
          date: date.toIso8601String(),
          createdAt: date.toIso8601String(),
          updatedAt: date.toIso8601String(),
          paid: 0,
          discount: 0,
        ).toMap(),
      );

      for (int j = 0; j < itemCount; j++) {
        final itemId = _uuid.v4();
        final productId = productIds[_random.nextInt(productIds.length)];
        final qty = 1 + _random.nextInt(5);
        final price = 20.0 + _random.nextInt(200);

        total += (qty * price);

        await txn.insert(
          'invoice_items',
          InvoiceItem(
            id: itemId,
            invoiceId: invoiceId,
            productId: productId,
            qty: qty,
            price: price,
            createdAt: date.toIso8601String(),
            updatedAt: date.toIso8601String(),
          ).toMap(),
        );
      }

      await txn.update(
        'invoices',
        {
          'invoice_no': "INV-${1000 + i}",
          'total': total,
          'paid': total,
          'pending': 0,
          'status': 'paid',
        },
        where: 'id = ?',
        whereArgs: [invoiceId],
      );
    }
  }
}
