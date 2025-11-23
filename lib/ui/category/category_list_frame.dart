import 'package:flutter/material.dart';
import '../../dao/category_dao.dart';
import '../../models/category.dart';
import '../../repositories/category_repository.dart';
import 'category_form_screen.dart';

class CategoryListFrame extends StatefulWidget {
  const CategoryListFrame({super.key});

  @override
  _CategoryListFrameState createState() => _CategoryListFrameState();
}

class _CategoryListFrameState extends State<CategoryListFrame> {
  final TextEditingController _searchController = TextEditingController();
  final List<Category> _categories = [];
  bool _loading = false;
  bool _loadingMore = false;
  bool _showDeleted = false;
  SortMode _sortMode = SortMode.nameAsc;
  late CategoryRepository _repo;

  // Lazy loading variables
  static const int _pageSize = 10;
  int _currentOffset = 0;
  bool _hasMoreData = true;

  @override
  void initState() {
    super.initState();
    _initRepoAndLoad();
    _searchController.addListener(_applyFilters);
  }

  Future<void> _initRepoAndLoad() async {
    _repo = await CategoryRepository.create();
    await _refreshCategories();
  }

  Future<void> _refreshCategories() async {
    setState(() => _loading = true);
    _categories.clear();
    _currentOffset = 0;
    _hasMoreData = true;
    await _loadNextPage();
    setState(() => _loading = false);
  }

  Future<void> _loadNextPage() async {
    if (_loadingMore || !_hasMoreData) return;

    setState(() => _loadingMore = true);

    final dao = await CategoryDao.create();
    final page = await dao.getAllPaged(
      _currentOffset,
      _pageSize,
      includeDeleted: _showDeleted,
    );

    if (page.length < _pageSize) _hasMoreData = false;
    _currentOffset += page.length;
    _categories.addAll(page);

    _applyFilters(); // filtering & sorting on loaded data

    setState(() => _loadingMore = false);
  }

  void _applyFilters() {
    final q = _searchController.text.toLowerCase().trim();
    List<Category> filtered = _categories.where((c) {
      if (q.isEmpty) return true;
      return c.name.toLowerCase().contains(q) ||
          (c.slug ?? '').toLowerCase().contains(q) ||
          (c.description ?? '').toLowerCase().contains(q);
    }).toList();

    filtered.sort((a, b) {
      switch (_sortMode) {
        case SortMode.nameAsc:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case SortMode.nameDesc:
          return b.name.toLowerCase().compareTo(a.name.toLowerCase());
        case SortMode.orderAsc:
          return a.sortOrder.compareTo(b.sortOrder);
        case SortMode.orderDesc:
          return b.sortOrder.compareTo(a.sortOrder);
        case SortMode.newest:
          return b.createdAt.compareTo(a.createdAt);
      }
    });

    _filteredCategories = filtered;
  }

  List<Category> _filteredCategories = [];

  Future<void> _openForm({Category? category}) async {
    final result = await Navigator.of(context).push<Category?>(
      MaterialPageRoute(builder: (_) => CategoryFormScreen(category: category)),
    );
    if (result != null) {
      await _refreshCategories();
    }
  }

  Future<void> _confirmDelete(Category c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text('Mark "${c.name}" as deleted?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _repo.deleteCategory(c.id);
      await _refreshCategories();
    }
  }

  Future<void> _restoreCategory(Category c) async {
    final restored = c.copyWith(
      isDeleted: false,
      updatedAt: DateTime.now().toIso8601String(),
    );
    await _repo.updateCategory(restored);
    await _refreshCategories();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildList() {
    if (_loading && _categories.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_filteredCategories.isEmpty) {
      return const Center(child: Text('No categories found'));
    }

    return ListView.builder(
      itemCount: _filteredCategories.length + (_hasMoreData ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _filteredCategories.length) {
          // Trigger next page load
          // Schedule lazy load after the current frame
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _loadNextPage();
          });
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final c = _filteredCategories[index];
        return ListTile(
          leading: c.icon != null
              ? CircleAvatar(child: Text(c.name.substring(0, 1)))
              : null,
          title: Text(c.name),
          subtitle: Text(
            'Order: ${c.sortOrder} • ${c.isActive ? "Active" : "Inactive"}${c.isDeleted ? " • Deleted" : ""}',
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: c.isDeleted
                ? [
                    IconButton(
                      icon: const Icon(Icons.restore, color: Colors.green),
                      onPressed: () => _restoreCategory(c),
                      tooltip: 'Restore',
                    ),
                  ]
                : [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _openForm(category: c),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _confirmDelete(c),
                    ),
                  ],
          ),
          onTap: () => _openForm(category: c),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshCategories,
            tooltip: 'Refresh',
          ),
          PopupMenuButton<SortMode>(
            onSelected: (m) {
              setState(() {
                _sortMode = m;
                _applyFilters();
              });
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: SortMode.nameAsc,
                child: Text('Name ↑'),
              ),
              const PopupMenuItem(
                value: SortMode.nameDesc,
                child: Text('Name ↓'),
              ),
              const PopupMenuItem(
                value: SortMode.orderAsc,
                child: Text('Sort Order ↑'),
              ),
              const PopupMenuItem(
                value: SortMode.orderDesc,
                child: Text('Sort Order ↓'),
              ),
              const PopupMenuItem(
                value: SortMode.newest,
                child: Text('Newest'),
              ),
            ],
            icon: const Icon(Icons.sort),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'toggle_deleted') {
                setState(() => _showDeleted = !_showDeleted);
                await _refreshCategories();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'toggle_deleted',
                child: Text(_showDeleted ? 'Hide deleted' : 'Show deleted'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search categories...',
              ),
            ),
          ),
          Expanded(child: _buildList()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        tooltip: 'Add Category',
        child: const Icon(Icons.add),
      ),
    );
  }
}

enum SortMode { nameAsc, nameDesc, orderAsc, orderDesc, newest }
