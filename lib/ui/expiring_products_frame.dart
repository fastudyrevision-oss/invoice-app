import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/expiring_batch_detail.dart';
import '../repositories/purchase_repo.dart';
import 'expiring_batch_detail_frame.dart';
import 'package:sqflite/sqflite.dart';

import '../services/expiring_export_service.dart';
import '../utils/platform_file_helper.dart';
import '../utils/date_helper.dart';
import 'dialogs/stock_disposal_dialog.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../services/logger_service.dart';

class ExpiringProductsFrame extends StatefulWidget {
  final Database db;
  final VoidCallback? onDataChanged;

  const ExpiringProductsFrame({
    super.key,
    required this.db,
    this.onDataChanged,
  });

  @override
  State<ExpiringProductsFrame> createState() => _ExpiringProductsFrameState();
}

class _ExpiringProductsFrameState extends State<ExpiringProductsFrame> {
  late final PurchaseRepository _repo;
  List<ExpiringBatchDetail> _batches = [];
  bool _loading = true;

  int _filterDays = 30;
  bool _onlyInStock = false;
  bool _showExpired = false;
  bool _showAll = false;

  String _sortBy = "Expiry";
  final TextEditingController _daysController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  final List<int> _quickFilters = [30, 90, 180];

  @override
  void initState() {
    super.initState();
    _repo = PurchaseRepository(widget.db);
    _daysController.text = _filterDays.toString();
    _loadExpiring();
  }

  Future<void> _loadExpiring({
    int? days,
    bool? inStockOnly,
    bool? showExpired,
    bool? showAll,
  }) async {
    setState(() => _loading = true);

    final filter = days ?? _filterDays;
    final onlyInStock = inStockOnly ?? _onlyInStock;
    final expired = showExpired ?? _showExpired;
    final all = showAll ?? _showAll;

    logger.debug(
      'ExpiringProducts',
      'Loading expiring batches: days=$filter, onlyInStock=$onlyInStock, showExpired=$expired, showAll=$all',
    );

    var batches = await _repo.getExpiringBatchesDetailed(filter);

    final now = DateTime.now();
    if (onlyInStock) {
      batches = batches.where((b) => b.qty > 0).toList();
    }
    if (expired && !all) {
      batches = batches.where((b) => b.expiryDate.isBefore(now)).toList();
    }
    if (!expired && !all) {
      batches = batches.where((b) => b.expiryDate.isAfter(now)).toList();
    }

    // Apply search filter
    final search = _searchController.text.trim().toLowerCase();
    if (search.isNotEmpty) {
      batches = batches.where((b) {
        return b.productName.toLowerCase().contains(search) ||
            b.batchNo.toLowerCase().contains(search);
      }).toList();
    }

    // Sort
    batches.sort((a, b) {
      switch (_sortBy) {
        case "Quantity":
          return b.qty.compareTo(a.qty);
        case "Name":
          return a.productName.compareTo(b.productName);
        default:
          return a.expiryDate.compareTo(b.expiryDate);
      }
    });

    // Pinned expired (expired ones first)
    final expiredList = batches
        .where((b) => b.expiryDate.isBefore(now))
        .toList();
    final nonExpired = batches
        .where((b) => !b.expiryDate.isBefore(now))
        .toList();
    batches = [...expiredList, ...nonExpired];

    if (!mounted) return;
    setState(() {
      _batches = batches;
      _loading = false;
      _filterDays = filter;
      _onlyInStock = onlyInStock;
      _showExpired = expired;
      _showAll = all;
    });

    widget.onDataChanged?.call();
  }

  Color _getTileColor(DateTime expiry, BuildContext context) {
    final now = DateTime.now();
    final diff = expiry.difference(now).inDays;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color color;
    if (diff < 0) {
      color = Colors.grey.shade600;
    } else if (diff <= 7)
      color = const Color.fromARGB(255, 245, 2, 2);
    else if (diff <= 15)
      color = Colors.orange.shade300;
    else if (diff <= 30)
      color = Colors.yellow.shade300;
    else if (diff <= 90)
      color = Colors.blue.shade200;
    else
      color = Colors.green.shade100;

    return isDark ? color.withValues(alpha: 0.3) : color;
  }

  Future<void> _handleExport(String outputType) async {
    if (_batches.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No data to export')));
      }
      return;
    }

