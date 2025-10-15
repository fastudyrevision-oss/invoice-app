import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_app/dao/customer_dao.dart';
import 'package:invoice_app/models/customer.dart';
import 'package:invoice_app/db/database_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final dao = CustomerDao();

  setUp(() async {
    await DatabaseHelper().init();
  });

  final customer = Customer(
    id: 'c1',
    name: 'John Doe',
    phone: '1234567890',
    email: 'john@example.com',
    address: '123 Main St',
    pendingAmount: 0.0,
    createdAt: '2025-09-28T12:00:00Z',
    updatedAt: '2025-09-28T12:00:00Z',
    isSynced: true,
  );

  test('insert and getAllCustomers', () async {
    await dao.insertCustomer(customer);
    final customers = await dao.getAllCustomers();
    expect(customers.any((c) => c.id == 'c1'), true);
  });

  test('getCustomerById returns correct customer', () async {
    await dao.insertCustomer(customer);
    final c = await dao.getCustomerById('c1');
    expect(c?.name, 'John Doe');
  });

  test('updateCustomer updates customer', () async {
    await dao.insertCustomer(customer);
    final updated = Customer(
      id: 'c1',
      name: 'Jane Doe',
      phone: '1234567890',
      email: 'jane@example.com',
      address: '456 Main St',
      pendingAmount: 10.0,
      createdAt: '2025-09-28T12:00:00Z',
      updatedAt: '2025-09-28T13:00:00Z',
      isSynced: false,
    );
    await dao.updateCustomer(updated);
    final c = await dao.getCustomerById('c1');
    expect(c?.name, 'Jane Doe');
    expect(c?.pendingAmount, 10.0);
  });

  test('deleteCustomer removes customer', () async {
    await dao.insertCustomer(customer);
    await dao.deleteCustomer('c1');
    final c = await dao.getCustomerById('c1');
    expect(c, isNull);
  });
}
