class TodoCategory {
  final int? id;
  final String name;
  final String color;
  final List<String> customColors;

  TodoCategory({
    this.id,
    required this.name,
    this.color = '#2196F3',
    this.customColors = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'color': color,
      'customColors': customColors.join(','),
    };
  }

  factory TodoCategory.fromMap(Map<String, dynamic> map) {
    return TodoCategory(
      id: map['id'] as int?,
      name: map['name'] as String,
      color: map['color'] as String? ?? '#2196F3',
      customColors: (map['customColors'] as String?)?.split(',').where((c) => c.isNotEmpty).toList() ?? [],
    );
  }

  TodoCategory copyWith({
    int? id,
    String? name,
    String? color,
    List<String>? customColors,
  }) {
    return TodoCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      customColors: customColors ?? this.customColors,
    );
  }

  static const List<String> availableColors = [
    '#F44336', '#E91E63', '#9C27B0', '#673AB7',
    '#3F51B5', '#2196F3', '#009688', '#4CAF50',
    '#8BC34A', '#CDDC39', '#FFC107', '#FF9800',
    '#FF5722', '#795548', '#607D8B', '#00BCD4',
    '#03A9F4', '#00E676', '#F06292', '#BA68C8',
  ];
}
