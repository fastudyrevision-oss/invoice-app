// ...existing code...
import 'package:flutter/material.dart';
import '../../models/category.dart';
import '../../dao/category_dao.dart';
import '../../repositories/category_repository.dart';

class CategoryFormScreen extends StatefulWidget {
  final Category? category;
  const CategoryFormScreen({Key? key, this.category}) : super(key: key);

  @override
  _CategoryFormScreenState createState() => _CategoryFormScreenState();
}

class _CategoryFormScreenState extends State<CategoryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _slug = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _sortOrder = TextEditingController();
  bool _isActive = true;
  String? _parentId;
  List<Category> _parents = [];
  late CategoryRepository _repo;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _repo = await CategoryRepository.create();
    final dao = await CategoryDao.create();
    _parents = await dao.getAll(includeDeleted: false);
    if (widget.category != null) {
      final c = widget.category!;
      _name.text = c.name;
      _slug.text = c.slug ?? '';
      _description.text = c.description ?? '';
      _sortOrder.text = c.sortOrder.toString();
      _isActive = c.isActive;
      _parentId = c.parentId;
    }
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final now = DateTime.now().toIso8601String();
    final isNew = widget.category == null;
    final id =
        widget.category?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
    final category = Category(
      id: id,
      name: _name.text.trim(),
      slug: _slug.text.trim().isEmpty ? null : _slug.text.trim(),
      description: _description.text.trim().isEmpty
          ? null
          : _description.text.trim(),
      parentId: _parentId,
      isActive: _isActive,
      isDeleted: false,
      icon: null,
      color: null,
      sortOrder: int.tryParse(_sortOrder.text) ?? 0,
      createdAt: isNew ? now : widget.category!.createdAt,
      updatedAt: now,
    );

    if (isNew) {
      await _repo.addCategory(category);
    } else {
      await _repo.updateCategory(category);
    }

    Navigator.of(context).pop(category);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category == null ? 'New Category' : 'Edit Category'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(12.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(labelText: 'Name'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Name required'
                          : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _slug,
                      decoration: const InputDecoration(labelText: 'Slug'),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _description,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String?>(
                      value: _parentId,
                      items:
                          [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('No parent'),
                            ),
                          ] +
                          _parents
                              .where(
                                (p) =>
                                    widget.category == null ||
                                    p.id != widget.category!.id,
                              )
                              .map(
                                (p) => DropdownMenuItem(
                                  value: p.id,
                                  child: Text(p.name),
                                ),
                              )
                              .toList(),
                      onChanged: (v) => setState(() => _parentId = v),
                      decoration: const InputDecoration(labelText: 'Parent'),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _sortOrder,
                      decoration: const InputDecoration(
                        labelText: 'Sort order',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: const Text('Active'),
                      value: _isActive,
                      onChanged: (v) => setState(() => _isActive = v),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: _save, child: const Text('Save')),
                  ],
                ),
              ),
            ),
    );
  }
}

// ...existing code...
