import '../../core/database/database_helper.dart';
import '../models/todo.dart';

class TodoRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<List<Todo>> getAll() => _db.getAllTodos();

  Future<List<Todo>> search(String query) => _db.searchTodos(query);

  Future<int> insert(Todo todo) => _db.insertTodo(todo);

  Future<int> update(Todo todo) => _db.updateTodo(todo);

  Future<int> delete(int id) => _db.deleteTodo(id);
}
