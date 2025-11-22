import 'package:flutter/material.dart';
import '../../repositories/supplier_repo.dart';
import '../../models/supplier_company.dart';
import 'package:uuid/uuid.dart';

class SupplierCompanyFrame extends StatefulWidget {
  final SupplierRepository repo;
  const SupplierCompanyFrame({super.key, required this.repo});

  @override
  State<SupplierCompanyFrame> createState() => _SupplierCompanyFrameState();
}

class _SupplierCompanyFrameState extends State<SupplierCompanyFrame> {
  late Future<List<SupplierCompany>> _companiesFuture;
  bool _showDeleted = false; // toggle to show deleted companies

  @override
  void initState() {
    super.initState();
    _loadCompanies();
  }

  void _loadCompanies() {
    setState(() {
      _companiesFuture = widget.repo.getAllCompanies(showDeleted: _showDeleted);
    });
  }

  Future<void> _addOrEditCompany([SupplierCompany? company]) async {
    final nameCtrl = TextEditingController(text: company?.name ?? '');
    final addressCtrl = TextEditingController(text: company?.address ?? '');
    final phoneCtrl = TextEditingController(text: company?.phone ?? '');
    final notesCtrl = TextEditingController(text: company?.notes ?? '');

    final result = await showDialog<SupplierCompany>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(company == null ? "Add Company" : "Edit Company"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: "Name"),
              ),
              TextField(
                controller: addressCtrl,
                decoration: const InputDecoration(labelText: "Address"),
              ),
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: "Phone"),
              ),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(labelText: "Notes"),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              final newCompany = SupplierCompany(
                id: company?.id ?? const Uuid().v4(),
                name: nameCtrl.text.trim(),
                address: addressCtrl.text.trim().isEmpty
                    ? null
                    : addressCtrl.text.trim(),
                phone: phoneCtrl.text.trim().isEmpty
                    ? null
                    : phoneCtrl.text.trim(),
                notes: notesCtrl.text.trim().isEmpty
                    ? null
                    : notesCtrl.text.trim(),
                createdAt:
                    company?.createdAt ?? DateTime.now().toIso8601String(),
                updatedAt: DateTime.now().toIso8601String(),
                deleted: company?.deleted ?? 0,
              );
              Navigator.pop(ctx, newCompany);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );

    if (result != null) {
      if (company == null) {
        await widget.repo.insertCompany(result);
      } else {
        await widget.repo.updateCompany(result);
      }
      _loadCompanies();
    }
  }

  Future<void> _deleteCompany(SupplierCompany company) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Company"),
        content: Text("Are you sure you want to delete '${company.name}'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.repo.deleteCompany(company.id); // soft delete
      _loadCompanies();
    }
  }

  Future<void> _restoreCompany(SupplierCompany company) async {
    await widget.repo.restoreCompany(company.id);
    _loadCompanies();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Companies"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_business),
            tooltip: "Add Company",
            onPressed: () => _addOrEditCompany(),
          ),
          IconButton(
            icon: Icon(_showDeleted ? Icons.visibility_off : Icons.visibility),
            tooltip: _showDeleted ? "Hide Deleted" : "Show Deleted",
            onPressed: () {
              setState(() {
                _showDeleted = !_showDeleted;
                _loadCompanies();
              });
            },
          ),
        ],
      ),
      body: FutureBuilder<List<SupplierCompany>>(
        future: _companiesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          final list = snapshot.data ?? [];
          if (list.isEmpty) {
            return const Center(child: Text("No companies found"));
          }

          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (_, i) {
              final c = list[i];
              final isDeleted = c.deleted == 1;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                color: isDeleted ? Colors.grey[300] : null,
                child: ListTile(
                  title: Text(c.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (c.phone?.isNotEmpty ?? false) Text("📞 ${c.phone}"),
                      if (c.address?.isNotEmpty ?? false)
                        Text("📍 ${c.address}"),
                      if (c.notes?.isNotEmpty ?? false) Text("📝 ${c.notes}"),
                      if (isDeleted)
                        const Text(
                          "Deleted",
                          style: TextStyle(color: Colors.red),
                        ),
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        _addOrEditCompany(c);
                      } else if (value == 'delete') {
                        _deleteCompany(c);
                      } else if (value == 'restore') {
                        _restoreCompany(c);
                      }
                    },
                    itemBuilder: (ctx) => [
                      if (!isDeleted)
                        const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      if (!isDeleted)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete'),
                        ),
                      if (isDeleted)
                        const PopupMenuItem(
                          value: 'restore',
                          child: Text('Restore'),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
