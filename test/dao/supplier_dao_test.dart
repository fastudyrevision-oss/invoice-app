import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_app/dao/supplier_dao.dart';
import 'package:invoice_app/models/supplier.dart';
import 'package:invoice_app/db/database_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final dao = SupplierDao();

  setUp(() async {
    await DatabaseHelper().init();
  });

  final supplier = Supplier(
    id: 's1',
    name: 'Supplier 1',
    phone: '1234567890',
    address: '123 Main St',
    contactPerson: 'John',
    companyId: 'sc1',
    pendingAmount: 0.0,
    creditLimit: 1000.0,
    createdAt: '2025-09-28T12:00:00Z',
    updatedAt: '2025-09-28T12:00:00Z',
    isSynced: true,
    deleted: 0,
  );

  test('insert and getAllSuppliers', () async {
    await dao.insertSupplier(supplier);
    final suppliers = await dao.getAllSuppliers();
    expect(suppliers.any((s) => s.id == 's1'), true);
  });

  test('getSupplierById returns correct supplier', () async {
    await dao.insertSupplier(supplier);
    final s = await dao.getSupplierById('s1');
    expect(s?.name, 'Supplier 1');
  });

  test('updateSupplier updates supplier', () async {
    await dao.insertSupplier(supplier);
    final updated = supplier.copyWith(name: 'Supplier 2');
    await dao.updateSupplier(updated);
    final s = await dao.getSupplierById('s1');
    expect(s?.name, 'Supplier 2');
  });

  test('deleteSupplier soft deletes supplier', () async {
    await dao.insertSupplier(supplier);
    await dao.deleteSupplier('s1');
    final s = await dao.getSupplierById('s1');
    expect(s, isNull);
  });
}
