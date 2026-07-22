import '../../core/database/database_helper.dart';
import '../models/todo.dart';
import '../models/subtask.dart';

class TodoRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<List<Todo>> getAll() => _db.getAllTodos();

  Future<List<Todo>> search(String query) => _db.searchTodos(query);

  Future<int> insert(Todo todo) => _db.insertTodo(todo);

  Future<int> update(Todo todo) => _db.updateTodo(todo);

  Future<int> delete(int id) => _db.deleteTodo(id);

  // Subtask operations
  Future<List<Subtask>> getSubtasks(int todoId) => _db.getSubtasksForTodo(todoId);

  Future<void> insertSubtask(Subtask subtask, int todoId) => _db.insertSubtask(subtask, todoId);

  Future<void> updateSubtask(Subtask subtask) => _db.updateSubtask(subtask);

  Future<void> deleteSubtask(String id) => _db.deleteSubtask(id);

  Future<void> reorderSubtasks(List<Subtask> subtasks) => _db.reorderSubtasks(subtasks);
}
