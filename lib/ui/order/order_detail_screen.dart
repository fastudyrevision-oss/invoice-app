import 'package:flutter/material.dart';
import '../../models/invoice.dart';
import '../../models/customer.dart';
import '../../dao/customer_dao.dart';
import '../../dao/product_dao.dart';
import '../../db/database_helper.dart';

class OrderDetailScreen extends StatefulWidget {
  final Invoice invoice;

  const OrderDetailScreen({super.key, required this.invoice});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  Customer? _customer;
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    final db = await DatabaseHelper.instance.db;
    final customerDao = CustomerDao(db);
    final productDao = ProductDao(db);

    final customer = await customerDao.getCustomerById(widget.invoice.customerId);

    // join invoice_items + products
    final rawItems = await db.rawQuery('''
      SELECT ii.qty, ii.price, p.name as product_name
      FROM invoice_items ii
      JOIN products p ON ii.product_id = p.id
      WHERE ii.invoice_id = ?
    ''', [widget.invoice.id]);

    setState(() {
      _customer = customer;
      _items = rawItems;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Order Details"),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () {
              // todo: implement pdf or print later
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Invoice ID: ${widget.invoice.id}",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text("Customer: ${_customer?.name ?? 'Unknown'}"),
              Text("Date: ${widget.invoice.date}"),
              const SizedBox(height: 10),

              const Divider(),

              Text("Total: ${widget.invoice.total.toStringAsFixed(2)}"),
              Text("Discount: ${widget.invoice.discount.toStringAsFixed(2)}"),
              Text("Paid: ${widget.invoice.paid.toStringAsFixed(2)}"),
              Text(
                "Pending: ${widget.invoice.pending.toStringAsFixed(2)}",
                style: const TextStyle(color: Colors.red),
              ),

              const SizedBox(height: 20),
              const Text("Items:",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),

              const SizedBox(height: 10),
              ..._items.map((item) => Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      title: Text(item['product_name']),
                      subtitle: Text(
                          "Qty: ${item['qty']} × ${item['price'].toStringAsFixed(2)}"),
                      trailing: Text(
                        (item['qty'] * item['price']).toStringAsFixed(2),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
