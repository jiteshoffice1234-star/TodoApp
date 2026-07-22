import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/todo.dart';
import '../../data/models/category.dart';
import '../../data/models/recurring_config.dart';
import 'priority_badge.dart';

class TodoCard extends StatelessWidget {
  final Todo todo;
  final TodoCategory? category;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final int index;

  const TodoCard({
    super.key,
    required this.todo,
    this.category,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    this.index = 0,
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

    return AnimatedSlide(
      offset: Offset(0, 0),
      duration: Duration(milliseconds: 300 + index * 50),
      curve: Curves.easeOut,
      child: AnimatedOpacity(
        opacity: 1.0,
        duration: Duration(milliseconds: 300 + index * 50),
        child: Dismissible(
          key: Key('todo_${todo.id}'),
          onDismissed: (_) => onDelete(),
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: Colors.red,
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          secondaryBackground: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 20),
            color: Colors.green,
            child: const Icon(Icons.check, color: Colors.white),
          ),
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.endToStart) {
              return true;
            } else {
              onToggle();
              return false;
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Card(
              color: todo.isDone
                  ? theme.colorScheme.surfaceContainerHighest
                  : theme.colorScheme.surface,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onEdit,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 12, 12, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: todo.isDone,
                        onChanged: (_) => onToggle(),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (category != null) ...[
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: _hexToColor(category!.color),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                if (todo.recurringConfig.type != RecurrenceType.none) ...[
                                  Icon(
                                    Icons.repeat,
                                    size: 14,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 4),
                                ],
                                if (todo.hasReminder) ...[
                                  Icon(
                                    Icons.notifications_active,
                                    size: 14,
                                    color: theme.colorScheme.tertiary,
                                  ),
                                  const SizedBox(width: 4),
                                ],
                                Expanded(
                                  child: Text(
                                    todo.title,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      decoration: todo.isDone
                                          ? TextDecoration.lineThrough
                                          : null,
                                      color: todo.isDone
                                          ? theme.colorScheme.onSurface
                                              .withOpacity(0.5)
                                          : theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (todo.description.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                todo.description,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.6),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                PriorityBadge(priority: todo.priority),
                                if (todo.dueDate != null) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isOverdue
                                          ? Colors.red.withOpacity(0.15)
                                          : theme.colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      DateFormat('MMM d, yyyy').format(todo.dueDate!),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: isOverdue
                                            ? Colors.red
                                            : theme.colorScheme.onPrimaryContainer,
                                      ),
                                    ),
                                  ),
                                ],
                                if (todo.recurringConfig.type != RecurrenceType.none) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.tertiaryContainer,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      todo.recurringConfig.label,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: theme.colorScheme.onTertiaryContainer,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            // Subtask progress
                            if (todo.hasSubtasks) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.check_circle_outline,
                                    size: 14,
                                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${todo.subtasks.where((s) => s.isDone).length}/${todo.subtasks.length}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: LinearProgressIndicator(
                                      value: todo.progress,
                                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                      minHeight: 4,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (todo.tags.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: todo.tags.map((tag) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.secondaryContainer,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      tag,
                                      style: TextStyle(
                                        fontSize: 10,
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
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: onDelete,
                        color: theme.colorScheme.error,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
