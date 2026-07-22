import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../data/models/todo.dart';
import '../../data/models/category.dart';
import '../../data/models/recurring_config.dart';
import '../../core/theme/color_utils.dart';
import 'priority_badge.dart';

class GridTodoCard extends StatefulWidget {
  final Todo todo;
  final TodoCategory? category;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final int index;

  const GridTodoCard({
    super.key,
    required this.todo,
    this.category,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    this.index = 0,
  });

  @override
  State<GridTodoCard> createState() => _GridTodoCardState();
}

class _GridTodoCardState extends State<GridTodoCard> {
  double _scale = 1.0;

  Color _hexToColor(String hex) => parseHexColor(hex);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final todo = widget.todo;
    final isOverdue = todo.dueDate != null &&
        todo.dueDate!.isBefore(DateTime.now()) &&
        !todo.isDone;

    return Animate(
      effects: [
        SlideEffect(
          begin: const Offset(0, 0.12),
          end: Offset.zero,
          curve: Curves.easeOutCubic,
          duration: (400 + widget.index * 60).ms,
        ),
        FadeEffect(
          begin: 0.0,
          end: 1.0,
          curve: Curves.easeOut,
          duration: (400 + widget.index * 60).ms,
        ),
      ],
      child: GestureDetector(
        onTap: widget.onEdit,
        onTapDown: (_) => setState(() => _scale = 0.95),
        onTapUp: (_) => setState(() => _scale = 1.0),
        onTapCancel: () => setState(() => _scale = 1.0),
        child: AnimatedScale(
          scale: _scale,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: Card(
            color: todo.isDone
                ? theme.colorScheme.surfaceContainerHighest
                : theme.colorScheme.surface,
            elevation: todo.isDone ? 0 : 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: isOverdue
                  ? BorderSide(color: Colors.red.withOpacity(0.3))
                  : BorderSide.none,
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: widget.onEdit,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (widget.category != null)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _hexToColor(widget.category!.color),
                              shape: BoxShape.circle,
                            ),
                          ),
                        const Spacer(),
                        if (todo.recurringConfig.type != RecurrenceType.none)
                          Icon(Icons.repeat, size: 14,
                              color: theme.colorScheme.primary),
                        if (todo.hasReminder)
                          Icon(Icons.notifications_active, size: 14,
                              color: theme.colorScheme.tertiary),
                        Checkbox(
                          value: todo.isDone,
                          onChanged: (_) => widget.onToggle(),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: AnimatedDefaultTextStyle(
                        duration: 300.ms,
                        style: theme.textTheme.titleSmall?.copyWith(
                          decoration: todo.isDone
                              ? TextDecoration.lineThrough
                              : null,
                          color: todo.isDone
                              ? theme.colorScheme.onSurface.withOpacity(0.5)
                              : theme.colorScheme.onSurface,
                        ),
                        child: Text(
                          todo.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
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
                    if (todo.hasSubtasks) ...[
                      Row(
                        children: [
                          Icon(Icons.check_circle_outline, size: 12,
                              color: theme.colorScheme.onSurface
                                  .withOpacity(0.6)),
                          const SizedBox(width: 4),
                          Text(
                            '${todo.subtasks.where((s) => s.isDone).length}/${todo.subtasks.length}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 10,
                              color: theme.colorScheme.onSurface
                                  .withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: todo.progress),
                        duration: 600.ms,
                        curve: Curves.easeOutCubic,
                        builder: (_, value, __) => LinearProgressIndicator(
                          value: value,
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                          minHeight: 3,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
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
                                color:
                                    theme.colorScheme.onSecondaryContainer,
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
        ),
      ),
    );
  }
}
