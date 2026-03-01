import 'package:flutter/material.dart';
import '../models/expense.dart';
import '../repositories/expense_repository.dart';
import 'expense/expense_insights_card.dart';
import 'common/unified_search_bar.dart';
import '../services/expense_export_service.dart';
import '../utils/responsive_utils.dart';
import '../services/logger_service.dart';

import '../utils/date_helper.dart';

enum ExpenseSortMode { date, amount }

enum ExpenseFilterType { daily, weekly, monthly, yearly, all }

enum ExpenseViewMode { table, compact, card }

class ExpenseFrame extends StatefulWidget {
  const ExpenseFrame({super.key});

  @override
  State<ExpenseFrame> createState() => _ExpenseFrameState();
}

class _ExpenseFrameState extends State<ExpenseFrame> {
  final _formKey = GlobalKey<FormState>(); // Add FormKey
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
  ExpenseViewMode _viewMode = ExpenseViewMode.card;

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
    try {
      logger.info('ExpenseFrame', 'Loading all expenses');
      final data = await _repo.getAllExpenses();
      setState(() {
        _expenses = data;
        _applyFilterAndSort();
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      logger.error(
        'ExpenseFrame',
        'Failed to load expenses',
        error: e,
        stackTrace: stackTrace,
      );
      setState(() => _isLoading = false);
    }
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
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: descController,
                decoration: const InputDecoration(labelText: "Description"),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: amountController,
                decoration: const InputDecoration(labelText: "Amount"),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Required';
                  final v = double.tryParse(value);
                  if (v == null || v <= 0) return 'Must be > 0';
                  return null;
                },
              ),
              TextFormField(
                controller: dateController,
                decoration: const InputDecoration(
                  labelText: "Date (DD-MM-YYYY)",
                  hintText: "30-12-2026",
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                readOnly: true,
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    dateController.text = DateHelper.formatDate(picked);
                  }
                },
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Required';
                  if (!DateHelper.isValidDate(value)) return 'Invalid Format';
                  return null;
                },
              ),
              TextFormField(
                controller: categoryController,
                decoration: const InputDecoration(labelText: "Category"),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Required' : null,
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                // Parse DD-MM-YYYY to ISO for storage
                final dateObj = DateHelper.parseDate(dateController.text);
                final isoDate = dateObj != null
                    ? dateObj.toIso8601String()
                    : DateTime.now().toIso8601String();

                final newExpense = Expense(
                  id:
                      expense?.id ??
                      DateTime.now().millisecondsSinceEpoch.toString(),
                  description: descController.text,
                  amount: double.tryParse(amountController.text) ?? 0.0,
                  date: isoDate, // Store as ISO
                  category: categoryController.text,
                );

                if (expense == null) {
                  await _repo.addExpense(newExpense);
                } else {
                  await _repo.updateExpense(newExpense);
                }

                if (!context.mounted) return;
                Navigator.pop(context);
                _loadExpenses();
              }
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
      selectedColor: chipColor.withValues(alpha: 0.2),
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

  Future<void> _handleExport(String outputType) async {
    if (_filteredExpenses.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No expenses to export')));
      return;
    }

    try {
      if (outputType == 'print') {
        logger.info('ExpenseFrame', 'Printing expense report');
        await _exportService.printExpenseReport(_filteredExpenses);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Sent to printer'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else if (outputType == 'save') {
        logger.info('ExpenseFrame', 'Saving expense report PDF');
        final file = await _exportService.saveExpenseReportPdf(
          _filteredExpenses,
        );
        if (mounted && file != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Saved: ${file.path}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else if (outputType == 'share') {
        logger.info('ExpenseFrame', 'Sharing expense report PDF');
        await _exportService.exportToPDF(_filteredExpenses);
      }
    } catch (e, stackTrace) {
      logger.error(
        'ExpenseFrame',
        'Export error',
        error: e,
        stackTrace: stackTrace,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Export error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = ResponsiveUtils.isMobile(context);

        return Scaffold(
          backgroundColor: Colors.grey[100],
          appBar: AppBar(
            title: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: const Text("Expenses"),
            ),
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.red.shade800, Colors.red.shade500],
                ),
              ),
            ),
            elevation: 2,
            foregroundColor: Colors.white,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: isMobile
                ? [
                    IconButton(
                      icon: Icon(_viewModeIcon()),
                      tooltip: 'View: ${_viewModeLabel()}',
                      onPressed: _cycleViewMode,
                    ),
                    IconButton(
                      icon: const Icon(Icons.insights),
                      tooltip: 'Insights',
                      onPressed: _showInsightsDialog,
                    ),
                    IconButton(
                      onPressed: _showAddEditExpenseDialog,
                      icon: const Icon(Icons.add_circle),
                      tooltip: 'Add Expense',
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'print' ||
                            value == 'save' ||
                            value == 'share') {
                          _handleExport(value);
                        } else if (value == 'refresh') {
                          setState(() => _currentMax = _pageSize);
                          _loadExpenses();
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'print',
                          child: Row(
                            children: [
                              Icon(Icons.print),
                              SizedBox(width: 8),
                              Text('Print List'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'save',
                          child: Row(
                            children: [
                              Icon(Icons.save),
                              SizedBox(width: 8),
                              Text('Save PDF'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'share',
                          child: Row(
                            children: [
                              Icon(Icons.share),
                              SizedBox(width: 8),
                              Text('Share PDF'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'refresh',
                          child: Row(
                            children: [
                              Icon(Icons.refresh),
                              SizedBox(width: 8),
                              Text('Refresh'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ]
                : [
                    const SizedBox(width: 10),
                    // View toggle
                    Tooltip(
                      message: 'View: ${_viewModeLabel()}',
                      child: TextButton.icon(
                        icon: Icon(
                          _viewModeIcon(),
                          size: 20,
                          color: Colors.white,
                        ),
                        label: Text(
                          _viewModeLabel(),
                          style: const TextStyle(color: Colors.white),
                        ),
                        onPressed: _cycleViewMode,
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.insights, color: Colors.white),
                      tooltip: 'Insights',
                      onPressed: _showInsightsDialog,
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.print, color: Colors.white),
                      tooltip: 'Print List',
                      onPressed: () => _handleExport('print'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.save, color: Colors.white),
                      tooltip: 'Save PDF',
                      onPressed: () => _handleExport('save'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.share, color: Colors.white),
                      tooltip: 'Share PDF',
                      onPressed: () => _handleExport('share'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white),
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
                      icon: const Icon(
                        Icons.add_circle,
                        size: 28,
                        color: Colors.white,
                      ),
                      tooltip: 'Add Expense',
                    ),
                    const SizedBox(width: 10),
                  ],
            bottom: PreferredSize(
              preferredSize: Size.fromHeight(
                ResponsiveUtils.getAppBarBottomHeight(
                  context,
                  baseHeight: isMobile ? 170 : 210,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).primaryColor.withValues(alpha: 0.1),
                      Theme.of(context).primaryColor.withValues(alpha: 0.05),
                    ],
                  ),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: UnifiedSearchBar(
                        hintText: "Search expenses...",
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
                    if (!isMobile)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          children: [
                            const Text(
                              "Sort: ",
                              style: TextStyle(fontSize: 12),
                            ),
                            FilterChip(
                              label: const Text("Date"),
                              selected: _sortMode == ExpenseSortMode.date,
                              onSelected: (_) => setState(() {
                                _sortMode = ExpenseSortMode.date;
                                _applyFilterAndSort();
                              }),
                              selectedColor: Colors.blue.shade100,
                              visualDensity: VisualDensity.compact,
                            ),
                            const SizedBox(width: 8),
                            FilterChip(
                              label: const Text("Amount"),
                              selected: _sortMode == ExpenseSortMode.amount,
                              onSelected: (_) => setState(() {
                                _sortMode = ExpenseSortMode.amount;
                                _applyFilterAndSort();
                              }),
                              selectedColor: Colors.red.shade100,
                              visualDensity: VisualDensity.compact,
                            ),
                            const Spacer(),
                            InkWell(
                              onTap: _toggleSort,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Text(
                                      "Order:",
                                      style: TextStyle(fontSize: 12),
                                    ),
                                    Icon(
                                      _sortAscending
                                          ? Icons.arrow_upward
                                          : Icons.arrow_downward,
                                      size: 16,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
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
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
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
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Total: Rs ${_filteredTotal.toStringAsFixed(0)}",
                            style: const TextStyle(
                              fontSize: 16,
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
          body: _buildBody(),
        );
      },
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

  IconData _viewModeIcon() {
    switch (_viewMode) {
      case ExpenseViewMode.table:
        return Icons.table_chart;
      case ExpenseViewMode.compact:
        return Icons.view_list;
      case ExpenseViewMode.card:
        return Icons.view_agenda;
    }
  }

  void _cycleViewMode() {
    setState(() {
      switch (_viewMode) {
        case ExpenseViewMode.table:
          _viewMode = ExpenseViewMode.compact;
          break;
        case ExpenseViewMode.compact:
          _viewMode = ExpenseViewMode.card;
          break;
        case ExpenseViewMode.card:
          _viewMode = ExpenseViewMode.table;
          break;
      }
    });
  }

  String _viewModeLabel() {
    switch (_viewMode) {
      case ExpenseViewMode.table:
        return 'Table';
      case ExpenseViewMode.compact:
        return 'Compact';
      case ExpenseViewMode.card:
        return 'Card';
    }
  }

  void _showInsightsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Expense Insights',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(8),
                  child: ExpenseInsightsCard(
                    expenses: _expenses,
                    loading: false,
                    lastUpdated: DateTime.now(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_filteredExpenses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              "No expenses found",
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _currentMax = _pageSize);
        await _loadExpenses();
      },
      child: _viewMode == ExpenseViewMode.table
          ? _buildTableView()
          : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: _currentMax > _filteredExpenses.length
                  ? _filteredExpenses.length
                  : _currentMax,
              itemBuilder: (context, index) {
                final expense = _filteredExpenses[index];
                if (_viewMode == ExpenseViewMode.compact) {
                  return _buildCompactItem(expense);
                }
                return _buildCardItem(expense);
              },
            ),
    );
  }

  Widget _buildTableView() {
    return Scrollbar(
      controller: _scrollController,
      child: SingleChildScrollView(
        controller: _scrollController,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 24,
            columns: const [
              DataColumn(label: Text("DATE")),
              DataColumn(label: Text("DESCRIPTION")),
              DataColumn(label: Text("CATEGORY")),
              DataColumn(label: Text("AMOUNT")),
              DataColumn(label: Text("ACTIONS")),
            ],
            rows: _filteredExpenses.take(_currentMax).map((e) {
              final date = DateTime.tryParse(e.date) ?? DateTime.now();
              return DataRow(
                cells: [
                  DataCell(Text(DateHelper.formatDate(date))),
                  DataCell(
                    SizedBox(
                      width: 200,
                      child: Text(
                        e.description,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(Text(e.category)),
                  DataCell(
                    Text(
                      "Rs ${e.amount.toStringAsFixed(0)}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.edit,
                            color: Colors.blue,
                            size: 18,
                          ),
                          onPressed: () => _showAddEditExpenseDialog(e),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: Colors.red,
                            size: 18,
                          ),
                          onPressed: () => _deleteExpense(e),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteExpense(Expense expense) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Expense?"),
        content: Text(
          "Are you sure you want to delete '${expense.description}'?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _repo.deleteExpense(expense.id);
      _loadExpenses();
    }
  }

  Widget _buildCompactItem(Expense expense) {
    final date = DateTime.tryParse(expense.date) ?? DateTime.now();
    final categoryColor = _getCategoryColor(expense.category);
    final categoryIcon = _getCategoryIcon(expense.category);

    return ListTile(
      dense: true,
      leading: CircleAvatar(
        backgroundColor: categoryColor.withValues(alpha: 0.1),
        child: Icon(categoryIcon, color: categoryColor, size: 20),
      ),
      title: Text(
        expense.description,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text("${expense.category} | ${DateHelper.formatDate(date)}"),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Rs ${expense.amount.toStringAsFixed(0)}",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.edit, size: 16, color: Colors.blue),
            onPressed: () => _showAddEditExpenseDialog(expense),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildCardItem(Expense expense) {
    final categoryColor = _getCategoryColor(expense.category);
    final categoryIcon = _getCategoryIcon(expense.category);
    final date = DateTime.tryParse(expense.date) ?? DateTime.now();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, categoryColor.withValues(alpha: 0.05)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: categoryColor.withValues(alpha: 0.2),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: categoryColor.withValues(alpha: 0.3),
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
                  colors: [categoryColor, categoryColor.withValues(alpha: 0.6)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              categoryColor,
                              categoryColor.withValues(alpha: 0.7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          categoryIcon,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              expense.description,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: categoryColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: categoryColor.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                expense.category,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: categoryColor.withValues(alpha: 0.9),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.edit_outlined,
                          color: Colors.blue,
                        ),
                        onPressed: () => _showAddEditExpenseDialog(expense),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        onPressed: () => _deleteExpense(expense),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                            padding: const EdgeInsets.symmetric(
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
                              borderRadius: BorderRadius.circular(8),
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
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: categoryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: categoryColor.withValues(alpha: 0.3),
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
                                color: categoryColor.withValues(alpha: 0.8),
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
  }
}