    try {
      if (outputType == 'print') {
        final service = ExpiringExportService();
        await service.printExpiringProducts(_batches);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Sent to printer'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else if (outputType == 'save') {
        final service = ExpiringExportService();
        final file = await service.saveExpiringProductsPdf(_batches);
        if (mounted && file != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Saved: ${file.path}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else if (outputType == 'share') {
        final service = ExpiringExportService();
        await service.exportToPDF(_batches);
      } else if (outputType == 'csv') {
        await _exportCSV();
      }
    } catch (e) {
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

  Future<void> _exportCSV() async {
    final buffer = StringBuffer();
    buffer.writeln("Product,Batch,Qty,Expiry Date");
    for (final b in _batches) {
      buffer.writeln(
        "${b.productName},${b.batchNo},${b.qty},${DateHelper.formatIso(b.expiryDate.toIso8601String())}",
      );
    }

    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final suggestedFileName = 'expiring_products_$timestamp.csv';

    try {
      // Use platform-aware file handling (Android: share, Desktop: file picker)
      final file = await PlatformFileHelper.saveCsvFile(
        csvContent: buffer.toString(),
        suggestedName: suggestedFileName,
        dialogTitle: 'Save Expiring Products CSV',
      );

      if (file != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CSV exported successfully')),
        );
      }
    } catch (e) {
      rethrow; // Handled in _handleExport
    }
  }

  Widget _buildLegend() {
    final items = [
      {"color": Colors.red.shade300, "label": "≤ 7 days"},
      {"color": Colors.orange.shade300, "label": "≤ 15 days"},
      {"color": Colors.yellow.shade300, "label": "≤ 30 days"},
      {"color": Colors.blue.shade200, "label": "≤ 90 days"},
      {"color": Colors.green.shade100, "label": "> 90 days"},
      {"color": Colors.grey.shade400, "label": "Expired"},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        children: items
            .map(
              (item) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 6,
                    backgroundColor: item["color"] as Color,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    item["label"] as String,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildValueSummary() {
    double totalValue = 0;
    for (var b in _batches) {
      totalValue += b.qty * (b.purchasePrice ?? 0);
    }
    final currencyFormat = NumberFormat.currency(symbol: 'Rs. ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            "Value of items in list:",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            currencyFormat.format(totalValue),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        return Column(
          children: [
            // FILTER BAR
            Container(
              color: isDark
                  ? Colors.grey.shade900
                  : Theme.of(context).cardColor,
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  _buildValueSummary(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search),
                            hintText: "Search by product or batch...",
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (_) => _loadExpiring(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Actions
                      if (!isMobile) ...[
                        IconButton(
                          icon: const Icon(Icons.print),
                          tooltip: "Print List",
                          onPressed: () => _handleExport('print'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.save),
                          tooltip: "Save PDF",
                          onPressed: () => _handleExport('save'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.share),
                          tooltip: "Share PDF",
                          onPressed: () => _handleExport('share'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.table_chart),
                          tooltip: "Export CSV",
                          onPressed: () => _handleExport('csv'),
                        ),
                      ] else
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          onSelected: (v) {
                            _handleExport(v);
                          },
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(
                              value: 'print',
                              child: Text('Print List'),
                            ),
                            const PopupMenuItem(
                              value: 'save',
                              child: Text('Save PDF'),
                            ),
                            const PopupMenuItem(
                              value: 'share',
                              child: Text('Share PDF'),
                            ),
                            const PopupMenuItem(
                              value: 'csv',
                              child: Text('Export CSV'),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Mobile stack or Row
                  if (isMobile)
                    Column(
                      children: [
                        Row(
                          children: [
                            SizedBox(
                              width: 80,
                              child: TextField(
                                controller: _daysController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: "Days",
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.filter_list_alt),
                              onPressed: () {
                                final enteredDays = int.tryParse(
                                  _daysController.text,
                                );
                                if (enteredDays != null && enteredDays > 0) {
                                  _loadExpiring(days: enteredDays);
                                }
                              },
                            ),
                            Expanded(
                              child: Wrap(
                                spacing: 4,
                                children: _quickFilters.map((d) {
                                  final active = _filterDays == d;
                                  return ChoiceChip(
                                    label: Text("$d"),
                                    selected: active,
                                    onSelected: (_) => _loadExpiring(days: d),
                                    visualDensity: VisualDensity.compact,
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              FilterChip(
                                label: const Text("In-stock"),
                                selected: _onlyInStock,
                                onSelected: (v) =>
                                    _loadExpiring(inStockOnly: v),
                              ),
                              const SizedBox(width: 8),
                              FilterChip(
                                label: const Text("Expired"),
                                selected: _showExpired,
                                onSelected: (v) => _loadExpiring(
                                  showExpired: v,
                                  showAll: false,
                                ),
                              ),
                              const SizedBox(width: 8),
                              FilterChip(
                                label: const Text("All"),
                                selected: _showAll,
                                onSelected: (v) => _loadExpiring(
                                  showAll: v,
                                  showExpired: false,
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Sort dropdown small
                              DropdownButton<String>(
                                value: _sortBy,
                                underline: Container(),
                                icon: const Icon(Icons.sort),
                                items: const [
                                  DropdownMenuItem(
                                    value: "Expiry",
                                    child: Text("Expiry"),
                                  ),
                                  DropdownMenuItem(
                                    value: "Quantity",
                                    child: Text("Qty"),
                                  ),
                                  DropdownMenuItem(
                                    value: "Name",
                                    child: Text("Name"),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _sortBy = val);
                                    _loadExpiring();
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  else
                    // Desktop Row
                    Row(
                      children: [
                        SizedBox(
                          width: 100,
                          child: TextField(
                            controller: _daysController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: "Days",
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            final enteredDays = int.tryParse(
                              _daysController.text,
                            );
                            if (enteredDays != null && enteredDays > 0) {
                              _loadExpiring(days: enteredDays);
                            }
                          },
                          child: const Text("Apply"),
                        ),
                        const SizedBox(width: 8),
                        ..._quickFilters.map((d) {
                          final active = _filterDays == d;
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 2.0,
                            ),
                            child: ChoiceChip(
                              label: Text("$d days"),
                              selected: active,
                              onSelected: (_) => _loadExpiring(days: d),
                            ),
                          );
                        }),
                        const Spacer(),
                        DropdownButton<String>(
                          value: _sortBy,
                          items: const [
                            DropdownMenuItem(
                              value: "Expiry",
                              child: Text("Sort: Expiry"),
                            ),
                            DropdownMenuItem(
                              value: "Quantity",
                              child: Text("Sort: Quantity"),
                            ),
                            DropdownMenuItem(
                              value: "Name",
                              child: Text("Sort: Name"),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _sortBy = val);
                              _loadExpiring();
                            }
                          },
                        ),
                      ],
                    ),

                  if (!isMobile) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        FilterChip(
                          label: const Text("Only in-stock"),
                          selected: _onlyInStock,
                          onSelected: (v) => _loadExpiring(inStockOnly: v),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text("Show expired"),
                          selected: _showExpired,
                          onSelected: (v) =>
                              _loadExpiring(showExpired: v, showAll: false),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text("Show all"),
                          selected: _showAll,
                          onSelected: (v) =>
                              _loadExpiring(showAll: v, showExpired: false),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // LEGEND & LIST
            _buildLegend(),
            const Divider(height: 1),

            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _batches.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.hourglass_empty,
                            size: 40,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 8),
                          Text("No matching products found."),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _batches.length,
                      itemBuilder: (context, i) {
                        final b = _batches[i];
                        final exp = b.expiryDate;
                        final diff = exp.difference(DateTime.now()).inDays;
                        final expired = diff < 0;
                        return Slidable(
                          endActionPane: ActionPane(
                            motion: const ScrollMotion(),
                            children: [
                              SlidableAction(
                                onPressed: (ctx) async {
                                  final result = await showDialog<bool>(
                                    context: context,
                                    builder: (_) =>
                                        StockDisposalDialog(batch: b),
                                  );
                                  if (result == true) {
                                    _loadExpiring();
                                  }
                                },
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                icon: Icons.delete_forever,
                                label: 'Dispose',
                              ),
                            ],
                          ),
                          child: Card(
                            color: _getTileColor(exp, context),
                            margin: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              leading: expired
                                  ? const Icon(
                                      Icons.warning_amber,
                                      color: Colors.red,
                                    )
                                  : const Icon(Icons.inventory_2_outlined),
                              title: Text(
                                b.productName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                "Batch: ${b.batchNo}, Qty: ${b.qty}, Expiry: ${DateHelper.formatIso(b.expiryDate.toIso8601String())}"
                                "\n${expired ? 'Expired ${-diff} days ago' : 'Expires in $diff days'}",
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => BatchDetailFrame(
                                      batch: b,
                                      db: widget.db,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
