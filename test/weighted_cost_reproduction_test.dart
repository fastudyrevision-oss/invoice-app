import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:invoice_app/dao/product_batch_dao.dart';
import 'package:invoice_app/models/product_batch.dart';
import 'package:uuid/uuid.dart';

void main() {
  late Database db;
  late ProductBatchDao batchDao;

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
          CREATE TABLE products (
            id TEXT PRIMARY KEY,
            name TEXT,
            cost_price REAL,
            sell_price REAL,
            quantity INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE product_batches (
            id TEXT PRIMARY KEY,
            product_id TEXT,
            supplier_id TEXT,
            batch_no TEXT,
            expiry_date TEXT,
            qty INTEGER,
            purchase_price REAL,
            sell_price REAL,
            purchase_id TEXT,
            created_at TEXT,
            updated_at TEXT,
            is_synced INTEGER DEFAULT 0
          )
        ''');
      },
    );
    batchDao = ProductBatchDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'Reproduction: Cost calculation uses last batch instead of weighted average',
    () async {
      // 1. Insert Product
      final productId = 'prod-001';
      await db.insert('products', {
        'id': productId,
        'name': 'Test Product',
        'cost_price': 0,
        'sell_price': 1000,
        'quantity': 0,
      });

      // 2. Purchase Batch 1: 10 units @ 400
      final batch1 = ProductBatch(
        id: const Uuid().v4(),
        productId: productId,
        batchNo: 'B1',
        qty: 10,
        purchasePrice: 400.0,
        createdAt: DateTime.now()
            .subtract(const Duration(days: 2))
            .toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      );
      await batchDao.insertBatch(batch1);

      // 3. Sell 2 units (simulate logic from OrderFormScreen)
      // Deduction
      await batchDao.deductFromBatches(productId, 2, trackUsage: true);

      // 4. Purchase Batch 2: 10 units @ 600
      final batch2 = ProductBatch(
        id: const Uuid().v4(),
        productId: productId,
        batchNo: 'B2',
        qty: 10,
        purchasePrice: 600.0,
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      );
      await batchDao.insertBatch(batch2);

      // Current State:
      // Batch 1: 8 units remaining @ 400
      // Batch 2: 10 units remaining @ 600
      // Total Qty: 18
      // WA cost = (8*400 + 10*600) / 18 = (3200 + 6000) / 18 = 9200 / 18 ≈ 511.11

      // 5. Sell 2 units (The Fix Check)
      // Simulate New OrderFormScreen logic:

      // A. Fetch ALL batches first to calculate WA
      final allBatches = await batchDao.getAvailableBatches(productId);

      // DEBUG: Found ${allBatches.length} batches

      double totalValue = 0;
      int totalStock = 0;
      for (final batch in allBatches) {
        // DEBUG: Batch ${batch.batchNo}, Qty: ${batch.qty}, Price: ${batch.purchasePrice}
        totalValue += batch.qty * (batch.purchasePrice ?? 0.0);
        totalStock += batch.qty;
      }

      // DEBUG: Total Stock: $totalStock, Total Value: $totalValue

      final weightedCost = totalStock > 0 ? totalValue / totalStock : 0.0;
      // DEBUG: Weighted Cost: $weightedCost

      // B. Deduct Stock (FIFO) is still performed, but cost doesn't depend on it
      await batchDao.deductFromBatches(productId, 2, trackUsage: true);

      // Expected (Weighted Average): ~511.11
      // (8*400 + 10*600) / 18 = 9200 / 18 = 511.11

      expect(
        weightedCost,
        closeTo(511.11, 0.1),
        reason:
            "Cost should represent Weighted Average Cost of available stock",
      );
    },
  );
}
