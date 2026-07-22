import 'recurring_config.dart';
import 'subtask.dart';

class Todo {
  final int? id;
  final String title;
  final String description;
  final String priority;
  final DateTime? dueDate;
  final int? categoryId;
  final bool isDone;
  final List<String> tags;
  final List<String> attachments;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // NEW: Recurring
  final RecurringConfig recurringConfig;
  final DateTime? nextDueDate;
  
  // NEW: Subtasks
  final List<Subtask> subtasks;
  
  // NEW: Reminder
  final DateTime? reminderAt;
  final bool hasReminder;
  
  // NEW: Sort order for drag-drop
  final int sortOrder;

  Todo({
    this.id,
    required this.title,
    this.description = '',
    this.priority = 'medium',
    this.dueDate,
    this.categoryId,
    this.isDone = false,
    this.tags = const [],
    this.attachments = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
    RecurringConfig? recurringConfig,
    this.nextDueDate,
    this.subtasks = const [],
    this.reminderAt,
    this.hasReminder = false,
    this.sortOrder = 0,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        recurringConfig = recurringConfig ?? RecurringConfig(type: RecurrenceType.none);

  double get progress {
    if (subtasks.isEmpty) return isDone ? 1.0 : 0.0;
    if (subtasks.every((s) => s.isDone)) return 1.0;
    final done = subtasks.where((s) => s.isDone).length;
    return done / subtasks.length;
  }

  bool get hasSubtasks => subtasks.isNotEmpty;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'description': description,
      'priority': priority,
      'dueDate': dueDate?.millisecondsSinceEpoch,
      'categoryId': categoryId,
      'isDone': isDone ? 1 : 0,
      'tags': tags.join(','),
      'attachments': attachments.join(','),
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'recurringConfig': recurringConfig.toMap()['type'],
      'recurringInterval': recurringConfig.toMap()['interval'],
      'recurringDaysOfWeek': recurringConfig.toMap()['daysOfWeek'],
      'recurringDayOfMonth': recurringConfig.toMap()['dayOfMonth'],
      'recurringEndDate': recurringConfig.toMap()['endDate'],
      'recurringHasEnd': recurringConfig.toMap()['hasEnd'],
      'nextDueDate': nextDueDate?.millisecondsSinceEpoch,
      'reminderAt': reminderAt?.millisecondsSinceEpoch,
      'hasReminder': hasReminder ? 1 : 0,
      'sortOrder': sortOrder,
    };
  }

  factory Todo.fromMap(Map<String, dynamic> map) {
    return Todo(
      id: map['id'] as int?,
      title: map['title'] as String,
      description: map['description'] as String? ?? '',
      priority: map['priority'] as String? ?? 'medium',
      dueDate: map['dueDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['dueDate'] as int)
          : null,
      categoryId: map['categoryId'] as int?,
      isDone: (map['isDone'] as int? ?? 0) == 1,
      tags: (map['tags'] as String?)?.split(',').where((t) => t.isNotEmpty).toList() ?? [],
      attachments: (map['attachments'] as String?)?.split(',').where((a) => a.isNotEmpty).toList() ?? [],
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int)
          : DateTime.now(),
      recurringConfig: RecurringConfig.fromMap({
        'type': map['recurringConfig'] ?? 0,
        'interval': map['recurringInterval'] ?? 1,
        'daysOfWeek': map['recurringDaysOfWeek'] ?? '',
        'dayOfMonth': map['recurringDayOfMonth'],
        'endDate': map['recurringEndDate'],
        'hasEnd': map['recurringHasEnd'] ?? 0,
      }),
      nextDueDate: map['nextDueDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['nextDueDate'] as int)
          : null,
      reminderAt: map['reminderAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['reminderAt'] as int)
          : null,
      hasReminder: (map['hasReminder'] as int? ?? 0) == 1,
      sortOrder: map['sortOrder'] as int? ?? 0,
    );
  }

  Todo copyWith({
    int? id,
    String? title,
    String? description,
    String? priority,
    DateTime? dueDate,
    int? categoryId,
    bool? isDone,
    List<String>? tags,
    List<String>? attachments,
    DateTime? createdAt,
    DateTime? updatedAt,
    RecurringConfig? recurringConfig,
    DateTime? nextDueDate,
    List<Subtask>? subtasks,
    DateTime? reminderAt,
    bool? hasReminder,
    int? sortOrder,
    bool clearDueDate = false,
    bool clearNextDueDate = false,
    bool clearReminder = false,
  }) {
    return Todo(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      categoryId: categoryId ?? this.categoryId,
      isDone: isDone ?? this.isDone,
      tags: tags ?? this.tags,
      attachments: attachments ?? this.attachments,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      recurringConfig: recurringConfig ?? this.recurringConfig,
      nextDueDate: clearNextDueDate ? null : (nextDueDate ?? this.nextDueDate),
      subtasks: subtasks ?? this.subtasks,
      reminderAt: clearReminder ? null : (reminderAt ?? this.reminderAt),
      hasReminder: hasReminder ?? this.hasReminder,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}
