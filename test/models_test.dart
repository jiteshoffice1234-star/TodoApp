import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/data/models/todo.dart';
import 'package:todo_app/data/models/category.dart';

void main() {
  group('Todo', () {
    test('toMap and fromMap roundtrip', () {
      final todo = Todo(
        title: 'Test',
        description: 'Description',
        priority: 'high',
        isDone: false,
      );
      final map = todo.toMap();
      final restored = Todo.fromMap(map);
      expect(restored.title, todo.title);
      expect(restored.description, todo.description);
      expect(restored.priority, todo.priority);
      expect(restored.isDone, todo.isDone);
    });

    test('copyWith updates fields', () {
      final todo = Todo(title: 'Original');
      final updated = todo.copyWith(title: 'Updated', isDone: true);
      expect(updated.title, 'Updated');
      expect(updated.isDone, true);
      expect(updated.id, todo.id);
    });
  });

  group('TodoCategory', () {
    test('toMap and fromMap roundtrip', () {
      final cat = TodoCategory(name: 'Work', color: '#FF5722');
      final map = cat.toMap();
      final restored = TodoCategory.fromMap(map);
      expect(restored.name, cat.name);
      expect(restored.color, cat.color);
    });
  });
}
