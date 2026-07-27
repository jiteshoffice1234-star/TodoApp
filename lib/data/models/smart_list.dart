import 'todo_enums.dart';

class SmartList {
  final int? id;
  final String name;
  final String icon;
  final TodoFilter filter;
  final String searchQuery;
  final String selectedTag;
  final int sortOrder;
  final String priority;
  final bool dueToday;

  SmartList({
    this.id,
    required this.name,
    this.icon = '📌',
    this.filter = TodoFilter.all,
    this.searchQuery = '',
    this.selectedTag = '',
    this.sortOrder = 0,
    this.priority = '',
    this.dueToday = false,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'icon': icon,
      'filter': filter.index,
      'searchQuery': searchQuery,
      'selectedTag': selectedTag,
      'sortOrder': sortOrder,
      'priority': priority,
      'dueToday': dueToday ? 1 : 0,
    };
  }

  factory SmartList.fromMap(Map<String, dynamic> map) {
    return SmartList(
      id: map['id'] as int?,
      name: map['name'] as String,
      icon: map['icon'] as String? ?? '📌',
      filter: TodoFilter.values[map['filter'] as int? ?? 0],
      searchQuery: map['searchQuery'] as String? ?? '',
      selectedTag: map['selectedTag'] as String? ?? '',
      sortOrder: map['sortOrder'] as int? ?? 0,
      priority: map['priority'] as String? ?? '',
      dueToday: (map['dueToday'] as int? ?? 0) == 1,
    );
  }

  SmartList copyWith({
    int? id,
    String? name,
    String? icon,
    TodoFilter? filter,
    String? searchQuery,
    String? selectedTag,
    int? sortOrder,
    String? priority,
    bool? dueToday,
  }) {
    return SmartList(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      filter: filter ?? this.filter,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedTag: selectedTag ?? this.selectedTag,
      sortOrder: sortOrder ?? this.sortOrder,
      priority: priority ?? this.priority,
      dueToday: dueToday ?? this.dueToday,
    );
  }
}
