import 'package:flutter/material.dart';
import '../models/expense.dart';
import '../repositories/expense_repository.dart';
import 'expense/expense_insights_card.dart';
import 'common/unified_search_bar.dart';
import '../services/expense_export_service.dart';

enum ExpenseSortMode { date, amount }

enum ExpenseFilterType { daily, weekly, monthly, yearly, all }

class ExpenseFrame extends StatefulWidget {
  const ExpenseFrame({super.key});

  @override
  _ExpenseFrameState createState() => _ExpenseFrameState();
}

class _ExpenseFrameState extends State<ExpenseFrame> {
  final ExpenseExportService _exportService = ExpenseExportService();
  final ExpenseRepository _repo = ExpenseRepository();
  List<Expense> _expenses = [];
  List<Expense> _filteredExpenses = [];
  bool _isLoading = true;
  String _searchQuery = '';
  bool _sortAscending = true;
  ExpenseSortMode _sortMode = ExpenseSortMode.date;
  ExpenseFilterType _filterType = ExpenseFilterType.all;
  double _filteredTotal = 0.0;

  final int _pageSize = 50;
  int _currentMax = 50;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadExpenses();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      setState(() {
        if (_currentMax < _filteredExpenses.length) {
          _currentMax += _pageSize;
          if (_currentMax > _filteredExpenses.length) {
            _currentMax = _filteredExpenses.length;
          }
        }
      });
    }
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
      _filteredExpenses.sort(
        (a, b) => _sortAscending
            ? a.date.compareTo(b.date)
            : b.date.compareTo(a.date),
      );
    } else if (_sortMode == ExpenseSortMode.amount) {
      _filteredExpenses.sort(
        (a, b) => _sortAscending
            ? a.amount.compareTo(b.amount)
            : b.amount.compareTo(a.amount),
      );
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
    final descController = TextEditingController(
      text: expense?.description ?? "",
    );
    final amountController = TextEditingController(
      text: expense?.amount.toString() ?? "",
    );
    final dateController = TextEditingController(text: expense?.date ?? "");
    final categoryController = TextEditingController(
      text: expense?.category ?? "General",
    );

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(expense == null ? "Add Expense" : "Edit Expense"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: "Description"),
            ),
            TextField(
              controller: amountController,
              decoration: const InputDecoration(labelText: "Amount"),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: dateController,
              decoration: const InputDecoration(labelText: "Date (YYYY-MM-DD)"),
            ),
            TextField(
              controller: categoryController,
              decoration: const InputDecoration(labelText: "Category"),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              final newExpense = Expense(
                id:
                    expense?.id ??
                    DateTime.now().millisecondsSinceEpoch.toString(),
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

              if (context.mounted) Navigator.pop(context);
              _loadExpenses();
            },
            child: Text(expense == null ? "Add" : "Update"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Wrap(
      spacing: 8,
      children: [
        _chip("All", ExpenseFilterType.all),
        _chip("Daily", ExpenseFilterType.daily),
        _chip("Weekly", ExpenseFilterType.weekly),
        _chip("Monthly", ExpenseFilterType.monthly),
        _chip("Yearly", ExpenseFilterType.yearly),
      ],
    );
  }

  void _applyFilters() {
    DateTime now = DateTime.now();

    List<Expense> filtered = _expenses;

    switch (_filterType) {
      case ExpenseFilterType.daily:
        filtered = filtered.where((e) {
          DateTime d = DateTime.parse(e.date);
          return d.year == now.year && d.month == now.month && d.day == now.day;
        }).toList();
        break;

      case ExpenseFilterType.weekly:
        final beginningOfWeek = now.subtract(Duration(days: now.weekday - 1));
        filtered = filtered.where((e) {
          DateTime d = DateTime.parse(e.date);
          return d.isAfter(beginningOfWeek) &&
              d.isBefore(now.add(const Duration(days: 1)));
        }).toList();
        break;

      case ExpenseFilterType.monthly:
        filtered = filtered.where((e) {
          DateTime d = DateTime.parse(e.date);
          return d.year == now.year && d.month == now.month;
        }).toList();
        break;

      case ExpenseFilterType.yearly:
        filtered = filtered.where((e) {
          DateTime d = DateTime.parse(e.date);
          return d.year == now.year;
        }).toList();
        break;

      case ExpenseFilterType.all:
        // Do nothing
        break;
    }
    // 🔥 calculate total
    final total = filtered.fold<double>(0.0, (sum, item) => sum + item.amount);

    setState(() {
      _filteredExpenses = filtered;
      _filteredTotal = total;
      _currentMax = (_filteredExpenses.length < _pageSize)
          ? _filteredExpenses.length
          : _pageSize;
    });
  }

  Widget _chip(String label, ExpenseFilterType type) {
    final isSelected = _filterType == type;
    Color chipColor;
    IconData chipIcon;

    switch (type) {
      case ExpenseFilterType.daily:
        chipColor = Colors.orange;
        chipIcon = Icons.today;
        break;
      case ExpenseFilterType.weekly:
        chipColor = Colors.blue;
        chipIcon = Icons.calendar_view_week;
        break;
      case ExpenseFilterType.monthly:
        chipColor = Colors.purple;
        chipIcon = Icons.calendar_month;
        break;
      case ExpenseFilterType.yearly:
        chipColor = Colors.green;
        chipIcon = Icons.calendar_today;
        break;
      default:
        chipColor = Colors.grey;
        chipIcon = Icons.all_inclusive;
    }

    return FilterChip(
      avatar: Icon(chipIcon, size: 16),
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filterType = type;
        });
        _applyFilters();
      },
      selectedColor: chipColor.withOpacity(0.2),
      checkmarkColor: chipColor,
      backgroundColor: Colors.white,
    );
  }

  IconData _getCategoryIcon(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('food') || cat.contains('meal')) return Icons.restaurant;
    if (cat.contains('transport') || cat.contains('fuel')) {
      return Icons.directions_car;
    }
    if (cat.contains('utility') || cat.contains('bill')) {
      return Icons.receipt_long;
    }
    if (cat.contains('salary') || cat.contains('wage')) return Icons.payments;
    if (cat.contains('office') || cat.contains('supply')) {
      return Icons.business_center;
    }
    if (cat.contains('rent')) return Icons.home;
    if (cat.contains('entertain')) return Icons.movie;
    if (cat.contains('health') || cat.contains('medical')) {
      return Icons.local_hospital;
    }
    if (cat.contains('education')) return Icons.school;
    return Icons.category;
  }

  Color _getCategoryColor(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('food')) return Colors.orange;
    if (cat.contains('transport')) return Colors.blue;
    if (cat.contains('utility')) return Colors.purple;
    if (cat.contains('salary')) return Colors.green;
    if (cat.contains('office')) return Colors.indigo;
    if (cat.contains('rent')) return Colors.brown;
    if (cat.contains('entertain')) return Colors.pink;
    if (cat.contains('health')) return Colors.red;
    if (cat.contains('education')) return Colors.teal;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Expenses"),
        elevation: 0,
        actions: [
          const SizedBox(width: 10),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Export to PDF',
            onPressed: () => _exportService.exportToPDF(_filteredExpenses),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              setState(() {
                _currentMax = _pageSize;
              });
              _loadExpenses();
            },
          ),
          IconButton(
            onPressed: () => _showAddEditExpenseDialog(),
            icon: const Icon(Icons.add_circle, size: 28),
            tooltip: 'Add Product',
          ),
          const SizedBox(width: 10),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(
            190,
          ), // Adjusted for proper spacing
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).primaryColor.withOpacity(0.1),
                  Theme.of(context).primaryColor.withOpacity(0.05),
                ],
              ),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: UnifiedSearchBar(
                    hintText: "Search by description, category, date...",
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    onClear: () {
                      setState(() {
                        _searchQuery = '';
                        _applyFilterAndSort();
                      });
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      const Text("Sort by: ", style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text("Date"),
                        selected: _sortMode == ExpenseSortMode.date,
                        onSelected: (selected) {
                          setState(() {
                            _sortMode = ExpenseSortMode.date;
                            _applyFilterAndSort();
                          });
                        },
                        selectedColor: Colors.blue.shade100,
                        checkmarkColor: Colors.blue,
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text("Amount"),
                        selected: _sortMode == ExpenseSortMode.amount,
                        onSelected: (selected) {
                          setState(() {
                            _sortMode = ExpenseSortMode.amount;
                            _applyFilterAndSort();
                          });
                        },
                        selectedColor: Colors.red.shade100,
                        checkmarkColor: Colors.red,
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              "Order:",
                              style: TextStyle(fontSize: 12),
                            ),
                            IconButton(
                              icon: Icon(
                                _sortAscending
                                    ? Icons.arrow_upward
                                    : Icons.arrow_downward,
                                size: 18,
                              ),
                              onPressed: _toggleSort,
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Row(
                    children: [
                      _chip("All", ExpenseFilterType.all),
                      const SizedBox(width: 6),
                      _chip("Daily", ExpenseFilterType.daily),
                      const SizedBox(width: 6),
                      _chip("Weekly", ExpenseFilterType.weekly),
                      const SizedBox(width: 6),
                      _chip("Monthly", ExpenseFilterType.monthly),
                      const SizedBox(width: 6),
                      _chip("Yearly", ExpenseFilterType.yearly),
                    ],
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.red.shade700, Colors.red.shade500],
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.account_balance_wallet,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Total: Rs ${_filteredTotal.toStringAsFixed(0)}",
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Expense Insights Card
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: ExpenseInsightsCard(
                    expenses: _expenses,
                    loading: false,
                    lastUpdated: DateTime.now(),
                  ),
                ),

                // Expense list
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: _currentMax > _filteredExpenses.length
                        ? _filteredExpenses.length
                        : _currentMax,
                    itemBuilder: (context, index) {
                      final expense = _filteredExpenses[index];
                      final categoryColor = _getCategoryColor(expense.category);
                      final categoryIcon = _getCategoryIcon(expense.category);
                      final date =
                          DateTime.tryParse(expense.date) ?? DateTime.now();
                      final dateStr =
                          "${date.day} ${_getMonthName(date.month)}";

                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white,
                              categoryColor.withOpacity(0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: categoryColor.withOpacity(0.2),
                              spreadRadius: 1,
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          border: Border.all(
                            color: categoryColor.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Colored strip
                              Container(
                                width: double.infinity,
                                height: 4,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      categoryColor,
                                      categoryColor.withOpacity(0.6),
                                    ],
                                  ),
                                ),
                              ),

                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Header Row
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Category Icon
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                categoryColor,
                                                categoryColor.withOpacity(0.7),
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: categoryColor
                                                    .withOpacity(0.3),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Icon(
                                            categoryIcon,
                                            color: Colors.white,
                                            size: 28,
                                          ),
                                        ),
                                        const SizedBox(width: 16),

                                        // Description & Category
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                expense.description,
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: categoryColor
                                                      .withOpacity(0.15),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color: categoryColor
                                                        .withOpacity(0.3),
                                                  ),
                                                ),
                                                child: Text(
                                                  expense.category,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: categoryColor
                                                        .withOpacity(0.9),
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Actions
                                        Column(
                                          children: [
                                            IconButton(
                                              icon: const Icon(
                                                Icons.edit_outlined,
                                                color: Colors.blue,
                                              ),
                                              onPressed: () =>
                                                  _showAddEditExpenseDialog(
                                                    expense,
                                                  ),
                                              tooltip: 'Edit',
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.delete_outline,
                                                color: Colors.red,
                                              ),
                                              onPressed: () async {
                                                final confirm = await showDialog<bool>(
                                                  context: context,
                                                  builder: (ctx) => AlertDialog(
                                                    title: const Text(
                                                      "Delete Expense?",
                                                    ),
                                                    content: Text(
                                                      "Are you sure you want to delete '${expense.description}'?",
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                              ctx,
                                                              false,
                                                            ),
                                                        child: const Text(
                                                          "Cancel",
                                                        ),
                                                      ),
                                                      ElevatedButton(
                                                        style:
                                                            ElevatedButton.styleFrom(
                                                              backgroundColor:
                                                                  Colors.red,
                                                              foregroundColor:
                                                                  Colors.white,
                                                            ),
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                              ctx,
                                                              true,
                                                            ),
                                                        child: const Text(
                                                          "Delete",
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );

                                                if (confirm == true) {
                                                  await _repo.deleteExpense(
                                                    expense.id,
                                                  );
                                                  _loadExpenses();
                                                }
                                              },
                                              tooltip: 'Delete',
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 16),
                                    const Divider(),
                                    const SizedBox(height: 12),

                                    // Amount & Date Row
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        // Amount
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "AMOUNT",
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.grey.shade500,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    Colors.red.shade600,
                                                    Colors.red.shade400,
                                                  ],
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.red
                                                        .withOpacity(0.3),
                                                    blurRadius: 6,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: Text(
                                                "Rs ${expense.amount.toStringAsFixed(0)}",
                                                style: const TextStyle(
                                                  fontSize: 20,
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),

                                        // Date Badge
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: categoryColor.withOpacity(
                                              0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: categoryColor.withOpacity(
                                                0.3,
                                              ),
                                              width: 2,
                                            ),
                                          ),
                                          child: Column(
                                            children: [
                                              Text(
                                                date.day.toString(),
                                                style: TextStyle(
                                                  fontSize: 24,
                                                  fontWeight: FontWeight.bold,
                                                  color: categoryColor,
                                                ),
                                              ),
                                              Text(
                                                _getMonthName(date.month),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: categoryColor
                                                      .withOpacity(0.8),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              Text(
                                                date.year.toString(),
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
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

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }
}
