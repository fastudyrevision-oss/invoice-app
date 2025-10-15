import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:invoice_app/dao/purchase_dao.dart';
import 'package:invoice_app/models/purchase.dart';

void main() {
  sqfliteFfiInit();
  late PurchaseDao dao;
  late Database db;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute('''CREATE TABLE purchases (
      id TEXT PRIMARY KEY,
      supplier_id TEXT,
      invoice_no TEXT,
      total REAL,
      paid REAL,
      pending REAL,
      date TEXT,
      created_at TEXT,
      updated_at TEXT
    )''');
    dao = PurchaseDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  final purchase = Purchase(
    id: 'pu1',
    supplierId: 's1',
    invoiceNo: 'INV-001',
    total: 100.0,
    paid: 50.0,
    pending: 50.0,
    date: '2025-09-28',
    createdAt: '2025-09-28T12:00:00Z',
    updatedAt: '2025-09-28T12:00:00Z',
  );

  test('insert and getAllPurchases', () async {
    await dao.insertPurchase(purchase);
    final purchases = await dao.getAllPurchases();
    expect(purchases.any((p) => p.id == 'pu1'), true);
  });

  test('getPurchaseById returns correct purchase', () async {
    await dao.insertPurchase(purchase);
    final p = await dao.getPurchaseById('pu1');
    expect(p?.invoiceNo, 'INV-001');
  });

  test('updatePurchase updates purchase', () async {
    await dao.insertPurchase(purchase);
    final updated = purchase.copyWith(total: 120.0, paid: 60.0);
    await dao.updatePurchase(updated);
    final p = await dao.getPurchaseById('pu1');
    expect(p?.total, 120.0);
    expect(p?.paid, 60.0);
  });

  test('deletePurchase removes purchase', () async {
    await dao.insertPurchase(purchase);
    await dao.deletePurchase('pu1');
    final p = await dao.getPurchaseById('pu1');
    expect(p, isNull);
  });
}
