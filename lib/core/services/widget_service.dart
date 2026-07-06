import 'dart:convert';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/todo.dart';
import '../../data/repositories/todo_repository.dart';

class WidgetService {
  static final WidgetService instance = WidgetService._init();
  WidgetService._init();

  Future<void> updateWidget() async {
    final todos = await TodoRepository().getAll();
    final pendingTodos = todos.where((t) => !t.isDone).take(5).toList();
    
    final todoData = pendingTodos.map((t) => {
      'id': t.id,
      'title': t.title,
      'priority': t.priority,
      'dueDate': t.dueDate?.toIso8601String(),
    }).toList();

    await HomeWidget.saveWidgetData<String>(
      'todos',
      jsonEncode(todoData),
    );
    
    await HomeWidget.saveWidgetData<int>(
      'pendingCount',
      pendingTodos.length,
    );

    await HomeWidget.updateWidget(
      name: 'TodoWidget',
      iOSName: 'TodoWidget',
    );
  }

  Future<void> init() async {
    HomeWidget.widgetClicked.listen((data) {
      if (data != null) {
        final action = data['action'];
        if (action == 'toggle' && data['todoId'] != null) {
          _toggleTodo(data['todoId'] as int);
        }
      }
    });
  }

  Future<void> _toggleTodo(int id) async {
    final todos = await TodoRepository().getAll();
    final todo = todos.firstWhere((t) => t.id == id);
    final updated = todo.copyWith(isDone: !todo.isDone);
    await TodoRepository().update(updated);
    await updateWidget();
  }
}
