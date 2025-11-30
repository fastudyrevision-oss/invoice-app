import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../dao/customer_payment_dao.dart';
import '../../models/customer_payment.dart';
import '../../models/customer.dart';

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
  late String? _transactionRef;
  late String? _note;

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
      _transactionRef = widget.paymentData!['transaction_ref'];
      _note = widget.paymentData!['note'];
    } else {
      // Add mode
      _selectedCustomerId = widget.customers.isNotEmpty
          ? widget.customers.first.id
          : null;
      _amount = 0.0;
      _method = 'cash';
      _date = DateTime.now();
      _transactionRef = null;
      _note = null;
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
    setState(() => _isSaving = true);

    try {
      final payment = CustomerPayment(
        id: widget.paymentData?['id'] ?? const Uuid().v4(),
        customerId: _selectedCustomerId!,
        amount: _amount,
        method: _method,
        date: _date.toIso8601String().split('T')[0],
        transactionRef: _transactionRef?.isEmpty == true
            ? null
            : _transactionRef,
        note: _note?.isEmpty == true ? null : _note,
      );

      if (widget.paymentData != null) {
        await _paymentDao.update(payment);
      } else {
        await _paymentDao.insert(payment);
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.paymentData != null
                  ? 'Payment updated successfully'
                  : 'Payment added successfully',
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving payment: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.paymentData != null ? 'Edit Payment' : 'Add Payment'),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Customer dropdown
                DropdownButtonFormField<String>(
                  value: _selectedCustomerId,
                  decoration: const InputDecoration(
                    labelText: 'Customer *',
                    border: OutlineInputBorder(),
                  ),
                  items: widget.customers.map((customer) {
                    return DropdownMenuItem(
                      value: customer.id,
                      child: Text(customer.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedCustomerId = value);
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a customer';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Amount
                TextFormField(
                  initialValue: widget.paymentData != null
                      ? _amount.toString()
                      : '',
                  decoration: const InputDecoration(
                    labelText: 'Amount *',
                    border: OutlineInputBorder(),
                    prefixText: 'Rs ',
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
                const SizedBox(height: 16),

                // Payment method
                DropdownButtonFormField<String>(
                  value: _method,
                  decoration: const InputDecoration(
                    labelText: 'Payment Method *',
                    border: OutlineInputBorder(),
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
                const SizedBox(height: 16),

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
                    decoration: const InputDecoration(
                      labelText: 'Date *',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(DateFormat('dd/MM/yyyy').format(_date)),
                  ),
                ),
                const SizedBox(height: 16),

                // Transaction reference
                TextFormField(
                  initialValue: _transactionRef,
                  decoration: const InputDecoration(
                    labelText: 'Transaction Reference',
                    border: OutlineInputBorder(),
                    hintText: 'e.g., CHQ123456, TXN789',
                  ),
                  onSaved: (value) => _transactionRef = value,
                ),
                const SizedBox(height: 16),

                // Note
                TextFormField(
                  initialValue: _note,
                  decoration: const InputDecoration(
                    labelText: 'Note',
                    border: OutlineInputBorder(),
                    hintText: 'Optional note',
                  ),
                  maxLines: 3,
                  onSaved: (value) => _note = value,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _savePayment,
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.paymentData != null ? 'Update' : 'Save'),
        ),
      ],
    );
  }
}
