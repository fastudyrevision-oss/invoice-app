import 'package:flutter/material.dart';
import '../models/expense.dart';
import '../repositories/expense_repository.dart';

enum ExpenseSortMode { date, amount }

class ExpenseFrame extends StatefulWidget {
  const ExpenseFrame({super.key});

  @override
  _ExpenseFrameState createState() => _ExpenseFrameState();
}

class _ExpenseFrameState extends State<ExpenseFrame> {
  final ExpenseRepository _repo = ExpenseRepository();
  List<Expense> _expenses = [];
  List<Expense> _filteredExpenses = [];
  bool _isLoading = true;
  String _searchQuery = '';
  bool _sortAscending = true;
  ExpenseSortMode _sortMode = ExpenseSortMode.date;

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    final data = await _repo.getAllExpenses();
    setState(() {
      _expenses = data;
      _applyFilterAndSort();
      _isLoading = false;
    });
  }

  void _applyFilterAndSort() {
    _filteredExpenses = _expenses.where((e) {
      final query = _searchQuery.toLowerCase();
      return e.description.toLowerCase().contains(query) ||
          e.category.toLowerCase().contains(query) ||
          e.date.contains(query);
    }).toList();

    if (_sortMode == ExpenseSortMode.date) {
      _filteredExpenses.sort((a, b) => _sortAscending
          ? a.date.compareTo(b.date)
          : b.date.compareTo(a.date));
    } else if (_sortMode == ExpenseSortMode.amount) {
      _filteredExpenses.sort((a, b) => _sortAscending
          ? a.amount.compareTo(b.amount)
          : b.amount.compareTo(a.amount));
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _applyFilterAndSort();
    });
  }

  void _toggleSort() {
    setState(() {
      _sortAscending = !_sortAscending;
      _applyFilterAndSort();
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
          : Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  _searchQuery = '';
                                  _applyFilterAndSort();
                                });
                              },
                            )
                          : null,
                      hintText: "Search by description, category, date...",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: _onSearchChanged,
                  ),
                ),

                // Sort options
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const Text("Sort by: "),
                          ChoiceChip(
                            label: const Text("Date"),
                            selected: _sortMode == ExpenseSortMode.date,
                            onSelected: (selected) {
                              setState(() {
                                _sortMode = ExpenseSortMode.date;
                                _applyFilterAndSort();
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text("Amount"),
                            selected: _sortMode == ExpenseSortMode.amount,
                            onSelected: (selected) {
                              setState(() {
                                _sortMode = ExpenseSortMode.amount;
                                _applyFilterAndSort();
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(_sortAscending ? Icons.arrow_downward : Icons.arrow_upward),
                            onPressed: _toggleSort,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Expense list
                Expanded(
                  child: ListView.builder(
                    itemCount: _filteredExpenses.length,
                    itemBuilder: (context, index) {
                      final expense = _filteredExpenses[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(expense.description, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    const SizedBox(height: 4),
                                    Text("${expense.category} • ${expense.date}", style: const TextStyle(fontSize: 14)),
                                  ],
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text("\$${expense.amount.toStringAsFixed(2)}",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: expense.amount > 0 ? Colors.red.shade700 : Colors.green.shade700)),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit),
                                        tooltip: "Edit",
                                        onPressed: () => _showAddEditExpenseDialog(expense),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete),
                                        tooltip: "Delete",
                                        onPressed: () async {
                                          await _repo.deleteExpense(expense.id);
                                          _loadExpenses();
                                        },
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  )
                                ],
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
