import 'package:flutter/foundation.dart';
import '../data/models/todo.dart';
import '../data/models/category.dart';
import '../data/models/subtask.dart';
import '../data/models/recurring_config.dart';
import '../data/repositories/todo_repository.dart';
import '../data/repositories/category_repository.dart';
import '../core/database/database_helper.dart';
import '../core/services/notification_service.dart';
import '../core/services/natural_language_parser.dart';

enum TodoFilter { all, pending, done }
enum TodoSort { dateCreated, dateUpdated, dueDate, priority, alphabetical, sortOrder }
enum ViewMode { list, grid }

class TodoProvider extends ChangeNotifier {
  final TodoRepository _todoRepo = TodoRepository();
  final CategoryRepository _categoryRepo = CategoryRepository();

  List<Todo> _todos = [];
  List<TodoCategory> _categories = [];
  TodoFilter _filter = TodoFilter.all;
  TodoSort _sort = TodoSort.sortOrder;
  ViewMode _viewMode = ViewMode.list;
  String _searchQuery = '';
  String _selectedTag = '';
  bool _isLoading = false;
  
  // Multi-select
  bool _isMultiSelectMode = false;
  final Set<int> _selectedTodoIds = {};
  
  // Calendar
  DateTime _selectedCalendarDate = DateTime.now();

  List<Todo> get todos => _filteredTodos;
  List<TodoCategory> get categories => _categories;
  TodoFilter get filter => _filter;
  TodoSort get sort => _sort;
  ViewMode get viewMode => _viewMode;
  String get searchQuery => _searchQuery;
  String get selectedTag => _selectedTag;
  bool get isLoading => _isLoading;
  bool get isMultiSelectMode => _isMultiSelectMode;
  Set<int> get selectedTodoIds => _selectedTodoIds;
  DateTime get selectedCalendarDate => _selectedCalendarDate;

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

  List<Todo> getTodosForDate(DateTime date) {
    return _todos.where((t) {
      if (t.dueDate == null) return false;
      return t.dueDate!.year == date.year &&
          t.dueDate!.month == date.month &&
          t.dueDate!.day == date.day;
    }).toList();
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
      case TodoSort.sortOrder:
        result.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }

    // Always show incomplete first unless filtering by done
    if (_filter != TodoFilter.done && _sort != TodoSort.sortOrder) {
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

  void setSelectedCalendarDate(DateTime date) {
    _selectedCalendarDate = date;
    notifyListeners();
  }

  // Multi-select
  void toggleMultiSelectMode() {
    _isMultiSelectMode = !_isMultiSelectMode;
    if (!_isMultiSelectMode) {
      _selectedTodoIds.clear();
    }
    notifyListeners();
  }

  void toggleTodoSelection(int id) {
    if (_selectedTodoIds.contains(id)) {
      _selectedTodoIds.remove(id);
    } else {
      _selectedTodoIds.add(id);
    }
    notifyListeners();
  }

  void selectAllVisible() {
    _selectedTodoIds.addAll(_filteredTodos.where((t) => t.id != null).map((t) => t.id!));
    notifyListeners();
  }

  void clearSelection() {
    _selectedTodoIds.clear();
    notifyListeners();
  }

  Future<void> deleteSelected() async {
    for (final id in _selectedTodoIds) {
      await _todoRepo.delete(id);
    }
    _todos.removeWhere((t) => t.id != null && _selectedTodoIds.contains(t.id));
    _selectedTodoIds.clear();
    _isMultiSelectMode = false;
    notifyListeners();
  }

  Future<void> completeSelected() async {
    for (final id in _selectedTodoIds) {
      final index = _todos.indexWhere((t) => t.id == id);
      if (index != -1) {
        final updated = _todos[index].copyWith(isDone: true);
        await _todoRepo.update(updated);
        _todos[index] = updated;
      }
    }
    _selectedTodoIds.clear();
    _isMultiSelectMode = false;
    notifyListeners();
  }

  Future<void> setCategoryForTodo(int todoId, int? categoryId) async {
    final index = _todos.indexWhere((t) => t.id == todoId);
    if (index == -1) return;
    final updated = _todos[index].copyWith(categoryId: categoryId);
    await _todoRepo.update(updated);
    _todos[index] = updated;
    notifyListeners();
  }

  Future<void> setCategoryForSelected(int? categoryId) async {
    for (final id in _selectedTodoIds) {
      final index = _todos.indexWhere((t) => t.id == id);
      if (index != -1) {
        final updated = _todos[index].copyWith(categoryId: categoryId);
        await _todoRepo.update(updated);
        _todos[index] = updated;
      }
    }
    _selectedTodoIds.clear();
    _isMultiSelectMode = false;
    notifyListeners();
  }

  Future<void> reorderTodos(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) newIndex -= 1;
    final item = _todos.removeAt(oldIndex);
    _todos.insert(newIndex, item);

    for (var i = 0; i < _todos.length; i++) {
      _todos[i] = _todos[i].copyWith(sortOrder: i);
    }

    await _updateSortOrders();
    notifyListeners();
  }

