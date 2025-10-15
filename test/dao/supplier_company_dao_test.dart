import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_app/dao/supplier_company_dao.dart';
import 'package:invoice_app/models/supplier_company.dart';
import 'package:invoice_app/db/database_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final dao = SupplierCompanyDao();

  setUp(() async {
    await DatabaseHelper().init();
  });

  final company = SupplierCompany(
    id: 'sc1',
    name: 'Acme Corp',
    address: '123 Main St',
    phone: '1234567890',
    notes: 'Preferred',
    createdAt: '2025-09-28T12:00:00Z',
    updatedAt: '2025-09-28T12:00:00Z',
    isSynced: true,
    deleted: 0,
  );

  test('insert and getAllCompanies', () async {
    await dao.insertCompany(company);
    final companies = await dao.getAllCompanies();
    expect(companies.any((c) => c.id == 'sc1'), true);
  });

  test('getCompanyById returns correct company', () async {
    await dao.insertCompany(company);
    final c = await dao.getCompanyById('sc1');
    expect(c?.name, 'Acme Corp');
  });

  test('updateCompany updates company', () async {
    await dao.insertCompany(company);
    final updated = company.copyWith(name: 'Beta Corp');
    await dao.updateCompany(updated);
    final c = await dao.getCompanyById('sc1');
    expect(c?.name, 'Beta Corp');
  });

  test('deleteCompany soft deletes company', () async {
    await dao.insertCompany(company);
    await dao.deleteCompany('sc1');
    final c = await dao.getCompanyById('sc1');
    expect(c, isNull);
  });
}
