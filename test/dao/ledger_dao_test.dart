import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_app/dao/ledger_dao.dart';
import 'package:invoice_app/db/database_helper.dart';
import 'package:invoice_app/models/ledger.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final dao = LedgerDao();

  setUp(() async {
    await DatabaseHelper().init();
  });

  final entry = Ledger(
    id: 'l1',
    description: 'Opening balance',
    amount: 1000.0,
    date: '2025-09-28',
    type: 'credit',
  );

  test('insert and getAll', () async {
    await dao.insert(entry);
    final entries = await dao.getAll();
    expect(entries.any((e) => e.id == 'l1'), true);
  });

  test('update ledger entry', () async {
    await dao.insert(entry);
    final updated = Ledger(
      id: 'l1',
      description: 'Updated balance',
      amount: 1200.0,
      date: '2025-09-29',
      type: 'debit',
    );
    await dao.update(updated);
    final entries = await dao.getAll();
    expect(entries.first.description, 'Updated balance');
    expect(entries.first.amount, 1200.0);
  });

  test('delete ledger entry', () async {
    await dao.insert(entry);
    await dao.delete('l1');
    final entries = await dao.getAll();
    expect(entries.any((e) => e.id == 'l1'), false);
  });
}
