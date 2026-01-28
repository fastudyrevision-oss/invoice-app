import 'package:flutter/material.dart';
import '../../dao/stock_disposal_dao.dart';
import '../../models/stock_disposal.dart';
import '../../db/database_helper.dart';
import 'package:intl/intl.dart';

class ExpiredStockScreen extends StatefulWidget {
  const ExpiredStockScreen({super.key});

  @override
  State<ExpiredStockScreen> createState() => _ExpiredStockScreenState();
}

class _ExpiredStockScreenState extends State<ExpiredStockScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = true;
  List<StockDisposal> _disposals = [];
  Map<String, double> _stats = {
    'write_offs': 0.0,
    'pending_refunds': 0.0,
    'received_refunds': 0.0,
    'rejected_returns': 0.0,
    'net_loss': 0.0,
  };

  DateTimeRange? _dateRange;
  final String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final db = await DatabaseHelper.instance.db;
      final dao = StockDisposalDao(db);

      List<StockDisposal> disposals;
      if (_dateRange != null) {
        disposals = await dao.getByDateRange(
          _dateRange!.start,
          _dateRange!.end,
        );
      } else {
        disposals = await dao.getAll();
      }

      final stats = await dao.getTotalLoss(
        start: _dateRange?.start,
        end: _dateRange?.end,
      );

      if (mounted) {
        setState(() {
          _disposals = disposals;
          _stats = stats;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expired Stock Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _selectDateRange,
            tooltip: 'Filter by Date',
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Disposal History'),
            Tab(text: 'Returns & Refunds'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSummaryHeader(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildDisposalList(showAll: true),
                      _buildDisposalList(showAll: false, onlyReturns: true),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryHeader() {
    final currencyFormat = NumberFormat.currency(symbol: 'Rs. ');
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildStatCard(
              'Net Loss',
              currencyFormat.format(_stats['net_loss']),
              Colors.red,
            ),
            _buildStatCard(
              'Write-offs',
              currencyFormat.format(_stats['write_offs']),
              Colors.brown,
            ),
            _buildStatCard(
              'Pending Refunds',
              currencyFormat.format(_stats['pending_refunds']),
              Colors.orange,
            ),
            _buildStatCard(
              'Received Refunds',
              currencyFormat.format(_stats['received_refunds']),
              Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisposalList({bool showAll = true, bool onlyReturns = false}) {
    final filtered = _disposals.where((d) {
      if (onlyReturns && d.disposalType != 'return') return false;
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        return (d.productName?.toLowerCase().contains(query) ?? false) ||
            (d.productCode?.toLowerCase().contains(query) ?? false) ||
            (d.batchNo?.toLowerCase().contains(query) ?? false) ||
            d.productId.toLowerCase().contains(query);
      }
      return true;
    }).toList();

    if (filtered.isEmpty) {
      return const Center(child: Text('No records found'));
    }

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final disposal = filtered[index];
        return _buildDisposalTile(disposal);
      },
    );
  }

  Widget _buildDisposalTile(StockDisposal disposal) {
    final date = DateTime.tryParse(disposal.createdAt) ?? DateTime.now();
    final isReturn = disposal.disposalType == 'return';
    final currencyFormat = NumberFormat.currency(symbol: 'Rs. ');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isReturn
              ? Colors.orange.shade100
              : Colors.brown.shade100,
          child: Icon(
            isReturn ? Icons.assignment_return : Icons.delete_sweep,
            color: isReturn ? Colors.orange : Colors.brown,
          ),
        ),
        title: Text(
          disposal.productName ?? 'Unknown Product',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Batch: ${disposal.batchNo ?? 'N/A'} | Qty: ${disposal.qty}'),
            Text('Type: ${disposal.disposalType.toUpperCase()}'),
            Text('Date: ${DateFormat('yyyy-MM-dd HH:mm').format(date)}'),
            if (disposal.notes != null && disposal.notes!.isNotEmpty)
              Text(
                'Notes: ${disposal.notes}',
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            if (isReturn)
              Row(
                children: [
                  const Text('Refund: '),
                  _buildStatusChip(disposal.refundStatus ?? 'pending'),
                  const SizedBox(width: 8),
                  if (disposal.refundAmount > 0)
                    Text(currencyFormat.format(disposal.refundAmount)),
                ],
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              currencyFormat.format(disposal.costLoss),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            if (isReturn && disposal.refundStatus == 'pending')
              TextButton(
                onPressed: () => _updateRefundStatus(disposal),
                child: const Text('Update'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case 'received':
        color = Colors.green;
        break;
      case 'rejected':
        color = Colors.red;
        break;
      default:
        color = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _dateRange,
    );

    if (picked != null) {
      setState(() {
        _dateRange = picked;
      });
      _loadData();
    }
  }

  Future<void> _updateRefundStatus(StockDisposal disposal) async {
    String status = disposal.refundStatus ?? 'pending';
    final amountController = TextEditingController(
      text: disposal.costLoss.toString(),
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Refund Status'),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: ['pending', 'received', 'rejected']
                    .map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(s.toUpperCase()),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => status = val);
                },
              ),
              if (status == 'received')
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(labelText: 'Refund Amount'),
                  keyboardType: TextInputType.number,
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final db = await DatabaseHelper.instance.db;
              final dao = StockDisposalDao(db);
              await dao.updateRefundStatus(
                disposal.id,
                status,
                double.tryParse(amountController.text) ?? 0.0,
              );
              Navigator.pop(context);
              _loadData();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
