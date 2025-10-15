import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_app/dao/expense_dao.dart';
import 'package:invoice_app/models/expense.dart';
import 'package:invoice_app/db/database_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final dao = ExpenseDao();

  setUp(() async {
    await DatabaseHelper().init();
  });

  final expense = Expense(
    id: 'e1',
    description: 'Lunch',
    amount: 20.0,
    date: '2025-09-28',
    category: 'Food',
  );

  test('insert and getAll', () async {
    await dao.insert(expense);
    final expenses = await dao.getAll();
    expect(expenses.any((e) => e.id == 'e1'), true);
  });

  test('update expense', () async {
    await dao.insert(expense);
    final updated = Expense(
      id: 'e1',
      description: 'Dinner',
      amount: 30.0,
      date: '2025-09-29',
      category: 'Food',
    );
    await dao.update(updated);
    final expenses = await dao.getAll();
    expect(expenses.firstWhere((e) => e.id == 'e1').description, 'Dinner');
    expect(expenses.firstWhere((e) => e.id == 'e1').amount, 30.0);
  });

  test('delete expense', () async {
    await dao.insert(expense);
    await dao.delete('e1');
    final expenses = await dao.getAll();
    expect(expenses.any((e) => e.id == 'e1'), false);
  });
}
