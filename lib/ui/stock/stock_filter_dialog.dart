import 'package:flutter/material.dart';

class StockFilterDialog extends StatefulWidget {
  final bool includePrice;
  final bool onlyLowStock;
  final bool showExpiry;
  final bool detailedView;

  const StockFilterDialog({
    super.key,
    required this.includePrice,
    required this.onlyLowStock,
    required this.showExpiry,
    required this.detailedView,
  });

  @override
  State<StockFilterDialog> createState() => _StockFilterDialogState();
}

class _StockFilterDialogState extends State<StockFilterDialog> {
  late bool _includePrice;
  late bool _onlyLowStock;
  late bool _showExpiry;
  late bool _detailedView;

  @override
  void initState() {
    super.initState();
    _includePrice = widget.includePrice;
    _onlyLowStock = widget.onlyLowStock;
    _showExpiry = widget.showExpiry;
    _detailedView = widget.detailedView;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Stock Report Filters"),
      content: SingleChildScrollView(
        child: Column(
          children: [
            SwitchListTile(
              title: const Text("Include Prices"),
              value: _includePrice,
              onChanged: (v) => setState(() => _includePrice = v),
            ),
            SwitchListTile(
              title: const Text("Show Low Stock Only"),
              value: _onlyLowStock,
              onChanged: (v) => setState(() => _onlyLowStock = v),
            ),
            SwitchListTile(
              title: const Text("Show Expiry Date / Supplier"),
              value: _showExpiry,
              onChanged: (v) => setState(() => _showExpiry = v),
            ),
            SwitchListTile(
              title: const Text("Detailed View"),
              subtitle: const Text("Show more columns and calculations"),
              value: _detailedView,
              onChanged: (v) => setState(() => _detailedView = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context, {
              'includePrice': _includePrice,
              'onlyLowStock': _onlyLowStock,
              'showExpiry': _showExpiry,
              'detailedView': _detailedView,
            });
          },
          child: const Text("Apply"),
        ),
      ],
    );
  }
}
