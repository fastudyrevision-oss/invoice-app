import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:invoice_app/dao/product_dao.dart';
import 'package:invoice_app/models/product.dart';

void main() {
  sqfliteFfiInit();
  late ProductDao dao;
  late Database db;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute('''CREATE TABLE products (
      id TEXT PRIMARY KEY,
      name TEXT,
      description TEXT,
      sku TEXT,
      default_unit TEXT,
      cost_price REAL,
      sell_price REAL,
      quantity INTEGER,
      min_stock INTEGER,
      track_expiry INTEGER,
      supplier_id TEXT,
      created_at TEXT,
      updated_at TEXT,
      is_deleted INTEGER
    )''');
    dao = ProductDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  final product = Product(
    id: 'p1',
    name: 'Test Product',
    description: 'A product',
    sku: 'SKU1',
    defaultUnit: 'pcs',
    costPrice: 10.0,
    sellPrice: 15.0,
    quantity: 100,
    minStock: 10,
    trackExpiry: false,
    supplierId: null,
    createdAt: '2025-09-28T12:00:00Z',
    updatedAt: '2025-09-28T12:00:00Z',
    isDeleted: false,
  );

  test('insert and getAll', () async {
    await dao.insert(product);
    final products = await dao.getAll();
    expect(products.any((p) => p.id == 'p1'), true);
  });

  test('getById returns correct product', () async {
    await dao.insert(product);
    final p = await dao.getById('p1');
    expect(p?.name, 'Test Product');
  });

  test('update product', () async {
    await dao.insert(product);
    final updated = product.copyWith(name: 'Updated Product', quantity: 50);
    await dao.update(updated);
    final p = await dao.getById('p1');
    expect(p?.name, 'Updated Product');
    expect(p?.quantity, 50);
  });

  test('delete product', () async {
    await dao.insert(product);
    await dao.delete('p1');
    final p = await dao.getById('p1');
    expect(p, isNull);
  });
}
