import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_app/dao/invoice_dao.dart';
import 'package:invoice_app/models/invoice.dart';
import 'package:invoice_app/db/database_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final dao = InvoiceDao();

  setUp(() async {
    await DatabaseHelper().init();
  });

  final invoice = Invoice(
    id: 'i1',
    customerId: 'c1',
    total: 200.0,
    discount: 10.0,
    paid: 100.0,
    pending: 90.0,
    date: '2025-09-28',
    createdAt: '2025-09-28T12:00:00Z',
    updatedAt: '2025-09-28T12:00:00Z',
  );

  test('insert and getAll', () async {
    await dao.insert(invoice);
    final invoices = await dao.getAll();
    expect(invoices.any((i) => i.id == 'i1'), true);
  });

  test('getById returns correct invoice', () async {
    await dao.insert(invoice);
    final i = await dao.getById('i1');
    expect(i?.customerId, 'c1');
  });

  test('update invoice', () async {
    await dao.insert(invoice);
    final updated = Invoice(
      id: 'i1',
      customerId: 'c1',
      total: 250.0,
      discount: 20.0,
      paid: 150.0,
      pending: 80.0,
      date: '2025-09-29',
      createdAt: '2025-09-28T12:00:00Z',
      updatedAt: '2025-09-29T12:00:00Z',
    );
    await dao.update(updated);
    final i = await dao.getById('i1');
    expect(i?.total, 250.0);
    expect(i?.discount, 20.0);
  });

  test('delete invoice', () async {
    await dao.insert(invoice);
    await dao.delete('i1');
    final i = await dao.getById('i1');
    expect(i, isNull);
  });
}
