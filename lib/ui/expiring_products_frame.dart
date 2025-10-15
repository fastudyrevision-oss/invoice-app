import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/expiring_batch_detail.dart';
import '../repositories/purchase_repo.dart';
import 'expiring_batch_detail_frame.dart';
import 'package:sqflite/sqflite.dart';

class ExpiringProductsFrame extends StatefulWidget {
  final Database db;
  final VoidCallback? onDataChanged;

  const ExpiringProductsFrame({super.key, required this.db, this.onDataChanged});

  @override
  State<ExpiringProductsFrame> createState() => _ExpiringProductsFrameState();
}

class _ExpiringProductsFrameState extends State<ExpiringProductsFrame> {
  late final PurchaseRepository _repo;
  List<ExpiringBatchDetail> _batches = [];
  bool _loading = true;

  int _filterDays = 30; // default filter
  final List<int> _filterOptions = [7, 15, 30, 90,180];

  @override
  void initState() {
    super.initState();
    _repo = PurchaseRepository(widget.db); // initialize repo here
    _loadExpiring();
  }

  Future<void> _loadExpiring({int? days}) async {
    setState(() {
      _loading = true;
    });

    final filter = days ?? _filterDays;

    // Fetch the detailed expiring batches
    final batches = await _repo.getExpiringBatchesDetailed(filter);

    if (!mounted) return;
    setState(() {
      _batches = batches;
      _loading = false;
      _filterDays = filter;
    });

    widget.onDataChanged?.call();
  }

  Color _getTileColor(DateTime expiry) {
    final now = DateTime.now();
    final difference = expiry.difference(now).inDays;

    if (difference <= 7) return Colors.red.shade300;
    if (difference <= 15) return Colors.yellow.shade300;
    if (difference <= 30) return Colors.brown.shade300;
    if (difference <=90) return Colors.blueGrey;
    
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Dropdown filter
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              const Text("Show expiring in: "),
              const SizedBox(width: 10),
              DropdownButton<int>(
                value: _filterDays,
                items: _filterOptions
                    .map((days) => DropdownMenuItem(
                          value: days,
                          child: Text("$days days"),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) _loadExpiring(days: value);
                },
              ),
            ],
          ),
        ),

        // Expanded ListView
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _batches.isEmpty
                  ? const Center(child: Text("No expiring products."))
                  : ListView.builder(
                      itemCount: _batches.length,
                      itemBuilder: (context, index) {
                        final batch = _batches[index];
                        final expiryDate = batch.expiryDate;

                        return Card(
                          color: _getTileColor(expiryDate),
                          child: ListTile(
                            title: Text(batch.productName),
                            subtitle: Text(
                                "Batch: ${batch.batchNo}, Qty: ${batch.qty}, Expiry: ${DateFormat('yyyy-MM-dd').format(expiryDate)}"),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => BatchDetailFrame(
                                    batch: batch,
                                    db: widget.db, // pass database only
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
