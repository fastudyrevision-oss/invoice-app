import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_app/dao/supplier_report_dao.dart';
import 'package:invoice_app/models/supplier_report.dart';
import 'package:invoice_app/db/database_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final dao = SupplierReportDao();

  setUp(() async {
    await DatabaseHelper().init();
  });

  test('getSupplierReports returns list', () async {
    final reports = await dao.getSupplierReports(startDate: '2025-01-01', endDate: '2025-12-31');
    expect(reports, isA<List<SupplierReport>>());
  });

  test('getCompanyReports returns list', () async {
    final reports = await dao.getCompanyReports(startDate: '2025-01-01', endDate: '2025-12-31');
    expect(reports, isA<List<SupplierReport>>());
  });
}
