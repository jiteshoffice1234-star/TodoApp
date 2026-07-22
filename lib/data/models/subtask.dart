import 'package:uuid/uuid.dart';

class Subtask {
  final String id;
  final String title;
  final bool isDone;
  final int? todoId;
  final int sortOrder;

  Subtask({
    String? id,
    required this.title,
    this.isDone = false,
    this.todoId,
    this.sortOrder = 0,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'isDone': isDone ? 1 : 0,
      'todoId': todoId,
      'sortOrder': sortOrder,
    };
  }

  factory Subtask.fromMap(Map<String, dynamic> map) {
    return Subtask(
      id: map['id'] as String,
      title: map['title'] as String,
      isDone: (map['isDone'] as int? ?? 0) == 1,
      todoId: map['todoId'] as int?,
      sortOrder: map['sortOrder'] as int? ?? 0,
    );
  }

  Subtask copyWith({
    String? id,
    String? title,
    bool? isDone,
    int? todoId,
    int? sortOrder,
  }) {
    return Subtask(
      id: id ?? this.id,
      title: title ?? this.title,
      isDone: isDone ?? this.isDone,
      todoId: todoId ?? this.todoId,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}
