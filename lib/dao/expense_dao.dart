import '../db/database_helper.dart';
import '../models/expense.dart';

class ExpenseDao {
  final dbHelper = DatabaseHelper();

  Future<int> insert(Expense expense) async =>
      await dbHelper.insert("expenses", expense.toMap());

  Future<List<Expense>> getAll() async {
    final data = await dbHelper.queryAll("expenses");
    return data.map((e) => Expense.fromMap(e)).toList();
  }

  Future<int> update(Expense expense) async =>
      await dbHelper.update("expenses", expense.toMap(), expense.id);

  Future<int> delete(String id) async => await dbHelper.delete("expenses", id);
}