  Future<void> _updateSortOrders() async {
    final ids = _todos.map((t) => t.id).whereType<int>().toList();
    final db = DatabaseHelper.instance;
    final batch = (await db.database).batch();
    for (var i = 0; i < ids.length; i++) {
      batch.update(
        'todos',
        {'sortOrder': i},
        where: 'id = ?',
        whereArgs: [ids[i]],
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> toggleTodo(int id) async {
    final index = _todos.indexWhere((t) => t.id == id);
    if (index == -1) return;
    final todo = _todos[index];
    final updated = todo.copyWith(isDone: !todo.isDone);
    await _todoRepo.update(updated);
    _todos[index] = updated;
    
    // Handle recurring
    if (updated.isDone && updated.recurringConfig.type != RecurrenceType.none) {
      final nextDate = updated.recurringConfig.getNextOccurrence(
        updated.dueDate ?? DateTime.now(),
      );
      if (nextDate != null) {
        final newTodo = updated.copyWith(
          isDone: false,
          dueDate: nextDate,
          nextDueDate: null,
          subtasks: updated.subtasks.map((s) => s.copyWith(isDone: false)).toList(),
        );
        await _todoRepo.insert(newTodo);
      }
    }
    
    notifyListeners();
  }

  Future<void> addFromQuickAdd(ParsedTodo parsed) async {
    final todo = Todo(
      title: parsed.title,
      priority: parsed.priority ?? 'medium',
      dueDate: parsed.dueDate,
      tags: parsed.tags,
      recurringConfig: parsed.recurring ?? RecurringConfig(type: RecurrenceType.none),
      hasReminder: parsed.hasReminder,
      reminderAt: parsed.reminderAt,
      sortOrder: _todos.length,
    );
    await saveTodo(todo);
  }

  Future<void> saveTodo(Todo todo) async {
    if (todo.id == null) {
      final id = await _todoRepo.insert(todo);
      _todos.add(todo.copyWith(id: id));
      if (todo.hasReminder) {
        await NotificationService.instance.scheduleReminder(todo.copyWith(id: id));
      }
    } else {
      await _todoRepo.update(todo);
      final index = _todos.indexWhere((t) => t.id == todo.id);
      if (index != -1) _todos[index] = todo;
      if (todo.hasReminder) {
        await NotificationService.instance.scheduleReminder(todo);
      } else {
        await NotificationService.instance.cancelReminder(todo.id!);
      }
    }
    notifyListeners();
  }

  Future<void> postponeTodo(int id, {Duration? custom}) async {
    final index = _todos.indexWhere((t) => t.id == id);
    if (index == -1) return;
    final todo = _todos[index];
    final duration = custom ?? const Duration(days: 1);
    final newDueDate = todo.dueDate != null ? todo.dueDate!.add(duration) : DateTime.now().add(duration);
    final updated = todo.copyWith(
      dueDate: newDueDate,
      reminderAt: todo.hasReminder ? newDueDate.subtract(const Duration(hours: 1)) : todo.reminderAt,
    );
    await _todoRepo.update(updated);
    _todos[index] = updated;
    notifyListeners();
  }

  Future<void> snoozeReminder(int id, String action) async {
    final index = _todos.indexWhere((t) => t.id == id);
    if (index == -1) return;

    Duration duration;
    switch (action) {
      case 'snooze_15':
        duration = const Duration(minutes: 15);
        break;
      case 'snooze_60':
        duration = const Duration(hours: 1);
        break;
      case 'snooze_tomorrow':
        duration = const Duration(days: 1);
        break;
      default:
        duration = const Duration(hours: 1);
    }

    final todo = _todos[index];
    final newReminderAt = DateTime.now().add(duration);
    final updated = todo.copyWith(
      reminderAt: newReminderAt,
      hasReminder: true,
    );
    await _todoRepo.update(updated);
    _todos[index] = updated;
    await NotificationService.instance.scheduleSnoozedReminder(
      id, todo.title, todo.description, duration,
    );
    notifyListeners();
  }

  Future<void> deleteTodo(int id) async {
    await _todoRepo.delete(id);
    await NotificationService.instance.cancelReminder(id);
    _todos.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  Future<void> deleteCompleted() async {
    final completed = _todos.where((t) => t.isDone).toList();
    for (final todo in completed) {
      if (todo.id != null) {
        await _todoRepo.delete(todo.id!);
        await NotificationService.instance.cancelReminder(todo.id!);
      }
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

  // Subtask operations
  Future<void> addSubtask(int todoId, String title) async {
    final subtask = Subtask(title: title, todoId: todoId);
    await DatabaseHelper.instance.insertSubtask(subtask, todoId);
    final index = _todos.indexWhere((t) => t.id == todoId);
    if (index != -1) {
      final updatedSubtasks = List<Subtask>.from(_todos[index].subtasks)..add(subtask);
      _todos[index] = _todos[index].copyWith(subtasks: updatedSubtasks);
      notifyListeners();
    }
  }

  Future<void> toggleSubtask(int todoId, String subtaskId) async {
    final todoIndex = _todos.indexWhere((t) => t.id == todoId);
    if (todoIndex == -1) return;
    
    final todo = _todos[todoIndex];
    final subtaskIndex = todo.subtasks.indexWhere((s) => s.id == subtaskId);
    if (subtaskIndex == -1) return;
    
    final updatedSubtask = todo.subtasks[subtaskIndex].copyWith(
      isDone: !todo.subtasks[subtaskIndex].isDone,
    );
    await DatabaseHelper.instance.updateSubtask(updatedSubtask);
    
    final updatedSubtasks = List<Subtask>.from(todo.subtasks);
    updatedSubtasks[subtaskIndex] = updatedSubtask;
    _todos[todoIndex] = todo.copyWith(subtasks: updatedSubtasks);
    notifyListeners();
  }

  Future<void> deleteSubtask(int todoId, String subtaskId) async {
    await DatabaseHelper.instance.deleteSubtask(subtaskId);
    final todoIndex = _todos.indexWhere((t) => t.id == todoId);
    if (todoIndex != -1) {
      final updatedSubtasks = _todos[todoIndex].subtasks.where((s) => s.id != subtaskId).toList();
      _todos[todoIndex] = _todos[todoIndex].copyWith(subtasks: updatedSubtasks);
      notifyListeners();
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
