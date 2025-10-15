import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_app/dao/audit_log_dao.dart';
import 'package:invoice_app/models/audit_log.dart';
import 'package:invoice_app/db/database_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final dao = AuditLogDao();

  setUp(() async {
    await DatabaseHelper().init();
  });

  test('insert and getAll AuditLog', () async {
    final log = AuditLog(
      id: '1',
      action: 'INSERT',
      tableName: 'products',
      recordId: '101',
      timestamp: '2025-09-28T12:00:00Z',
      userId: 'user1',
    );
    await dao.insert(log);
    final logs = await dao.getAll();
    expect(logs.any((l) => l.id == '1'), true);
  });

  test('getByTable returns correct logs', () async {
    final log = AuditLog(
      id: '2',
      action: 'UPDATE',
      tableName: 'customers',
      recordId: '201',
      timestamp: '2025-09-28T13:00:00Z',
      userId: 'user2',
    );
    await dao.insert(log);
    final logs = await dao.getByTable('customers');
    expect(logs.any((l) => l.id == '2'), true);
  });
}
