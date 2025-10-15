import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_app/dao/stock_alert_dao.dart';
import 'package:invoice_app/models/stock_alert.dart';
import 'package:invoice_app/db/database_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final dao = StockAlertDao();

  setUp(() async {
    await DatabaseHelper().init();
  });

  test('getLowStockAlerts returns list', () async {
    final alerts = await dao.getLowStockAlerts();
    expect(alerts, isA<List<StockAlert>>());
  });

  test('getExpiredProducts returns list', () async {
    final expired = await dao.getExpiredProducts();
    expect(expired, isA<List<StockAlert>>());
  });
}
