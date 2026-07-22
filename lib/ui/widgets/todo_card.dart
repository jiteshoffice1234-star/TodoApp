import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../data/models/todo.dart';
import '../../data/models/category.dart';
import '../../data/models/recurring_config.dart';
import '../../core/theme/color_utils.dart';
import '../../providers/todo_provider.dart';
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

  Color _hexToColor(String hex) => parseHexColor(hex);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOverdue =
        todo.dueDate != null && todo.dueDate!.isBefore(DateTime.now()) && !todo.isDone;

    return Animate(
      effects: [
        SlideEffect(
          begin: const Offset(0, 0.1),
          end: Offset.zero,
          curve: Curves.easeOutCubic,
          duration: (400 + index * 60).ms,
        ),
        FadeEffect(
          begin: 0.0,
          end: 1.0,
          curve: Curves.easeOut,
          duration: (400 + index * 60).ms,
        ),
      ],
      child: Dismissible(
        key: Key('todo_${todo.id}'),
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.endToStart) return true;
          return false;
        },
        onDismissed: (_) => onDelete(),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          color: Colors.red,
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: _TodoCardContent(
            todo: todo,
            category: category,
            isOverdue: isOverdue,
            theme: theme,
            onEdit: onEdit,
            onToggle: onToggle,
            onDelete: onDelete,
            hexToColor: _hexToColor,
          ),
        ),
      ),
    );
  }
}

class _TodoCardContent extends StatefulWidget {
  final Todo todo;
  final TodoCategory? category;
  final bool isOverdue;
  final ThemeData theme;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final Color Function(String) hexToColor;

  const _TodoCardContent({
    required this.todo,
    required this.category,
    required this.isOverdue,
    required this.theme,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
    required this.hexToColor,
  });

  @override
  State<_TodoCardContent> createState() => _TodoCardContentState();
}

class _TodoCardContentState extends State<_TodoCardContent>
    with SingleTickerProviderStateMixin {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    final t = widget.todo;
    final cat = widget.category;
    final theme = widget.theme;
    final isOverdue = widget.isOverdue;
    final _hexToColor = widget.hexToColor;

    return GestureDetector(
      onTap: widget.onEdit,
      onTapDown: (_) => setState(() => _scale = 0.97),
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: Card(
          color: t.isDone
              ? theme.colorScheme.surfaceContainerHighest
              : theme.colorScheme.surface,
          elevation: t.isDone ? 0 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isOverdue
                ? BorderSide(color: Colors.red.withOpacity(0.3))
                : BorderSide.none,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: t.isDone,
                  onChanged: (_) => widget.onToggle(),
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
                          if (cat != null) ...[
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: _hexToColor(cat!.color),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          if (t.recurringConfig.type != RecurrenceType.none) ...[
                            Icon(Icons.repeat, size: 14,
                                color: theme.colorScheme.primary),
                            const SizedBox(width: 4),
                          ],
                          if (t.hasReminder) ...[
                            Icon(Icons.notifications_active, size: 14,
                                color: theme.colorScheme.tertiary),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: AnimatedDefaultTextStyle(
                              duration: 300.ms,
                              style: theme.textTheme.titleSmall?.copyWith(
                                decoration: t.isDone
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: t.isDone
                                    ? theme.colorScheme.onSurface
                                        .withOpacity(0.5)
                                    : theme.colorScheme.onSurface,
                              ),
                              child: Text(t.title),
                            ),
                          ),
                        ],
                      ),
                      if (t.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          t.description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
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
                          PriorityBadge(priority: t.priority),
                          if (t.dueDate != null) ...[
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
                                DateFormat('MMM d, yyyy').format(t.dueDate!),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: isOverdue
                                      ? Colors.red
                                      : theme.colorScheme
                                          .onPrimaryContainer,
                                ),
                              ),
                            ),
                          ],
                          if (t.recurringConfig.type != RecurrenceType.none) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.tertiaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                t.recurringConfig.label,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: theme.colorScheme
                                      .onTertiaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (t.hasSubtasks) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.check_circle_outline, size: 14,
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.6)),
                            const SizedBox(width: 4),
                            Text(
                              '${t.subtasks.where((s) => s.isDone).length}/${t.subtasks.length}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.6),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0, end: t.progress),
                                duration: 600.ms,
                                curve: Curves.easeOutCubic,
                                builder: (_, value, __) =>
                                    LinearProgressIndicator(
                                  value: value,
                                  backgroundColor: theme
                                      .colorScheme.surfaceContainerHighest,
                                  minHeight: 4,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (t.tags.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: t.tags.map((tag) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color:
                                    theme.colorScheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                tag,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: theme.colorScheme
                                      .onSecondaryContainer,
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
                  onPressed: widget.onDelete,
                  color: theme.colorScheme.error,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
