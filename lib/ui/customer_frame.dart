import 'package:flutter/material.dart';
import '../models/customer.dart';
import '../models/customer_payment.dart';
import '../repositories/customer_repository.dart';
import '../db/database_helper.dart';
class CustomerFrame extends StatefulWidget {
  const CustomerFrame({super.key});

  @override
  _CustomerFrameState createState() => _CustomerFrameState();
}

class _CustomerFrameState extends State<CustomerFrame> {
 
  CustomerRepository? _repo ;
  List<Customer> _customers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
     _initRepo(); // initialize database + repository first
  

  }
  Future<void> _initRepo() async {
    final db = await DatabaseHelper.instance.db;
    setState(() {
      _repo = CustomerRepository(db);
    });
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    final data = await _repo!.getAllCustomers();
    setState(() {
      _customers = data;
      _isLoading = false;
    });
  }

  void _showAddCustomerDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Add Customer"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: InputDecoration(labelText: "Name")),
            TextField(controller: phoneController, decoration: InputDecoration(labelText: "Phone")),
            TextField(controller: emailController, decoration: InputDecoration(labelText: "Email")),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              final customer = Customer(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: nameController.text,
                phone: phoneController.text,
                email: emailController.text,
                pendingAmount: 0.0,
                createdAt: DateTime.now().toIso8601String(),
                updatedAt: DateTime.now().toIso8601String(),
              );
              await _repo!.addCustomer(customer);
              Navigator.pop(context);
              _loadCustomers();
            },
            child: Text("Add"),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel")),
        ],
      ),
    );
  }

  void _showEditCustomerDialog(Customer customer) {
    final nameController = TextEditingController(text: customer.name);
    final phoneController = TextEditingController(text: customer.phone);
    final emailController = TextEditingController(text: customer.email ?? "");

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Edit Customer"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: InputDecoration(labelText: "Name")),
            TextField(controller: phoneController, decoration: InputDecoration(labelText: "Phone")),
            TextField(controller: emailController, decoration: InputDecoration(labelText: "Email")),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              final updatedCustomer = Customer(
                id: customer.id,
                name: nameController.text,
                phone: phoneController.text,
                email: emailController.text,
                pendingAmount: customer.pendingAmount,
                createdAt: customer.createdAt,
                updatedAt: DateTime.now().toIso8601String(),
              );

              await _repo!.updateCustomer(updatedCustomer);
              Navigator.pop(context);
              _loadCustomers();
            },
            child: Text("Update"),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel")),
        ],
      ),
    );
  }

  void _showAddPaymentDialog(Customer customer) {
    final amountController = TextEditingController();
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Add Payment for ${customer.name}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              decoration: InputDecoration(labelText: "Amount"),
              keyboardType: TextInputType.number,
            ),
            TextField(controller: noteController, decoration: InputDecoration(labelText: "Note")),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              final payment = CustomerPayment(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                customerId: customer.id,
                amount: double.tryParse(amountController.text) ?? 0.0,
                note: noteController.text,
                date: DateTime.now().toIso8601String(),
              );
              await _repo!.addPayment(payment);
              Navigator.pop(context);
              _loadCustomers();
            },
            child: Text("Add Payment"),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Customers"),
        actions: [
          IconButton(onPressed: _showAddCustomerDialog, icon: Icon(Icons.add)),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: [
                  DataColumn(label: Text("Name")),
                  DataColumn(label: Text("Phone")),
                  DataColumn(label: Text("Email")),
                  DataColumn(label: Text("Pending")),
                  DataColumn(label: Text("Actions")),
                ],
                rows: _customers
                    .map(
                      (c) => DataRow(cells: [
                        DataCell(Text(c.name)),
                        DataCell(Text(c.phone)),
                        DataCell(Text(c.email ?? "")),
                        DataCell(Text("\$${c.pendingAmount.toStringAsFixed(2)}")),
                        DataCell(Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.payment),
                              tooltip: "Add Payment",
                              onPressed: () => _showAddPaymentDialog(c),
                            ),
                            IconButton(
                              icon: Icon(Icons.edit),
                              tooltip: "Edit Customer",
                              onPressed: () => _showEditCustomerDialog(c),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete),
                              tooltip: "Delete Customer",
                              onPressed: () async {
                                await _repo!.deleteCustomer(c.id);
                                _loadCustomers();
                              },
                            ),
                          ],
                        )),
                      ]),
                    )
                    .toList(),
              ),
            ),
    );
  }
}
