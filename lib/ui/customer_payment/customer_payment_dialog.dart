import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../dao/customer_payment_dao.dart';
import '../../models/customer_payment.dart';
import '../../models/customer.dart';
import '../../dao/invoice_dao.dart';
import '../../models/invoice.dart';
import '../../db/database_helper.dart';

class CustomerPaymentDialog extends StatefulWidget {
  final List<Customer> customers;
  final Map<String, dynamic>? paymentData;

  const CustomerPaymentDialog({
    super.key,
    required this.customers,
    this.paymentData,
  });

  @override
  State<CustomerPaymentDialog> createState() => _CustomerPaymentDialogState();
}

class _CustomerPaymentDialogState extends State<CustomerPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _paymentDao = CustomerPaymentDao();

  late String? _selectedCustomerId;
  late double _amount;
  late String _method;
  late DateTime _date;
  late String? _selectedInvoiceId;
  late String? _transactionReference;
  late String? _note;

  List<Invoice> _pendingInvoices = [];
  bool _isLoadingInvoices = false;

  bool _isSaving = false;

  final List<String> _paymentMethods = [
    'cash',
    'card',
    'bank_transfer',
    'upi',
    'cheque',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.paymentData != null) {
      // Edit mode
      _selectedCustomerId = widget.paymentData!['customer_id'];
      _amount = (widget.paymentData!['amount'] as num).toDouble();
      _method = widget.paymentData!['method'] ?? 'cash';
      _date = DateTime.parse(widget.paymentData!['date']);

      // ✅ Fix: Remove transaction_ref fallback. Only use invoice_id.
      _selectedInvoiceId = widget.paymentData!['invoice_id'];

      _transactionReference = widget.paymentData!['transaction_ref'];
      _note = widget.paymentData!['note'];
    } else {
      // Add mode
      // ... (existing add mode init)
      _selectedCustomerId = widget.customers.isNotEmpty
          ? widget.customers.first.id
          : null;
      _amount = 0.0;
      _method = 'cash';
      _date = DateTime.now();
      _selectedInvoiceId = null;
      _transactionReference = null;
      _note = null;
    }

    if (_selectedCustomerId != null) {
      // ✅ Pass the selectedInvoiceId so we can fetch it even if it's fully paid
      _loadPendingInvoices(
        _selectedCustomerId!,
        linkedInvoiceId: _selectedInvoiceId,
      );
    }
  }

  Future<void> _loadPendingInvoices(
    String customerId, {
    String? linkedInvoiceId,
  }) async {
    setState(() => _isLoadingInvoices = true);
    try {
      final db = await DatabaseHelper.instance.db;
      final invoiceDao = InvoiceDao(db);

      // 1. Get all pending invoices
      final invoices = await invoiceDao.getPendingByCustomerId(customerId);

      // 2. ✅ If we have a linked invoice (Edit mode), ensure it's in the list
      // ignoring 'pending' status (it might be fully paid now)
      if (linkedInvoiceId != null &&
          !invoices.any((i) => i.id == linkedInvoiceId)) {
        final linkedInvoice = await invoiceDao.getById(linkedInvoiceId);
        if (linkedInvoice != null) {
          invoices.add(linkedInvoice);
          // Sort or prepend? Maybe prepend to make it visible
          invoices.sort((a, b) => b.date.compareTo(a.date));
        }
      }

      setState(() {
        _pendingInvoices = invoices;
        _isLoadingInvoices = false;
      });
    } catch (e) {
      setState(() => _isLoadingInvoices = false);
      debugPrint("Error loading invoices: $e");
    }
  }

  Future<void> _savePayment() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCustomerId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a customer')));
      return;
    }

    _formKey.currentState!.save();

    // ✅ Real Edit check: Must have paymentData AND it must contain an 'id'
    final isRealEdit =
        widget.paymentData != null && widget.paymentData!.containsKey('id');

    // ✅ Overpayment validation for specific invoices
    if (_selectedInvoiceId != null) {
      // Handle case where selected invoice might not be in _pendingInvoices list (edge case)
      // Though our fix above should prevent this.
      final selectedInv = _pendingInvoices.firstWhere(
        (i) => i.id == _selectedInvoiceId,
        orElse: () => Invoice(
          id: 'unknown',
          customerId: '',
          customerName: '',
          total: 0,
          pending: 0,
          date: '',
          createdAt: '',
          updatedAt: '',
        ),
      );

      if (selectedInv.id != 'unknown') {
        // In edit mode, we account for the existing payment amount
        double maxAllowed = selectedInv.pending;
        if (isRealEdit) {
          final oldAmount = (widget.paymentData!['amount'] as num).toDouble();
          maxAllowed += oldAmount;
        }

        if (_amount > maxAllowed) {
          // ... (existing overpayment dialog logic)
          final proceed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Overpayment Warning'),
              content: Text(
                'You are paying Rs ${_amount.toStringAsFixed(2)} for an invoice with only Rs ${maxAllowed.toStringAsFixed(2)} pending. This will result in a negative balance for this invoice. Is this intended?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Correct Amount'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Proceed Anyway'),
                ),
              ],
            ),
          );
          if (proceed != true) return;
        }
      }
    }

    setState(() => _isSaving = true);

    try {
      final payment = CustomerPayment(
        id: isRealEdit ? widget.paymentData!['id'] : const Uuid().v4(),
        customerId: _selectedCustomerId!,
        invoiceId: _selectedInvoiceId, // ✅ Link to specific invoice
        amount: _amount,
        method: _method,
        date: _date.toIso8601String().split('T')[0],
        transactionRef: _transactionReference,
        note: _note?.isEmpty == true ? null : _note,
      );

      final oldPayment = isRealEdit
          ? CustomerPayment.fromMap(widget.paymentData!)
          : null;

      // ✅ Use the new transacted processPayment method
      await _paymentDao.processPayment(
        payment: payment,
        isUpdate: isRealEdit,
        oldPayment: oldPayment,
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isRealEdit
                  ? 'Payment updated and balances adjusted'
                  : 'Payment processed and balances updated',
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error processing payment: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.paymentData != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isEdit
                    ? [Colors.blue.shade700, Colors.blue.shade500]
                    : [Colors.green.shade700, Colors.green.shade500],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isEdit ? Icons.edit : Icons.add_card,
                  color: Colors.white,
                  size: 28,
                ),
                const SizedBox(width: 16),
                Text(
                  isEdit ? 'Edit Payment' : 'New Payment',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Customer dropdown
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCustomerId,
                      decoration: InputDecoration(
                        labelText: 'Customer',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      items: widget.customers.map((customer) {
                        return DropdownMenuItem(
                          value: customer.id,
                          child: Text(customer.name),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCustomerId = value;
                          _selectedInvoiceId = null; // Reset invoice selection
                        });
                        if (value != null) {
                          _loadPendingInvoices(value);
                        }
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a customer';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Amount
                    TextFormField(
                      initialValue: widget.paymentData != null
                          ? _amount.toString()
                          : '',
                      decoration: InputDecoration(
                        labelText: 'Amount',
                        prefixIcon: const Icon(Icons.attach_money),
                        prefixText: 'Rs ',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}'),
                        ),
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter amount';
                        }
                        final amount = double.tryParse(value);
                        if (amount == null || amount <= 0) {
                          return 'Please enter a valid amount';
                        }
                        return null;
                      },
                      onSaved: (value) => _amount = double.parse(value!),
                    ),
                    const SizedBox(height: 20),

                    // Payment method
                    DropdownButtonFormField<String>(
                      initialValue: _method,
                      decoration: InputDecoration(
                        labelText: 'Payment Method',
                        prefixIcon: const Icon(Icons.payment),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      items: _paymentMethods.map((method) {
                        return DropdownMenuItem(
                          value: method,
                          child: Text(method.toUpperCase()),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _method = value!);
                      },
                    ),
                    const SizedBox(height: 20),

                    // Transaction reference (conditional)
                    if (_method != 'cash') ...[
                      TextFormField(
                        initialValue: _transactionReference,
                        decoration: InputDecoration(
                          labelText: 'Reference Number / Cheque No',
                          prefixIcon: const Icon(
                            Icons.confirmation_number_outlined,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          hintText: 'e.g. Bank TXN ID or Cheque No',
                        ),
                        onSaved: (value) => _transactionReference = value,
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Date
                    InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _date,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) {
                          setState(() => _date = date);
                        }
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Date',
                          prefixIcon: const Icon(Icons.calendar_today),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        child: Text(
                          DateFormat('dd/MM/yyyy').format(_date),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Transaction reference (Invoice Selection)
                    DropdownButtonFormField<String>(
                      initialValue:
                          _pendingInvoices.any(
                            (i) => i.id == _selectedInvoiceId,
                          )
                          ? _selectedInvoiceId
                          : null,
                      decoration: InputDecoration(
                        labelText: 'Link to Invoice (Optional)',
                        prefixIcon: const Icon(Icons.receipt_long),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        suffixIcon: _isLoadingInvoices
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('No Invoice / General Payment'),
                        ),
                        ..._pendingInvoices.map((invoice) {
                          return DropdownMenuItem<String>(
                            value: invoice.id,
                            child: Text(
                              'Inv #${invoice.id.substring(0, 8)}... - Pending: Rs ${invoice.pending.toStringAsFixed(2)}',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedInvoiceId = value;
                          // Optional: Auto-fill amount if an invoice is selected and amount is 0
                          if (value != null && _amount == 0) {
                            final invoice = _pendingInvoices.firstWhere(
                              (i) => i.id == value,
                            );
                            _amount = invoice.pending;
                          }
                        });
                      },
                      onSaved: (value) => _selectedInvoiceId = value,
                    ),
                    const SizedBox(height: 20),

                    // Note
                    TextFormField(
                      initialValue: _note,
                      decoration: InputDecoration(
                        labelText: 'Note',
                        prefixIcon: const Icon(Icons.note),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        hintText: 'Optional note',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      maxLines: 3,
                      onSaved: (value) => _note = value,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Actions
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isSaving
                      ? null
                      : () => Navigator.pop(context, false),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _isSaving ? null : _savePayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isEdit ? Colors.blue : Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          isEdit ? 'Update Payment' : 'Save Payment',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
