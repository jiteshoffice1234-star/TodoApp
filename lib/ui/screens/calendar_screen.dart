import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../providers/todo_provider.dart';
import '../../data/models/todo.dart';
import '../widgets/todo_card.dart';
import 'add_edit_todo_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TodoProvider>();
    final theme = Theme.of(context);
    final selectedDate = _selectedDay ?? _focusedDay;
    final todosForDate = provider.getTodosForDate(selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
            onPressed: () {
              setState(() {
                _focusedDay = DateTime.now();
                _selectedDay = DateTime.now();
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime(2020),
            lastDay: DateTime(2100),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onFormatChanged: (format) {
              setState(() => _calendarFormat = format);
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
            eventLoader: (day) {
              return provider.getTodosForDate(day);
            },
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
              markerDecoration: BoxDecoration(
                color: theme.colorScheme.error,
                shape: BoxShape.circle,
              ),
              markerSize: 8,
              markersMaxCount: 3,
            ),
            headerStyle: HeaderStyle(
              formatButtonVisible: true,
              titleCentered: true,
              titleTextStyle: theme.textTheme.titleMedium!,
            ),
          ),
          const Divider(),
          Expanded(
            child: todosForDate.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.event_available,
                          size: 64,
                          color: theme.colorScheme.primary.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No todos for ${DateFormat('MMM d, yyyy').format(selectedDate)}',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: todosForDate.length,
                    itemBuilder: (context, index) {
                      final todo = todosForDate[index];
                      final category = provider.getCategoryById(todo.categoryId);
                      return TodoCard(
                        todo: todo,
                        category: category,
                        index: index,
                        onToggle: () => provider.toggleTodo(todo.id!),
                        onEdit: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AddEditTodoScreen(todo: todo),
                          ),
                        ),
                        onDelete: () => _confirmDelete(context, provider, todo),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AddEditTodoScreen(
                todo: Todo(
                  title: '',
                  dueDate: selectedDate,
                ),
              ),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  void _confirmDelete(BuildContext context, TodoProvider provider, Todo todo) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Todo'),
        content: Text('Delete "${todo.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () {
              provider.deleteTodo(todo.id!);
              Navigator.of(ctx).pop();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
