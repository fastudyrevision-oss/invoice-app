import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_app/dao/profit_loss_dao.dart';
import 'package:invoice_app/models/profit_loss_report.dart';
import 'package:invoice_app/db/database_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final dao = ProfitLossDao();

  setUp(() async {
    await DatabaseHelper().init();
  });

  test('generateReport returns ProfitLossReport', () async {
    final report = await dao.generateReport('2025-01-01', '2025-12-31');
    expect(report, isA<ProfitLossReport>());
  });
}
