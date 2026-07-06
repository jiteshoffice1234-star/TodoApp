import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/todo.dart';
import '../../data/models/category.dart';
import 'priority_badge.dart';

class GridTodoCard extends StatelessWidget {
  final Todo todo;
  final TodoCategory? category;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const GridTodoCard({
    super.key,
    required this.todo,
    this.category,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOverdue = todo.dueDate != null &&
        todo.dueDate!.isBefore(DateTime.now()) &&
        !todo.isDone;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      child: Card(
        color: todo.isDone
            ? theme.colorScheme.surfaceContainerHighest
            : theme.colorScheme.surface,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (category != null)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _hexToColor(category!.color),
                          shape: BoxShape.circle,
                        ),
                      ),
                    const Spacer(),
                    Checkbox(
                      value: todo.isDone,
                      onChanged: (_) => onToggle(),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: Text(
                    todo.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      decoration: todo.isDone
                          ? TextDecoration.lineThrough
                          : null,
                      color: todo.isDone
                          ? theme.colorScheme.onSurface.withOpacity(0.5)
                          : theme.colorScheme.onSurface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (todo.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    todo.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    PriorityBadge(priority: todo.priority),
                    const Spacer(),
                    if (todo.dueDate != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isOverdue
                              ? Colors.red.withOpacity(0.15)
                              : theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          DateFormat('MMM d').format(todo.dueDate!),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: isOverdue
                                ? Colors.red
                                : theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                  ],
                ),
                if (todo.tags.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: todo.tags.take(2).map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          tag,
                          style: TextStyle(
                            fontSize: 8,
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
