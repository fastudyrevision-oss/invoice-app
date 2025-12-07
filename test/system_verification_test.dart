import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:invoice_app/db/database_helper.dart';
import 'package:invoice_app/models/product.dart';
import 'package:invoice_app/dao/product_dao.dart';

void main() {
  late DatabaseHelper dbHelper;
  late ProductDao productDao;

  setUpAll(() {
    // Initialize FFI
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    dbHelper = DatabaseHelper.testInstance();
    await dbHelper.openInMemoryDb();

    final db = await dbHelper.db;
    productDao = ProductDao(db);
  });

  tearDown(() async {
    await dbHelper.close();
  });

  group('System Verification Tests', () {
    test('Product CRUD operations work correctly', () async {
      // 1. Create Product
      final p = Product(
        id: 'p1',
        name: 'Test Product',
        description: 'Test Description',
        sku: 'TP001',
        defaultUnit: 'pcs',
        costPrice: 50,
        sellPrice: 100,
        quantity: 10,
        minStock: 5,
        trackExpiry: false,
        supplierId: null,
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      );
      await productDao.insert(p);

      // 2. Read Product
      var fetchedP = await productDao.getById('p1');
      expect(fetchedP, isNotNull);
      expect(fetchedP?.name, 'Test Product');
      expect(fetchedP?.quantity, 10);

      // 3. Update Stock
      await productDao.increaseStock('p1', 5);
      fetchedP = await productDao.getById('p1');
      expect(fetchedP?.quantity, 15, reason: 'Stock should increase to 15');

      await productDao.decreaseStock('p1', 3);
      fetchedP = await productDao.getById('p1');
      expect(fetchedP?.quantity, 12, reason: 'Stock should decrease to 12');

      // 4. Update Product
      final updatedP = p.copyWith(name: 'Updated Product', sellPrice: 120);
      await productDao.update(updatedP);
      fetchedP = await productDao.getById('p1');
      expect(fetchedP?.name, 'Updated Product');
      expect(fetchedP?.sellPrice, 120);

      // 5. Soft Delete
      await productDao.delete('p1');
      fetchedP = await productDao.getById('p1', includeDeleted: false);
      expect(fetchedP, isNull, reason: 'Deleted product should not be found');

      fetchedP = await productDao.getById('p1', includeDeleted: true);
      expect(
        fetchedP,
        isNotNull,
        reason: 'Deleted product should be found with includeDeleted=true',
      );
    });

    test('Audit Log records product operations', () async {
      final db = await dbHelper.db;

      // Create a product (triggers CREATE log)
      final p = Product(
        id: 'audit_p1',
        name: 'Audit Prod',
        description: '',
        sku: 'A1',
        defaultUnit: 'pcs',
        costPrice: 0,
        sellPrice: 0,
        quantity: 0,
        minStock: 0,
        trackExpiry: false,
        supplierId: null,
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      );
      await productDao.insert(p);

      final logs = await db.query('audit_logs');
      expect(logs.isNotEmpty, true, reason: 'Audit log should record creation');
      expect(logs.first['table_name'], 'products');
      expect(logs.first['action'], 'CREATE');
      expect(logs.first['record_id'], 'audit_p1');
    });

    test('Profit margin calculation is correct', () {
      final costPrice = 50.0;
      final sellPrice = 100.0;
      final profit = sellPrice - costPrice;
      final profitPercent = (profit / costPrice) * 100;

      expect(profit, 50.0);
      expect(profitPercent, 100.0, reason: '100% profit margin');
    });

    test('Low stock detection works', () {
      final product1 = Product(
        id: 'p1',
        name: 'Low Stock Item',
        description: '',
        sku: 'LS1',
        defaultUnit: 'pcs',
        costPrice: 10,
        sellPrice: 20,
        quantity: 3,
        minStock: 5,
        trackExpiry: false,
        supplierId: null,
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      );

      final product2 = Product(
        id: 'p2',
        name: 'Normal Stock Item',
        description: '',
        sku: 'NS1',
        defaultUnit: 'pcs',
        costPrice: 10,
        sellPrice: 20,
        quantity: 10,
        minStock: 5,
        trackExpiry: false,
        supplierId: null,
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      );

      expect(
        product1.quantity <= product1.minStock,
        true,
        reason: 'Product 1 is low stock',
      );
      expect(
        product2.quantity <= product2.minStock,
        false,
        reason: 'Product 2 has normal stock',
      );
    });
  });
}
