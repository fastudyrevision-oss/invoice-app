import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/dao/audit_log_dao.dart';
import '../data/models/audit_log_entry.dart';
import '../data/repository/audit_log_repository.dart';
import 'widgets/audit_log_card.dart';

class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  final AuditLogRepository _repo = AuditLogRepository(AuditLogDao());
  List<AuditLogEntry> _logs = [];
  bool _loading = true;

  // Filters
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedAction;
  String? _selectedTable;

  final List<String> _actions = ['CREATE', 'UPDATE', 'DELETE'];
  final List<String> _tables = [
    'invoices',
    'products',
    'customers',
    'suppliers',
    'manual_entries',
  ];

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    setState(() => _loading = true);
    try {
      final logs = await _repo.getLogs(
        start: _startDate,
        end: _endDate,
        action: _selectedAction,
        tableName: _selectedTable,
        limit: 100, // Load more for better visibility
      );
      setState(() {
        _logs = logs;
        _loading = false;
      });
    } catch (e) {
      debugPrint("Error fetching logs: $e");
      setState(() => _loading = false);
    }
  }

  void _showDetails(AuditLogEntry entry) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView(
              controller: scrollController,
              children: [
                Text(
                  "Audit Details",
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                _detailRow("Action", entry.action),
                _detailRow("Table", entry.tableName),
                _detailRow("Record ID", entry.recordId),
                _detailRow("User ID", entry.userId),
                _detailRow(
                  "Time",
                  DateFormat('yyyy-MM-dd HH:mm:ss').format(entry.timestamp),
                ),
                const Divider(height: 32),
                if (entry.oldData != null) ...[
                  const Text(
                    "Old Data:",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _jsonView(entry.oldData!),
                  const SizedBox(height: 16),
                ],
                if (entry.newData != null) ...[
                  const Text(
                    "New Data:",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _jsonView(entry.newData!),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              "$label:",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _jsonView(Map<String, dynamic> data) {
    const JsonEncoder encoder = JsonEncoder.withIndent('  ');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Text(
        encoder.convert(data),
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
      ),
    );
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end
            .add(const Duration(days: 1))
            .subtract(const Duration(seconds: 1));
      });
      _fetchLogs();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Audit Logs"),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _pickDateRange,
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchLogs),
        ],
      ),
      body: Column(
        children: [
          // Filters Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                if (_startDate != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Chip(
                      label: Text(
                        "${DateFormat('MM/dd').format(_startDate!)} - ${DateFormat('MM/dd').format(_endDate!)}",
                      ),
                      onDeleted: () {
                        setState(() {
                          _startDate = null;
                          _endDate = null;
                        });
                        _fetchLogs();
                      },
                    ),
                  ),
                _filterChip<String>(
                  label: "Action",
                  value: _selectedAction,
                  items: _actions,
                  onSelected: (val) {
                    setState(() => _selectedAction = val);
                    _fetchLogs();
                  },
                ),
                const SizedBox(width: 8),
                _filterChip<String>(
                  label: "Table",
                  value: _selectedTable,
                  items: _tables,
                  onSelected: (val) {
                    setState(() => _selectedTable = val);
                    _fetchLogs();
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _logs.isEmpty
                ? const Center(child: Text("No logs found"))
                : ListView.builder(
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      return AuditLogCard(
                        entry: _logs[index],
                        onTap: () => _showDetails(_logs[index]),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip<T>({
    required String label,
    required T? value,
    required List<T> items,
    required Function(T?) onSelected,
  }) {
    return InputChip(
      label: Text(value?.toString() ?? label),
      selected: value != null,
      onSelected: (_) async {
        // Simple dropdown logic for chip
        final selected = await showMenu<T>(
          context: context,
          position: const RelativeRect.fromLTRB(100, 100, 0, 0), // Approximate
          items: [
             PopupMenuItem<T>(value: null, child: Text("All")),
            ...items.map(
              (item) =>
                  PopupMenuItem<T>(value: item, child: Text(item.toString())),
            ),
          ],
        );
        onSelected(selected);
      },
      deleteIcon: const Icon(Icons.close, size: 18),
      onDeleted: value != null ? () => onSelected(null) : null,
    );
  }
}
