import '../../core/database/database_helper.dart';
import '../models/category.dart';

class CategoryRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<List<TodoCategory>> getAll() => _db.getAllCategories();

  Future<int> insert(TodoCategory category) => _db.insertCategory(category);

  Future<int> update(TodoCategory category) => _db.updateCategory(category);

  Future<int> delete(int id) => _db.deleteCategory(id);
}
