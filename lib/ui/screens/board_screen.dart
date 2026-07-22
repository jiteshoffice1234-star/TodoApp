import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../data/models/todo.dart';
import '../../data/models/category.dart';
import '../../data/models/recurring_config.dart';
import '../../providers/todo_provider.dart';
import '../../core/theme/color_utils.dart';
import 'add_edit_todo_screen.dart';

class BoardScreen extends StatefulWidget {
  const BoardScreen({super.key});

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  int? _draggedTodoId;
  int? _dragTargetCategory;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TodoProvider>();
    final todos = provider.todos.where((t) => !t.isDone).toList();
    final categories = provider.categories;
    final theme = Theme.of(context);

    final uncategorized = todos.where((t) => t.categoryId == null).toList();
    final columns = <BoardColumn>[
      BoardColumn(
        category: null,
        todos: uncategorized,
        color: theme.colorScheme.surfaceContainerHighest,
      ),
      ...categories.map((cat) => BoardColumn(
        category: cat,
        todos: todos.where((t) => t.categoryId == cat.id).toList(),
        color: parseHexColor(cat.color).withOpacity(0.15),
      )),
    ];

    final doneTodos = provider.todos.where((t) => t.isDone).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Board'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AddEditTodoScreen()),
            ),
          ),
        ],
      ),
      body: columns.isEmpty
          ? const Center(child: Text('No categories yet. Add one in Categories.'))
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.all(12),
                    children: columns.map((col) => _buildColumn(col, provider, theme)).toList(),
                  ),
                ),
                if (doneTodos.isNotEmpty) _buildDoneStrip(doneTodos, provider, theme),
              ],
            ),
    );
  }

  Widget _buildColumn(BoardColumn col, TodoProvider provider, ThemeData theme) {
    final cat = col.category;
    final catColor = cat != null ? parseHexColor(cat.color) : theme.colorScheme.onSurface.withOpacity(0.4);
    final label = cat?.name ?? 'Uncategorized';
    final bgColor = cat != null ? parseHexColor(cat.color).withOpacity(0.08) : theme.colorScheme.surfaceContainerHighest;

    return DragTarget<int>(
      onWillAcceptWithDetails: (details) {
        setState(() => _dragTargetCategory = cat?.id);
        return true;
      },
      onLeave: (_) => setState(() => _dragTargetCategory = null),
      onAcceptWithDetails: (details) {
        final todoId = details.data;
        provider.setCategoryForTodo(todoId, cat?.id);
        setState(() => _dragTargetCategory = null);
      },
      builder: (context, candidateData, rejectedData) {
        final isHover = _dragTargetCategory == cat?.id;
        return Animate(
          effects: [
            SlideEffect(
              begin: const Offset(0, 0.08),
              end: Offset.zero,
              curve: Curves.easeOutCubic,
              duration: 400.ms,
            ),
            FadeEffect(
              begin: 0.0,
              end: 1.0,
              curve: Curves.easeOut,
              duration: 400.ms,
            ),
          ],
          child: Container(
            width: 260,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: isHover ? bgColor.withOpacity(0.3) : bgColor,
              borderRadius: BorderRadius.circular(16),
              border: isHover ? Border.all(color: catColor.withOpacity(0.6), width: 2) : null,
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Row(
                    children: [
                      Container(
                        width: 10, height: 10,
                        decoration: BoxDecoration(color: catColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Text(label, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text('${col.todos.length}', style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: col.todos.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text('Drop todos here', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.3))),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: col.todos.length,
                          itemBuilder: (context, index) => _buildCard(col.todos[index], index, provider, theme),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCard(Todo todo, int index, TodoProvider provider, ThemeData theme) {
    return Animate(
      effects: [
        SlideEffect(
          begin: const Offset(0, 0.1),
          end: Offset.zero,
          curve: Curves.easeOutCubic,
          duration: (300 + index * 50).ms,
        ),
        FadeEffect(
          begin: 0.0,
          end: 1.0,
          curve: Curves.easeOut,
          duration: (300 + index * 50).ms,
        ),
      ],
      child: LongPressDraggable<int>(
      data: todo.id!,
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 220,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(todo.title, style: theme.textTheme.bodyMedium),
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _cardContent(todo, provider, theme),
      ),
      onDragStarted: () => setState(() => _draggedTodoId = todo.id),
      onDragEnd: (_) => setState(() => _draggedTodoId = null),
      child: _cardContent(todo, provider, theme),
    ),
    );
  }

  Widget _cardContent(Todo todo, TodoProvider provider, ThemeData theme) {
    final isOverdue = todo.dueDate != null && todo.dueDate!.isBefore(DateTime.now()) && !todo.isDone;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => AddEditTodoScreen(todo: todo)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(todo.title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                  ),
                  Checkbox(
                    value: todo.isDone,
                    onChanged: (_) => provider.toggleTodo(todo.id!),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              if (todo.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(todo.description, style: theme.textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  _miniBadge(todo.priority == 'high' ? Colors.red : todo.priority == 'medium' ? Colors.orange : Colors.green, todo.priority, theme),
                  const Spacer(),
                  if (todo.dueDate != null)
                    Text(
                      '${todo.dueDate!.month}/${todo.dueDate!.day}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isOverdue ? Colors.red : theme.colorScheme.onSurface.withOpacity(0.6),
                        fontWeight: isOverdue ? FontWeight.w600 : null,
                      ),
                    ),
                  if (todo.subtasks.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text('${todo.subtasks.where((s) => s.isDone).length}/${todo.subtasks.length}',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.5)),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniBadge(Color color, String text, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Widget _buildDoneStrip(List<Todo> doneTodos, TodoProvider provider, ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.08),
        border: Border(top: BorderSide(color: Colors.green.withOpacity(0.2))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, size: 16, color: Colors.green),
              const SizedBox(width: 6),
              Text('Completed (${doneTodos.length})', style: theme.textTheme.labelMedium?.copyWith(color: Colors.green)),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: doneTodos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final t = doneTodos[index];
                return Chip(
                  label: Text(t.title, style: const TextStyle(fontSize: 11)),
                  onDeleted: () => provider.toggleTodo(t.id!),
                  deleteIcon: const Icon(Icons.undo, size: 14),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class BoardColumn {
  final TodoCategory? category;
  final List<Todo> todos;
  final Color color;

  BoardColumn({this.category, required this.todos, required this.color});
}
