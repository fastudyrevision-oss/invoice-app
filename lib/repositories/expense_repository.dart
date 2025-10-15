import '../dao/expense_dao.dart';
import '../models/expense.dart';

class ExpenseRepository {
  final _dao = ExpenseDao();

  Future<int> addExpense(Expense expense) => _dao.insert(expense);

  Future<List<Expense>> getAllExpenses() => _dao.getAll();

  Future<int> updateExpense(Expense expense) => _dao.update(expense);

  Future<int> deleteExpense(String id) => _dao.delete(id);
}
