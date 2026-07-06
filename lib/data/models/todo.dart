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
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

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
  }) {
    return Todo(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      dueDate: dueDate ?? this.dueDate,
      categoryId: categoryId ?? this.categoryId,
      isDone: isDone ?? this.isDone,
      tags: tags ?? this.tags,
      attachments: attachments ?? this.attachments,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
