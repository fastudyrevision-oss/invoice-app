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

    final formKey = GlobalKey<FormState>();

    final result = await showDialog<SupplierCompany>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(company == null ? "Add Company" : "Edit Company"),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: "Name *"),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? "Required" : null,
                ),
                TextFormField(
                  controller: addressCtrl,
                  decoration: const InputDecoration(labelText: "Address"),
                ),
                TextFormField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(labelText: "Phone"),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      if (!RegExp(r'^[0-9+]+$').hasMatch(value)) {
                        return 'Invalid phone number';
                      }
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(labelText: "Notes"),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
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
              }
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
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Companies"),
        elevation: 0,
        actions: [
          const SizedBox(width: 10),
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
          IconButton(
            icon: const Icon(Icons.add_business, size: 28),
            tooltip: "Add Company",
            onPressed: () => _addOrEditCompany(),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: FutureBuilder<List<SupplierCompany>>(
        future: _companiesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text("Error: ${snapshot.error}"),
                ],
              ),
            );
          }
          final list = snapshot.data ?? [];
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.business_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "No companies found",
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (_, i) {
              final c = list[i];
              final isDeleted = c.deleted == 1;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white,
                      isDeleted
                          ? Colors.grey.withOpacity(0.1)
                          : Colors.blue.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: (isDeleted ? Colors.grey : Colors.blue)
                          .withOpacity(0.2),
                      spreadRadius: 1,
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: (isDeleted ? Colors.grey : Colors.blue).withOpacity(
                      0.3,
                    ),
                    width: 1.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Strip
                      if (isDeleted)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 12,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.grey.shade600,
                                Colors.grey.shade400,
                              ],
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.delete_outline,
                                size: 16,
                                color: Colors.white,
                              ),
                              SizedBox(width: 8),
                              Text(
                                "Deleted Company",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),

                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header Row
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Company Icon
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.indigo.shade600,
                                        Colors.indigo.shade400,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.indigo.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.business,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 16),

                                // Company Name
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        c.name,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      if (c.phone?.isNotEmpty ?? false)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 4,
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.phone,
                                                size: 14,
                                                color: Colors.green.shade700,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                c.phone!,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),

                                // Actions
                                if (!isDeleted)
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit_outlined,
                                          color: Colors.blue,
                                        ),
                                        onPressed: () => _addOrEditCompany(c),
                                        tooltip: 'Edit',
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: Colors.red,
                                        ),
                                        onPressed: () => _deleteCompany(c),
                                        tooltip: 'Delete',
                                      ),
                                    ],
                                  )
                                else
                                  IconButton(
                                    icon: const Icon(
                                      Icons.restore,
                                      color: Colors.orange,
                                    ),
                                    onPressed: () => _restoreCompany(c),
                                    tooltip: 'Restore',
                                  ),
                              ],
                            ),

                            if (c.address?.isNotEmpty ?? false) ...[
                              const SizedBox(height: 12),
                              const Divider(),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    size: 16,
                                    color: Colors.red.shade400,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      c.address!,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (c.notes?.isNotEmpty ?? false) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.amber.shade200,
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.note,
                                      size: 16,
                                      color: Colors.amber.shade700,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        c.notes!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.amber.shade900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
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
