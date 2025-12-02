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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.category_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No categories found',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredCategories.length + (_hasMoreData ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _filteredCategories.length) {
          // Trigger next page load
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _loadNextPage();
          });
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final c = _filteredCategories[index];
        final isDeleted = c.isDeleted;
        final isActive = c.isActive;

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
                    : isActive
                        ? Colors.green.withOpacity(0.05)
                        : Colors.orange.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: (isDeleted
                        ? Colors.grey
                        : isActive
                            ? Colors.green
                            : Colors.orange)
                    .withOpacity(0.2),
                spreadRadius: 1,
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: (isDeleted
                      ? Colors.grey
                      : isActive
                          ? Colors.green
                          : Colors.orange)
                  .withOpacity(0.3),
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
                        colors: [Colors.grey.shade600, Colors.grey.shade400],
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.delete_outline, size: 16, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          "Deleted Category",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (!isActive)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.orange.shade600, Colors.orange.shade400],
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.pause_circle_outline, size: 16, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          "Inactive Category",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                InkWell(
                  onTap: () => _openForm(category: c),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Category Icon
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.purple.shade600,
                                Colors.purple.shade400,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.purple.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            c.icon != null ? Icons.category : Icons.label,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Category Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: Colors.blue.shade200,
                                      ),
                                    ),
                                    child: Text(
                                      "Order: ${c.sortOrder}",
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.blue.shade900,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (c.description?.isNotEmpty ?? false) ...[
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        c.description!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Actions
                        if (isDeleted)
                          IconButton(
                            icon: const Icon(
                              Icons.restore,
                              color: Colors.orange,
                            ),
                            onPressed: () => _restoreCategory(c),
                            tooltip: 'Restore',
                          )
                        else
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  color: Colors.blue,
                                ),
                                onPressed: () => _openForm(category: c),
                                tooltip: 'Edit',
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
                                onPressed: () => _confirmDelete(c),
                                tooltip: 'Delete',
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Categories'),
        elevation: 0,
        actions: [
          const SizedBox(width: 10),
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
          const SizedBox(width: 10),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).primaryColor.withOpacity(0.1),
                  Theme.of(context).primaryColor.withOpacity(0.05),
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Search categories...',
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: _buildList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        tooltip: 'Add Category',
        icon: const Icon(Icons.add),
        label: const Text('New Category'),
      ),
    );
  }
}

enum SortMode { nameAsc, nameDesc, orderAsc, orderDesc, newest }
