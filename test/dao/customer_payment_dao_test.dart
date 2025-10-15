import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_app/dao/customer_payment_dao.dart';
import 'package:invoice_app/models/customer_payment.dart';
import 'package:invoice_app/db/database_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final dao = CustomerPaymentDao();

  setUp(() async {
    await DatabaseHelper().init();
  });

  final payment = CustomerPayment(
    id: 'p1',
    customerId: 'c1',
    amount: 100.0,
    date: '2025-09-28',
    note: 'First payment',
  );

  test('insert and getByCustomerId', () async {
    await dao.insert(payment);
    final payments = await dao.getByCustomerId('c1');
    expect(payments.any((p) => p.id == 'p1'), true);
  });

  test('update payment', () async {
    await dao.insert(payment);
    final updated = CustomerPayment(
      id: 'p1',
      customerId: 'c1',
      amount: 150.0,
      date: '2025-09-29',
      note: 'Updated payment',
    );
    await dao.update(updated);
    final payments = await dao.getByCustomerId('c1');
    expect(payments.first.amount, 150.0);
  });

  test('delete payment', () async {
    await dao.insert(payment);
    await dao.delete('p1');
    final payments = await dao.getByCustomerId('c1');
    expect(payments.any((p) => p.id == 'p1'), false);
  });
}
