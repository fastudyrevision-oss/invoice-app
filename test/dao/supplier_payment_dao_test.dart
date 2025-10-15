import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_app/dao/supplier_payment_dao.dart';
import 'package:invoice_app/models/supplier_payment.dart';
import 'package:invoice_app/db/database_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final dao = SupplierPaymentDao();

  setUp(() async {
    await DatabaseHelper().init();
  });

  final payment = SupplierPayment(
    id: 'sp1',
    supplierId: 's1',
    purchaseId: 'pu1',
    amount: 100.0,
    method: 'cash',
    transactionRef: 'TRX1',
    note: 'First payment',
    date: '2025-09-28',
    createdAt: '2025-09-28T12:00:00Z',
    updatedAt: '2025-09-28T12:00:00Z',
    deleted: 0,
  );

  test('insert and getPayments', () async {
    await dao.insertPayment(payment);
    final payments = await dao.getPayments('s1');
    expect(payments.any((p) => p.id == 'sp1'), true);
  });

  test('getPaymentsByPurchase returns correct payment', () async {
    await dao.insertPayment(payment);
    final payments = await dao.getPaymentsByPurchase('pu1');
    expect(payments.any((p) => p.id == 'sp1'), true);
  });
}
