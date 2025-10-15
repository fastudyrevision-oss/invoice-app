import 'package:flutter/material.dart';
import '../../repositories/supplier_repo.dart';
import '../../repositories/supplier_payment_repo.dart';
import '../../models/supplier.dart';
import 'supplier_detail_frame.dart';
import 'supplier_form_frame.dart';
import 'supplier_company_frame.dart';

class SupplierFrame extends StatefulWidget {
  final SupplierRepository repo;
  final SupplierPaymentRepository repo2;
  const SupplierFrame({super.key, required this.repo  , required this.repo2});

  @override
  State<SupplierFrame> createState() => _SupplierFrameState();
}
class _SupplierFrameState extends State<SupplierFrame> {
  late Future<List<Supplier>> _suppliersFuture;
  bool _showDeleted = false; // toggle to show deleted suppliers
  String _searchKeyword = "";

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
  }

  void _loadSuppliers() {
    setState(() {
      _suppliersFuture = widget.repo.getAllSuppliers(showDeleted: _showDeleted).then((list) {
        if (_searchKeyword.isNotEmpty) {
          return list.where((s) =>
              s.name.toLowerCase().contains(_searchKeyword.toLowerCase()) ||
              (s.phone?.toLowerCase().contains(_searchKeyword.toLowerCase()) ?? false)
          ).toList();
        }
        return list;
      });
    });
  }

  Future<void> _editSupplier(Supplier supplier) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SupplierFormFrame(repo: widget.repo, supplier: supplier),
      ),
    );
    if (result == true) _loadSuppliers();
  }

  Future<void> _deleteSupplier(Supplier supplier) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Supplier"),
        content: Text("Are you sure you want to delete '${supplier.name}'?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete")),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.repo.deleteSupplier(supplier.id);
      _loadSuppliers();
    }
  }

  Future<void> _restoreSupplier(Supplier supplier) async {
    await widget.repo.restoreSupplier(supplier.id);
    _loadSuppliers();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Suppliers & Companies"),
          bottom: TabBar(
            tabs: [
              Tab(icon: const Icon(Icons.person), text: "Suppliers"),
              Tab(icon: const Icon(Icons.business), text: "Companies"),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(_showDeleted ? Icons.visibility_off : Icons.visibility),
              tooltip: _showDeleted ? "Hide Deleted" : "Show Deleted",
              onPressed: () {
                setState(() {
                  _showDeleted = !_showDeleted;
                  _loadSuppliers();
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () async {
                final keyword = await showDialog<String>(
                  context: context,
                  builder: (ctx) {
                    final ctrl = TextEditingController(text: _searchKeyword);
                    return AlertDialog(
                      title: const Text("Search Supplier"),
                      content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: "Name or Phone")),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                        TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text("Search")),
                      ],
                    );
                  },
                );
                if (keyword != null) {
                  _searchKeyword = keyword;
                  _loadSuppliers();
                }
              },
            ),
          ],
        ),
        body: TabBarView(
          children: [
            // --- SUPPLIERS TAB ---
            FutureBuilder<List<Supplier>>(
              future: _suppliersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text("No suppliers found."));
                }

                final suppliers = snapshot.data!;
                return ListView.builder(
                  itemCount: suppliers.length,
                  itemBuilder: (context, index) {
                    final supplier = suppliers[index];
                    final isDeleted = (supplier as dynamic).deleted == 1;
                    return Card(
                      color: isDeleted ? Colors.grey[300] : null,
                      child: ListTile(
                        title: Text(supplier.name),
                        subtitle: Text(supplier.phone ?? "No phone"),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "Pending: ${supplier.pendingAmount.toStringAsFixed(2)}",
                              style: const TextStyle(color: Colors.red),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _editSupplier(supplier);
                                } else if (value == 'delete') _deleteSupplier(supplier);
                                else if (value == 'restore') _restoreSupplier(supplier);
                              },
                              itemBuilder: (ctx) => [
                                if (!isDeleted) const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                if (!isDeleted) const PopupMenuItem(value: 'delete', child: Text('Delete')),
                                if (isDeleted) const PopupMenuItem(value: 'restore', child: Text('Restore')),
                              ],
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SupplierDetailFrame(repo: widget.repo,repo2:widget.repo2, supplier: supplier),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
            // --- COMPANIES TAB ---
            SupplierCompanyFrame(repo: widget.repo),
          ],
        ),
        floatingActionButton: Builder(
          builder: (context) {
            final tabIndex = DefaultTabController.of(context).index;
            if (tabIndex == 0) {
              return FloatingActionButton(
                heroTag: null,
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => SupplierFormFrame(repo: widget.repo)),
                  );
                  if (result == true) _loadSuppliers();
                },
                child: const Icon(Icons.person_add),
              );
            } else {
              return const SizedBox.shrink();
            }
          },
        ),
      ),
    );
  }
}
