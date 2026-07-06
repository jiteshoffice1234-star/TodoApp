import 'package:flutter/foundation.dart';
import '../data/models/todo.dart';
import '../data/models/category.dart';
import '../data/repositories/todo_repository.dart';
import '../data/repositories/category_repository.dart';

enum TodoFilter { all, pending, done }
enum TodoSort { dateCreated, dateUpdated, dueDate, priority, alphabetical }
enum ViewMode { list, grid }

class TodoProvider extends ChangeNotifier {
  final TodoRepository _todoRepo = TodoRepository();
  final CategoryRepository _categoryRepo = CategoryRepository();

  List<Todo> _todos = [];
  List<TodoCategory> _categories = [];
  TodoFilter _filter = TodoFilter.all;
  TodoSort _sort = TodoSort.dateCreated;
  ViewMode _viewMode = ViewMode.list;
  String _searchQuery = '';
  String _selectedTag = '';
  bool _isLoading = false;

  List<Todo> get todos => _filteredTodos;
  List<TodoCategory> get categories => _categories;
  TodoFilter get filter => _filter;
  TodoSort get sort => _sort;
  ViewMode get viewMode => _viewMode;
  String get searchQuery => _searchQuery;
  String get selectedTag => _selectedTag;
  bool get isLoading => _isLoading;

  int get pendingCount => _todos.where((t) => !t.isDone).length;
  int get doneCount => _todos.where((t) => t.isDone).length;
  int get allCount => _todos.length;

  List<String> get allTags {
    final tags = <String>{};
    for (final todo in _todos) {
      tags.addAll(todo.tags);
    }
    return tags.toList()..sort();
  }

  Map<String, int> get categoryStats {
    final stats = <String, int>{};
    for (final todo in _todos) {
      final catName = getCategoryById(todo.categoryId)?.name ?? 'Uncategorized';
      stats[catName] = (stats[catName] ?? 0) + 1;
    }
    return stats;
  }

  Map<String, int> get completionStats {
    final stats = <String, int>{
      'completed': doneCount,
      'pending': pendingCount,
    };
    return stats;
  }

  int get currentStreak {
    final now = DateTime.now();
    int streak = 0;
    DateTime checkDate = DateTime(now.year, now.month, now.day);
    
    while (true) {
      final dayTodos = _todos.where((t) =>
          t.isDone &&
          t.updatedAt.year == checkDate.year &&
          t.updatedAt.month == checkDate.month &&
          t.updatedAt.day == checkDate.day);
      
      if (dayTodos.isEmpty && checkDate != DateTime(now.year, now.month, now.day)) {
        break;
      }
      
      if (dayTodos.isNotEmpty) {
        streak++;
      } else if (checkDate == DateTime(now.year, now.month, now.day)) {
        // Today doesn't count yet
      } else {
        break;
      }
      
      checkDate = checkDate.subtract(const Duration(days: 1));
    }
    
    return streak;
  }

  List<Todo> get _filteredTodos {
    List<Todo> result = List.from(_todos);

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result
          .where((t) =>
              t.title.toLowerCase().contains(q) ||
              t.description.toLowerCase().contains(q) ||
              t.tags.any((tag) => tag.toLowerCase().contains(q)))
          .toList();
    }

    if (_selectedTag.isNotEmpty) {
      result = result.where((t) => t.tags.contains(_selectedTag)).toList();
    }

    switch (_filter) {
      case TodoFilter.pending:
        result = result.where((t) => !t.isDone).toList();
      case TodoFilter.done:
        result = result.where((t) => t.isDone).toList();
      case TodoFilter.all:
        break;
    }

    switch (_sort) {
      case TodoSort.dateCreated:
        result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case TodoSort.dateUpdated:
        result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      case TodoSort.dueDate:
        result.sort((a, b) {
          if (a.dueDate == null && b.dueDate == null) return 0;
          if (a.dueDate == null) return 1;
          if (b.dueDate == null) return -1;
          return a.dueDate!.compareTo(b.dueDate!);
        });
      case TodoSort.priority:
        final priorityIndex = {'high': 0, 'medium': 1, 'low': 2};
        result.sort((a, b) {
          final piA = priorityIndex[a.priority] ?? 1;
          final piB = priorityIndex[b.priority] ?? 1;
          return piA.compareTo(piB);
        });
      case TodoSort.alphabetical:
        result.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    }

    // Always show incomplete first unless filtering by done
    if (_filter != TodoFilter.done) {
      result.sort((a, b) {
        if (a.isDone != b.isDone) return a.isDone ? 1 : -1;
        return 0;
      });
    }

    return result;
  }

  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();
    _todos = await _todoRepo.getAll();
    _categories = await _categoryRepo.getAll();
    _isLoading = false;
    notifyListeners();
  }

  void setFilter(TodoFilter filter) {
    _filter = filter;
    notifyListeners();
  }

  void setSort(TodoSort sort) {
    _sort = sort;
    notifyListeners();
  }

  void setViewMode(ViewMode mode) {
    _viewMode = mode;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSelectedTag(String tag) {
    _selectedTag = tag;
    notifyListeners();
  }

  Future<void> toggleTodo(int id) async {
    final index = _todos.indexWhere((t) => t.id == id);
    if (index == -1) return;
    final todo = _todos[index];
    final updated = todo.copyWith(isDone: !todo.isDone);
    await _todoRepo.update(updated);
    _todos[index] = updated;
    notifyListeners();
  }

  Future<void> saveTodo(Todo todo) async {
    if (todo.id == null) {
      final id = await _todoRepo.insert(todo);
      _todos.add(todo.copyWith(id: id));
    } else {
      await _todoRepo.update(todo);
      final index = _todos.indexWhere((t) => t.id == todo.id);
      if (index != -1) _todos[index] = todo;
    }
    notifyListeners();
  }

  Future<void> deleteTodo(int id) async {
    await _todoRepo.delete(id);
    _todos.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  Future<void> deleteCompleted() async {
    final completed = _todos.where((t) => t.isDone).toList();
    for (final todo in completed) {
      if (todo.id != null) await _todoRepo.delete(todo.id!);
    }
    _todos.removeWhere((t) => t.isDone);
    notifyListeners();
  }

  Future<void> addCategory(TodoCategory category) async {
    final id = await _categoryRepo.insert(category);
    _categories.add(category.copyWith(id: id));
    notifyListeners();
  }

  Future<void> updateCategory(TodoCategory category) async {
    if (category.id != null) {
      await _categoryRepo.update(category);
      final index = _categories.indexWhere((c) => c.id == category.id);
      if (index != -1) _categories[index] = category;
      notifyListeners();
    }
  }

  Future<void> deleteCategory(int id) async {
    await _categoryRepo.delete(id);
    _categories.removeWhere((c) => c.id == id);
    _todos = _todos.map((t) {
      if (t.categoryId == id) return t.copyWith(categoryId: null);
      return t;
    }).toList();
    notifyListeners();
  }

  TodoCategory? getCategoryById(int? id) {
    if (id == null) return null;
    try {
      return _categories.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  List<Todo> getTodosForExport() {
    return List.from(_todos);
  }

  Future<void> importTodos(List<Todo> todos) async {
    for (final todo in todos) {
      await _todoRepo.insert(todo);
    }
    await loadData();
  }
}
