import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:invoice_app/db/database_helper.dart';
import 'package:invoice_app/dao/stock_report_dao.dart';

void main() {
  late DatabaseHelper dbHelper;
  late StockDao dao;
  late Database db;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    dbHelper = DatabaseHelper.testInstance();
    db = await dbHelper.openInMemoryDb();

    // Create tables
    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        name TEXT,
        is_deleted INTEGER DEFAULT 0,
        min_stock INTEGER DEFAULT 0,
        category_id TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE product_batches (
        id TEXT PRIMARY KEY,
        product_id TEXT,
        qty INTEGER,
        purchase_price REAL,
        sell_price REAL,
        batch_no TEXT,
        created_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE categories (id TEXT PRIMARY KEY, name TEXT)
    ''');
    await db.execute('''
      CREATE TABLE suppliers (id TEXT PRIMARY KEY, name TEXT, company_id TEXT)
    ''');
    await db.execute('''
      CREATE TABLE supplier_companies (id TEXT PRIMARY KEY, name TEXT)
    ''');

    dao = StockDao();
  });

  tearDown(() async {
    await db.execute("DELETE FROM product_batches");
    await db.execute("DELETE FROM products");
  });

  group('StockDao ABC Analysis Logic', () {
    test(
      'abcStatistics includes all active products even with 0 stock',
      () async {
        // Arrange: 5 products. 2 with stock, 3 without.
        await db.insert('products', {
          'id': 'p1',
          'name': 'Prod 1',
          'is_deleted': 0,
        });
        await db.insert('products', {
          'id': 'p2',
          'name': 'Prod 2',
          'is_deleted': 0,
        });
        await db.insert('products', {
          'id': 'p3',
          'name': 'Prod 3',
          'is_deleted': 0,
        });
        await db.insert('products', {
          'id': 'p4',
          'name': 'Prod 4',
          'is_deleted': 0,
        });
        await db.insert('products', {
          'id': 'p5',
          'name': 'Prod 5',
          'is_deleted': 0,
        });

        // P1 has high value: 8000 (Category A since prev_total = 0)
        await db.insert('product_batches', {
          'id': 'b1',
          'product_id': 'p1',
          'qty': 80,
          'purchase_price': 100,
          'batch_no': 'B1',
        });
        // P2 has value: 1000. Total = 9000.
        // P2 prev_total = 8000.
        // 70% of 9000 = 6300. 8000 > 6300 (not A).
        // 90% of 9000 = 8100. 8000 <= 8100 (Category B).
        await db.insert('product_batches', {
          'id': 'b2',
          'product_id': 'p2',
          'qty': 10,
          'purchase_price': 100,
          'batch_no': 'B2',
        });
        // P3, P4, P5 have 0 stock (Category C)

        // Act
        final stats = await dao.getABCStatistics();

        // Assert
        final totalItems =
            stats['A']!['count'] + stats['B']!['count'] + stats['C']!['count'];
        expect(
          totalItems,
          5,
          reason: "Total products in ABC should match total active products",
        );
        expect(stats['A']!['count'], 1);
        expect(stats['B']!['count'], 1);
        expect(stats['C']!['count'], 3);
      },
    );

    test(
      'getPagedStockReport includes products with 0 stock when ABC filter is used',
      () async {
        // Arrange
        await db.insert('products', {
          'id': 'p1',
          'name': 'Prod 1',
          'is_deleted': 0,
        });
        // Act
        final results = await dao.getPagedStockReport(
          limit: 10,
          offset: 0,
          abcFilter: 'C',
        );

        // Assert
        expect(results.any((r) => r.productId == 'p1'), true);
        expect(results.firstWhere((r) => r.productId == 'p1').remainingQty, 0);
      },
    );

    test('getStockTotalCount matches reporting count', () async {
      // Arrange
      await db.insert('products', {
        'id': 'p1',
        'name': 'Prod 1',
        'is_deleted': 0,
      });
      await db.insert('products', {
        'id': 'p2',
        'name': 'Prod 2',
        'is_deleted': 0,
      });
      // P1 has 2 batches
      await db.insert('product_batches', {
        'id': 'b1',
        'product_id': 'p1',
        'qty': 10,
        'purchase_price': 10,
      });
      await db.insert('product_batches', {
        'id': 'b2',
        'product_id': 'p1',
        'qty': 5,
        'purchase_price': 10,
      });

      // Act
      final results = await dao.getPagedStockReport(limit: 10, offset: 0);
      final count = await dao.getStockTotalCount();

      // Assert
      expect(
        count,
        results.length,
        reason:
            "Count from getStockTotalCount should match paged results length",
      );
      expect(
        count,
        3,
        reason: "Expected 3 rows (2 for p1 batches + 1 for p2 row)",
      );
      expect(results.length, 3, reason: "Paged output should have 3 items");
      // getStockTotalCount without ABC uses: SELECT COUNT(*) as count FROM product_batches pb JOIN products p ...
      // That's an INNER JOIN in the code (it doesn't have LEFT).
      // Let's re-check getStockTotalCount in the file.
    });
  });
}
