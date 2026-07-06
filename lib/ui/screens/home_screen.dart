import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/todo.dart';
import '../../providers/todo_provider.dart';
import '../../providers/theme_provider.dart';
import '../widgets/todo_card.dart';
import '../widgets/grid_todo_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/voice_input_button.dart';
import 'add_edit_todo_screen.dart';
import 'categories_screen.dart';
import 'stats_screen.dart';
import 'backup_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late TextEditingController _searchCtrl;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TodoProvider>().loadData();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final todoProvider = context.watch<TodoProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final theme = Theme.of(context);
    final todos = todoProvider.todos;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Todo App'),
        actions: [
          IconButton(
            icon: Icon(
                themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => themeProvider.toggleTheme(),
            tooltip: 'Toggle theme',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (value) {
              switch (value) {
                case 'sort':
                  _showSortDialog(todoProvider);
                  break;
                case 'view':
                  todoProvider.setViewMode(
                    todoProvider.viewMode == ViewMode.list
                        ? ViewMode.grid
                        : ViewMode.list,
                  );
                  break;
                case 'stats':
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const StatsScreen()),
                  );
                  break;
                case 'backup':
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const BackupScreen()),
                  );
                  break;
                case 'categories':
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CategoriesScreen()),
                  );
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'sort',
                child: Row(
                  children: [
                    const Icon(Icons.sort),
                    const SizedBox(width: 8),
                    Text('Sort: ${_getSortLabel(todoProvider.sort)}'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'view',
                child: Row(
                  children: [
                    Icon(todoProvider.viewMode == ViewMode.list
                        ? Icons.grid_view
                        : Icons.view_list),
                    const SizedBox(width: 8),
                    Text(todoProvider.viewMode == ViewMode.list
                        ? 'Grid View'
                        : 'List View'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'stats',
                child: Row(
                  children: [
                    Icon(Icons.bar_chart),
                    SizedBox(width: 8),
                    Text('Statistics'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'backup',
                child: Row(
                  children: [
                    Icon(Icons.backup),
                    SizedBox(width: 8),
                    Text('Backup & Restore'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'categories',
                child: Row(
                  children: [
                    Icon(Icons.category),
                    SizedBox(width: 8),
                    Text('Categories'),
                  ],
                ),
              ),
            ],
          ),
          if (todoProvider.doneCount > 0)
            IconButton(
              icon: const Icon(Icons.clear_all),
              onPressed: _confirmClearDone,
              tooltip: 'Clear completed',
            ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(todoProvider),
          _buildFilterChips(todoProvider, theme),
          _buildTagFilter(todoProvider, theme),
          Expanded(
            child: todoProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : todos.isEmpty
                    ? const EmptyState()
                    : todoProvider.viewMode == ViewMode.list
                        ? _buildTodoList(todos, todoProvider, theme)
                        : _buildTodoGrid(todos, todoProvider, theme),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const VoiceInputButton(),
          const SizedBox(height: 16),
          FloatingActionButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AddEditTodoScreen()),
            ),
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(TodoProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: TextField(
        controller: _searchCtrl,
        decoration: InputDecoration(
          hintText: 'Search todos...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchCtrl.clear();
                    provider.setSearchQuery('');
                  },
                )
              : null,
        ),
        onChanged: (v) => provider.setSearchQuery(v),
      ),
    );
  }

  Widget _buildFilterChips(TodoProvider provider, ThemeData theme) {
    final filters = [
      ('All', TodoFilter.all, provider.allCount),
      ('Pending', TodoFilter.pending, provider.pendingCount),
      ('Done', TodoFilter.done, provider.doneCount),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: filters.map((f) {
          final (label, filter, count) = f;
          final isSelected = provider.filter == filter;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FilterChip(
              label: Text('$label ($count)'),
              selected: isSelected,
              onSelected: (_) => provider.setFilter(filter),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTagFilter(TodoProvider provider, ThemeData theme) {
    if (provider.allTags.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: const Text('All Tags'),
              selected: provider.selectedTag.isEmpty,
              onSelected: (_) => provider.setSelectedTag(''),
            ),
          ),
          ...provider.allTags.map((tag) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(tag),
              selected: provider.selectedTag == tag,
              onSelected: (_) => provider.setSelectedTag(tag),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildTodoList(
      List<Todo> todos, TodoProvider provider, ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: todos.length,
      itemBuilder: (context, index) {
        final todo = todos[index];
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
    );
  }

  Widget _buildTodoGrid(
      List<Todo> todos, TodoProvider provider, ThemeData theme) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: todos.length,
      itemBuilder: (context, index) {
        final todo = todos[index];
        final category = provider.getCategoryById(todo.categoryId);
        return GridTodoCard(
          todo: todo,
          category: category,
          onToggle: () => provider.toggleTodo(todo.id!),
          onEdit: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AddEditTodoScreen(todo: todo),
            ),
          ),
          onDelete: () => _confirmDelete(context, provider, todo),
        );
      },
    );
  }

  String _getSortLabel(TodoSort sort) {
    switch (sort) {
      case TodoSort.dateCreated:
        return 'Date Created';
      case TodoSort.dateUpdated:
        return 'Date Updated';
      case TodoSort.dueDate:
        return 'Due Date';
      case TodoSort.priority:
        return 'Priority';
      case TodoSort.alphabetical:
        return 'Alphabetical';
    }
  }

  void _showSortDialog(TodoProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sort By'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: TodoSort.values.map((sort) {
            return RadioListTile<TodoSort>(
              title: Text(_getSortLabel(sort)),
              value: sort,
              groupValue: provider.sort,
              onChanged: (value) {
                if (value != null) {
                  provider.setSort(value);
                  Navigator.of(ctx).pop();
                }
              },
            );
          }).toList(),
        ),
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Todo deleted'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmClearDone() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Completed'),
        content: Text(
            'Delete all ${context.read<TodoProvider>().doneCount} completed todos?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () {
              context.read<TodoProvider>().deleteCompleted();
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Completed todos cleared'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}
