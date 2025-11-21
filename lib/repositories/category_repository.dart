import '../dao/category_dao.dart';
import '../models/category.dart';

class CategoryRepository {
  final CategoryDao _dao;

  CategoryRepository(this._dao);

  static Future<CategoryRepository> create() async {
    final dao = await CategoryDao.create();
    return CategoryRepository(dao);
  }

  Future<List<Category>> getAllCategories() => _dao.getAll();
  Future<List<Category>> getAllCategoriesPaged(int offset, int limit) => _dao.getAllPaged(offset, limit);

  Future<Category?> getCategoryById(String id) => _dao.getById(id);

  Future<int> addCategory(Category c) => _dao.insert(c);

  Future<int> updateCategory(Category c) => _dao.update(c);

  Future<int> deleteCategory(String id) => _dao.delete(id);
}
