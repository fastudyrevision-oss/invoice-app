import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:invoice_app/dao/purchase_item_dao.dart';
import 'package:invoice_app/models/purchase_item.dart';

void main() {
  sqfliteFfiInit();
  late PurchaseItemDao dao;
  late Database db;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute('''CREATE TABLE purchase_items (
      id TEXT PRIMARY KEY,
      purchase_id TEXT,
      product_id TEXT,
      qty INTEGER,
      purchase_price REAL,
      sell_price REAL,
      batch_no TEXT,
      expiry_date TEXT
    )''');
    dao = PurchaseItemDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  final item = PurchaseItem(
    id: 'pi1',
    purchaseId: 'pu1',
    productId: 'p1',
    qty: 5,
    purchasePrice: 10.0,
    sellPrice: 15.0,
    batchNo: 'BATCH1',
    expiryDate: '2025-12-31',
  );

  test('insert and getItemsByPurchaseId', () async {
    await dao.insertPurchaseItem(item);
    final items = await dao.getItemsByPurchaseId('pu1');
    expect(items.any((i) => i.id == 'pi1'), true);
  });

  test('deleteItemsByPurchaseId removes items', () async {
    await dao.insertPurchaseItem(item);
    await dao.deleteItemsByPurchaseId('pu1');
    final items = await dao.getItemsByPurchaseId('pu1');
    expect(items.any((i) => i.id == 'pi1'), false);
  });
}
