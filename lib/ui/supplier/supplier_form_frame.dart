import 'package:flutter/material.dart';
import '../../repositories/supplier_repo.dart';
import '../../models/supplier.dart';
import '../../models/supplier_company.dart';
import 'package:uuid/uuid.dart';
import 'package:dropdown_search/dropdown_search.dart';

class SupplierFormFrame extends StatefulWidget {
  final SupplierRepository repo;
  final Supplier? supplier; // null = create, not null = edit

  const SupplierFormFrame({super.key, required this.repo, this.supplier});

  @override
  State<SupplierFormFrame> createState() => _SupplierFormFrameState();
}

class _SupplierFormFrameState extends State<SupplierFormFrame> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _creditCtrl = TextEditingController();
  String? _companyId;

  List<SupplierCompany> _companies = [];
  final SupplierCompany allCompaniesOption = SupplierCompany(
    id: '-1',
    name: 'Select Company', // or any default
    createdAt: DateTime.now().toIso8601String(),
    updatedAt: DateTime.now().toIso8601String(),
    // fill other fields if needed
  );

  @override
  void initState() {
    super.initState();
    _loadCompanies();

    if (widget.supplier != null) {
      final s = widget.supplier!;
      _nameCtrl.text = s.name;
      _phoneCtrl.text = s.phone ?? "";
      _addressCtrl.text = s.address ?? "";
      _contactCtrl.text = s.contactPerson ?? "";
      _creditCtrl.text = s.creditLimit.toString();
      _companyId = s.companyId;
    }
  }

  void _loadCompanies() async {
    final list = await widget.repo.getAllCompanies(
      showDeleted: false,
    ); // only active companies
    if (mounted) setState(() => _companies = list);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final now = DateTime.now().toIso8601String();
    final supplier = Supplier(
      id: widget.supplier?.id ?? const Uuid().v4(),
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      address: _addressCtrl.text.trim().isEmpty
          ? null
          : _addressCtrl.text.trim(),
      contactPerson: _contactCtrl.text.trim().isEmpty
          ? null
          : _contactCtrl.text.trim(),
      companyId: _companyId,
      pendingAmount: widget.supplier?.pendingAmount ?? 0.0,
      creditLimit: double.tryParse(_creditCtrl.text.trim()) ?? 0.0,
      createdAt: widget.supplier?.createdAt ?? now,
      updatedAt: now,
      deleted: widget.supplier?.deleted ?? 0, // include deleted field
    );

    if (widget.supplier == null) {
      await widget.repo.insertSupplier(supplier);
    } else {
      await widget.repo.updateSupplier(supplier);
    }

    if (mounted) {
      Navigator.pop(context, true); // triggers refresh in SupplierFrame
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _contactCtrl.dispose();
    _creditCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.supplier == null ? "Add Supplier" : "Edit Supplier"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: "Name"),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              TextFormField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(labelText: "Phone"),
              ),
              TextFormField(
                controller: _addressCtrl,
                decoration: const InputDecoration(labelText: "Address"),
              ),
              TextFormField(
                controller: _contactCtrl,
                decoration: const InputDecoration(labelText: "Contact Person"),
              ),
              TextFormField(
                controller: _creditCtrl,
                decoration: const InputDecoration(labelText: "Credit Limit"),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              DropdownSearch<SupplierCompany>(
                // or Mode.BOTTOM_SHEET / Mode.DIALOG
                items: (items, props) => _companies,
                itemAsString: (SupplierCompany c) => c.name,
                onChanged: (c) {
                  if (c != null) {
                    setState(() => _companyId = c.id);
                  } else {
                    setState(() => _companyId = null);
                  }
                },
                compareFn: (SupplierCompany a, SupplierCompany b) =>
                    a.id == b.id,
                selectedItem: _companies.firstWhere(
                  (c) => c.id == _companyId,
                  orElse: () => allCompaniesOption, // return null if not found
                ),

                popupProps: PopupProps.menu(
                  showSearchBox: true,
                  fit: FlexFit.loose,
                ), // lets user type to search
                decoratorProps: DropDownDecoratorProps(
                  decoration: InputDecoration(
                    labelText: "Company",
                    border: OutlineInputBorder(),
                  ),
                ),
              ),

              const SizedBox(height: 24),
              ElevatedButton(onPressed: _save, child: const Text("Save")),
            ],
          ),
        ),
      ),
    );
  }
}
