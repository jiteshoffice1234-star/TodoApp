import 'dart:convert';
import 'package:home_widget/home_widget.dart';
import '../../data/models/todo.dart';
import '../../data/repositories/todo_repository.dart';

class WidgetService {
  static final WidgetService instance = WidgetService._init();
  WidgetService._init();

  Future<void> updateWidget() async {
    final todos = await TodoRepository().getAll();
    final pendingTodos = todos.where((t) => !t.isDone).take(5).toList();
    final completedToday = todos.where((t) =>
        t.isDone &&
        t.updatedAt.year == DateTime.now().year &&
        t.updatedAt.month == DateTime.now().month &&
        t.updatedAt.day == DateTime.now().day).length;
    
    final todoData = pendingTodos.map((t) => {
      'id': t.id,
      'title': t.title,
      'priority': t.priority,
      'dueDate': t.dueDate?.toIso8601String(),
      'hasSubtasks': t.hasSubtasks,
      'subtaskProgress': t.progress,
      'hasReminder': t.hasReminder,
    }).toList();

    await HomeWidget.saveWidgetData<String>(
      'todos',
      jsonEncode(todoData),
    );
    
    await HomeWidget.saveWidgetData<int>(
      'pendingCount',
      pendingTodos.length,
    );

    await HomeWidget.saveWidgetData<int>(
      'completedToday',
      completedToday,
    );

    await HomeWidget.updateWidget(
      name: 'TodoWidget',
      iOSName: 'TodoWidget',
    );
  }

  Future<void> init() async {
    HomeWidget.widgetClicked.listen((Uri? data) {
      if (data != null) {
        final action = data.queryParameters['action'];
        if (action == 'toggle' && data.queryParameters['todoId'] != null) {
          final todoId = int.tryParse(data.queryParameters['todoId']!);
          if (todoId != null) {
            _toggleTodo(todoId);
          }
        }
      }
    });
  }

  Future<void> _toggleTodo(int id) async {
    final todos = await TodoRepository().getAll();
    try {
      final todo = todos.firstWhere((t) => t.id == id);
      final updated = todo.copyWith(isDone: !todo.isDone);
      await TodoRepository().update(updated);
      await updateWidget();
    } catch (_) {}
  }
}
