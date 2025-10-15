import 'package:flutter/material.dart';
import '../models/expense.dart';
import '../repositories/expense_repository.dart';

class ExpenseFrame extends StatefulWidget {
  const ExpenseFrame({super.key});

  @override
  _ExpenseFrameState createState() => _ExpenseFrameState();
}

class _ExpenseFrameState extends State<ExpenseFrame> {
  final ExpenseRepository _repo = ExpenseRepository();
  List<Expense> _expenses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    final data = await _repo.getAllExpenses();
    setState(() {
      _expenses = data;
      _isLoading = false;
    });
  }

  void _showAddEditExpenseDialog([Expense? expense]) {
    final descController = TextEditingController(text: expense?.description ?? "");
    final amountController = TextEditingController(text: expense?.amount.toString() ?? "");
    final dateController = TextEditingController(text: expense?.date ?? "");
    final categoryController = TextEditingController(text: expense?.category ?? "General");

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(expense == null ? "Add Expense" : "Edit Expense"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: descController, decoration: const InputDecoration(labelText: "Description")),
            TextField(controller: amountController, decoration: const InputDecoration(labelText: "Amount"), keyboardType: TextInputType.number),
            TextField(controller: dateController, decoration: const InputDecoration(labelText: "Date (YYYY-MM-DD)")),
            TextField(controller: categoryController, decoration: const InputDecoration(labelText: "Category")),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              final newExpense = Expense(
                id: expense?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                description: descController.text,
                amount: double.tryParse(amountController.text) ?? 0.0,
                date: dateController.text,
                category: categoryController.text,
              );

              if (expense == null) {
                await _repo.addExpense(newExpense);
              } else {
                await _repo.updateExpense(newExpense);
              }

              Navigator.pop(context);
              _loadExpenses();
            },
            child: Text(expense == null ? "Add" : "Update"),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Expenses"),
        actions: [
          IconButton(onPressed: () => _showAddEditExpenseDialog(), icon: const Icon(Icons.add)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text("Description")),
                  DataColumn(label: Text("Amount")),
                  DataColumn(label: Text("Date")),
                  DataColumn(label: Text("Category")),
                  DataColumn(label: Text("Actions")),
                ],
                rows: _expenses
                    .map(
                      (e) => DataRow(cells: [
                        DataCell(Text(e.description)),
                        DataCell(Text("\$${e.amount.toStringAsFixed(2)}")),
                        DataCell(Text(e.date)),
                        DataCell(Text(e.category)),
                        DataCell(Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              tooltip: "Edit",
                              onPressed: () => _showAddEditExpenseDialog(e),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              tooltip: "Delete",
                              onPressed: () async {
                                await _repo.deleteExpense(e.id);
                                _loadExpenses();
                              },
                            ),
                          ],
                        )),
                      ]),
                    )
                    .toList(),
              ),
            ),
    );
  }
}
