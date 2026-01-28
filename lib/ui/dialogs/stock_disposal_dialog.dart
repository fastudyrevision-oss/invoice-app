import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/stock_disposal.dart';
import '../../models/expiring_batch_detail.dart';
import '../../dao/stock_disposal_dao.dart';
import '../../dao/product_batch_dao.dart';
import '../../db/database_helper.dart';
import '../../core/services/audit_logger.dart';
import '../../services/auth_service.dart';
import '../../services/logger_service.dart';

class StockDisposalDialog extends StatefulWidget {
  final ExpiringBatchDetail batch;

  const StockDisposalDialog({super.key, required this.batch});

  @override
  State<StockDisposalDialog> createState() => _StockDisposalDialogState();
}

class _StockDisposalDialogState extends State<StockDisposalDialog> {
  final _formKey = GlobalKey<FormState>();
  final _qtyController = TextEditingController();
  final _notesController = TextEditingController();
  final _uuid = const Uuid();

  String _disposalType = 'write_off';
  String? _refundStatus;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _qtyController.text = widget.batch.qty.toString();
    // Update UI when quantity changes
    _qtyController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitDisposal() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _processing = true);

    try {
      final qty = int.tryParse(_qtyController.text) ?? 0;
      if (qty <= 0) throw Exception("Invalid quantity");

      final costLoss = (widget.batch.purchasePrice ?? 0) * qty;

      final disposal = StockDisposal(
        id: _uuid.v4(),
        batchId: widget.batch.batchId,
        productId: widget.batch.productId,
        supplierId: widget.batch.supplierId,
        qty: qty,
        disposalType: _disposalType,
        costLoss: costLoss,
        refundStatus: _disposalType == 'return'
            ? (_refundStatus ?? 'pending')
            : null,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        createdAt: DateTime.now().toIso8601String(),
      );

      final db = await DatabaseHelper.instance.db;
      final disposalDao = StockDisposalDao(db);
      final batchDao = ProductBatchDao(db);
      final messenger = ScaffoldMessenger.of(context);

      // Insert disposal record
      await disposalDao.insert(disposal);

      // ✅ DEDUCT FROM SPECIFIC BATCH (was generic FIFO before)
      await batchDao.deductFromSpecificBatch(widget.batch.batchId, qty);

      // 📝 ADD AUDIT LOG
      await AuditLogger.log(
        'DISPOSAL_CREATE',
        'stock_disposal',
        recordId: disposal.id,
        userId: AuthService.instance.currentUser?.id ?? 'system',
        newData: disposal.toMap(),
      );

      // 📝 ADD SYSTEM LOG
      logger.info(
        'StockDisposal',
        'Stock disposal recorded: ${widget.batch.productName} (Qty: $qty, Type: $_disposalType)',
        context: {
          'disposalId': disposal.id,
          'productId': widget.batch.productId,
        },
      );

      if (mounted) {
        Navigator.pop(context, true);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              _disposalType == 'write_off'
                  ? '✅ Stock written off successfully'
                  : '✅ Return to supplier recorded',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e, st) {
      logger.error(
        'StockDisposal',
        'Failed to record disposal',
        error: e,
        stackTrace: st,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Dispose Expired Stock'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Product: ${widget.batch.productName}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('Batch: ${widget.batch.batchNo}'),
              Text('Available Qty: ${widget.batch.qty}'),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _disposalType,
                decoration: const InputDecoration(
                  labelText: 'Disposal Type',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'write_off',
                    child: Text('Write Off (Loss)'),
                  ),
                  DropdownMenuItem(
                    value: 'return',
                    child: Text('Return to Supplier'),
                  ),
                ],
                onChanged: (val) {
                  setState(() {
                    _disposalType = val!;
                    if (_disposalType == 'return' && _refundStatus == null) {
                      _refundStatus = 'pending';
                    }
                  });
                },
              ),
              const SizedBox(height: 12),
              if (_disposalType == 'return')
                DropdownButtonFormField<String>(
                  initialValue: _refundStatus,
                  decoration: const InputDecoration(
                    labelText: 'Refund Status',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'pending', child: Text('Pending')),
                    DropdownMenuItem(
                      value: 'received',
                      child: Text('Received'),
                    ),
                    DropdownMenuItem(
                      value: 'rejected',
                      child: Text('Rejected'),
                    ),
                  ],
                  onChanged: (val) => setState(() => _refundStatus = val),
                ),
              if (_disposalType == 'return') const SizedBox(height: 12),
              TextFormField(
                controller: _qtyController,
                decoration: const InputDecoration(
                  labelText: 'Quantity to Dispose',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Required';
                  final qty = int.tryParse(val);
                  if (qty == null || qty <= 0) return 'Invalid quantity';
                  if (qty > widget.batch.qty) {
                    return 'Exceeds available quantity';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (Optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Cost Impact:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Loss: Rs ${((widget.batch.purchasePrice ?? 0) * (int.tryParse(_qtyController.text) ?? 0)).toStringAsFixed(2)}',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _processing ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _processing ? null : _submitDisposal,
          style: ElevatedButton.styleFrom(
            backgroundColor: _disposalType == 'write_off'
                ? Colors.red
                : Colors.orange,
          ),
          child: _processing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  _disposalType == 'write_off' ? 'Write Off' : 'Record Return',
                ),
        ),
      ],
    );
  }
}
