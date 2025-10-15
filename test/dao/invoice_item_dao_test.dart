import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_app/dao/invoice_item_dao.dart';
import 'package:invoice_app/db/database_helper.dart';
import 'package:invoice_app/models/invoice_item.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final dao = InvoiceItemDao();

  setUp(() async {
    await DatabaseHelper().init();
  });

  final item = InvoiceItem(
    id: 'ii1',
    invoiceId: 'i1',
    productId: 'p1',
    qty: 2,
    price: 50.0,
  );

  test('insert and getByInvoiceId', () async {
    await dao.insert(item);
    final items = await dao.getByInvoiceId('i1');
    expect(items.any((i) => i.id == 'ii1'), true);
  });

  test('update invoice item', () async {
    await dao.insert(item);
    final updated = InvoiceItem(
      id: 'ii1',
      invoiceId: 'i1',
      productId: 'p1',
      qty: 3,
      price: 60.0,
    );
    await dao.update(updated);
    final items = await dao.getByInvoiceId('i1');
    expect(items.first.qty, 3);
    expect(items.first.price, 60.0);
  });

  test('delete invoice item', () async {
    await dao.insert(item);
    await dao.delete('ii1');
    final items = await dao.getByInvoiceId('i1');
    expect(items.any((i) => i.id == 'ii1'), false);
  });
}
