import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:invoice_app/dao/product_batch_dao.dart';
import 'package:invoice_app/models/product_batch.dart';

void main() {
  sqfliteFfiInit();
  late ProductBatchDao dao;
  late Database db;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute('''CREATE TABLE product_batches (
      id TEXT PRIMARY KEY,
      product_id TEXT,
      batch_no TEXT,
      expiry_date TEXT,
      qty INTEGER,
      purchase_price REAL,
      sell_price REAL,
      purchase_id TEXT,
      created_at TEXT,
      updated_at TEXT
    )''');
    dao = ProductBatchDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  final batch = ProductBatch(
    id: 'b1',
    productId: 'p1',
    batchNo: 'BATCH1',
    expiryDate: '2025-12-31',
    qty: 10,
    purchasePrice: 5.0,
    sellPrice: 8.0,
    purchaseId: 'pu1',
    createdAt: '2025-09-28T12:00:00Z',
    updatedAt: '2025-09-28T12:00:00Z',
  );

  test('insert and getBatchesByProduct', () async {
    await dao.insertBatch(batch);
    final batches = await dao.getBatchesByProduct('p1');
    expect(batches.any((b) => b.id == 'b1'), true);
  });

  test('getBatchesByPurchaseId returns correct batch', () async {
    await dao.insertBatch(batch);
    final batches = await dao.getBatchesByPurchaseId('pu1');
    expect(batches.any((b) => b.id == 'b1'), true);
  });
}
