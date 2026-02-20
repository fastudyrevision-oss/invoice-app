import 'package:flutter/material.dart';
import '../../repositories/supplier_repo.dart';
import '../../models/supplier_company.dart';
import 'package:uuid/uuid.dart';
import '../../services/supplier_export_service.dart';
import '../../services/logger_service.dart';

class SupplierCompanyFrame extends StatefulWidget {
  final SupplierRepository repo;
  final Function(SupplierCompany)? onViewSuppliers;
  const SupplierCompanyFrame({
    super.key,
    required this.repo,
    this.onViewSuppliers,
  });

  @override
  State<SupplierCompanyFrame> createState() => _SupplierCompanyFrameState();
}

class _SupplierCompanyFrameState extends State<SupplierCompanyFrame> {
  late Future<List<SupplierCompany>> _companiesFuture;
  bool _showDeleted = false; // toggle to show deleted companies
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  Map<String, int> _supplierCounts = {};
  Map<String, List<String>> _supplierNamesMap = {};
  final SupplierExportService _exportService = SupplierExportService();
  int _totalCompanies = 0;
  int _totalSuppliers = 0;

  @override
  void initState() {
    super.initState();
    _loadCompanies();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadCompanies() async {
    setState(() {
      _companiesFuture = widget.repo.getAllCompanies(showDeleted: _showDeleted);
    });

    // Load supplier counts
    // Load supplier names
    final namesMap = await widget.repo.getSupplierNamesByCompany(
      includeDeleted: false,
    );
    final companies = await _companiesFuture;

    // Derive counts from namesMap
    final Map<String, int> counts = namesMap.map(
      (key, value) => MapEntry(key, value.length),
    );

    setState(() {
      _supplierCounts = counts;
      _supplierNamesMap = namesMap;
      _totalCompanies = companies.where((c) => c.deleted == 0).length;
      _totalSuppliers = counts.values.fold(0, (sum, count) => sum + count);
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

  Future<void> _exportCompanies(String type) async {
    final companies = await _companiesFuture;
    if (companies.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No companies to export')));
      }
      return;
    }

    try {
      if (type == 'share') {
        await _exportService.exportCompaniesToPDF(companies, _supplierNamesMap);
      } else if (type == 'print') {
        await _exportService.printCompaniesList(companies, _supplierNamesMap);
      } else if (type == 'save') {
        final file = await _exportService.saveCompaniesPdf(
          companies,
          _supplierNamesMap,
        );
        if (mounted && file != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Saved: ${file.path}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      logger.error('SupplierCompanyFrame', 'Export error', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Export error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<SupplierCompany> _filterCompanies(List<SupplierCompany> companies) {
    if (_searchQuery.isEmpty) return companies;
    return companies.where((c) {
      final query = _searchQuery.toLowerCase();
      return c.name.toLowerCase().contains(query) ||
          (c.phone?.toLowerCase().contains(query) ?? false) ||
          (c.address?.toLowerCase().contains(query) ?? false);
    }).toList();
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
          PopupMenuButton<String>(
            icon: const Icon(Icons.picture_as_pdf, size: 28),
            tooltip: "Export Companies",
            onSelected: _exportCompanies,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share, size: 18),
                    SizedBox(width: 8),
                    Text('Share PDF'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'print',
                child: Row(
                  children: [
                    Icon(Icons.print, size: 18),
                    SizedBox(width: 8),
                    Text('Print Report'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'save',
                child: Row(
                  children: [
                    Icon(Icons.save_alt, size: 18),
                    SizedBox(width: 8),
                    Text('Save PDF'),
                  ],
                ),
              ),
            ],
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
          final allCompanies = snapshot.data ?? [];
          final list = _filterCompanies(allCompanies);

          if (allCompanies.isEmpty) {
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

          return Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search companies...',
                    prefixIcon: const Icon(Icons.search, color: Colors.blue),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                ),
              ),

              // Statistics Cards
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Total Companies',
                        _totalCompanies.toString(),
                        Icons.business,
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'Total Suppliers',
                        _totalSuppliers.toString(),
                        Icons.people,
                        Colors.green,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Company List
              Expanded(
                child: list.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty
                                  ? "No companies found"
                                  : "No results for '$_searchQuery'",
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: list.length,
                        itemBuilder: (_, i) {
                          final c = list[i];
                          final isDeleted = c.deleted == 1;
                          final supplierCount = _supplierCounts[c.id] ?? 0;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white,
                                  isDeleted
                                      ? Colors.grey.withValues(alpha: 0.1)
                                      : Colors.blue.withValues(alpha: 0.05),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: (isDeleted ? Colors.grey : Colors.blue)
                                      .withValues(alpha: 0.2),
                                  spreadRadius: 1,
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                              border: Border.all(
                                color: (isDeleted ? Colors.grey : Colors.blue)
                                    .withValues(alpha: 0.3),
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Header Row
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
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
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.indigo
                                                        .withValues(alpha: 0.3),
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
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          c.name,
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 18,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: Colors
                                                                    .black87,
                                                              ),
                                                        ),
                                                      ),
                                                      if (supplierCount > 0)
                                                        Container(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 8,
                                                                vertical: 4,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            gradient:
                                                                LinearGradient(
                                                                  colors: [
                                                                    Colors
                                                                        .green
                                                                        .shade400,
                                                                    Colors
                                                                        .green
                                                                        .shade600,
                                                                  ],
                                                                ),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  12,
                                                                ),
                                                          ),
                                                          child: Text(
                                                            '$supplierCount',
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 12,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color: Colors
                                                                      .white,
                                                                ),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 8),
                                                  // Display Supplier Names
                                                  if (_supplierNamesMap[c.id]
                                                          ?.isNotEmpty ??
                                                      false)
                                                    Wrap(
                                                      spacing: 4,
                                                      runSpacing: 4,
                                                      children: _supplierNamesMap[c.id]!
                                                          .map(
                                                            (name) => Container(
                                                              padding:
                                                                  const EdgeInsets.symmetric(
                                                                    horizontal:
                                                                        8,
                                                                    vertical: 2,
                                                                  ),
                                                              decoration: BoxDecoration(
                                                                color: Colors
                                                                    .blue
                                                                    .shade50,
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      6,
                                                                    ),
                                                                border: Border.all(
                                                                  color: Colors
                                                                      .blue
                                                                      .shade100,
                                                                ),
                                                              ),
                                                              child: Text(
                                                                name,
                                                                style: TextStyle(
                                                                  fontSize: 11,
                                                                  color: Colors
                                                                      .blue
                                                                      .shade800,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500,
                                                                ),
                                                              ),
                                                            ),
                                                          )
                                                          .toList(),
                                                    )
                                                  else
                                                    Text(
                                                      "No suppliers",
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors
                                                            .grey
                                                            .shade500,
                                                        fontStyle:
                                                            FontStyle.italic,
                                                      ),
                                                    ),
                                                  if (c.phone?.isNotEmpty ??
                                                      false)
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                            top: 4,
                                                          ),
                                                      child: Row(
                                                        children: [
                                                          Icon(
                                                            Icons.phone,
                                                            size: 14,
                                                            color: Colors
                                                                .green
                                                                .shade700,
                                                          ),
                                                          const SizedBox(
                                                            width: 4,
                                                          ),
                                                          Text(
                                                            c.phone!,
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              color: Colors
                                                                  .grey
                                                                  .shade700,
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
                                                      Icons.list_alt,
                                                      color: Colors.indigo,
                                                    ),
                                                    onPressed: () => widget
                                                        .onViewSuppliers
                                                        ?.call(c),
                                                    tooltip: 'View Suppliers',
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(
                                                      Icons.edit_outlined,
                                                      color: Colors.blue,
                                                    ),
                                                    onPressed: () =>
                                                        _addOrEditCompany(c),
                                                    tooltip: 'Edit',
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(
                                                      Icons.delete_outline,
                                                      color: Colors.red,
                                                    ),
                                                    onPressed: () =>
                                                        _deleteCompany(c),
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
                                                onPressed: () =>
                                                    _restoreCompany(c),
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
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: Colors.amber.shade200,
                                              ),
                                            ),
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
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
                                                      color:
                                                          Colors.amber.shade900,
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
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.1), color.withValues(alpha: 0.05)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}
