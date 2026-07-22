import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/category.dart';
import '../../providers/todo_provider.dart';
import '../../core/theme/color_utils.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TodoProvider>();
    final categories = provider.categories;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddDialog(context, provider),
          ),
        ],
      ),
      body: categories.isEmpty
          ? const Center(
              child: Text('No categories yet. Tap + to add one.'),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final cat = categories[index];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _parseColor(cat.color),
                      radius: 16,
                    ),
                    title: Text(cat.name),
                    subtitle: Text('Custom colors: ${cat.customColors.length + 1}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _showEditDialog(context, provider, cat),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          color: theme.colorScheme.error,
                          onPressed: () => _confirmDelete(context, provider, cat),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Color _parseColor(String hex) => parseHexColor(hex);

  void _showAddDialog(BuildContext context, TodoProvider provider) {
    final nameCtrl = TextEditingController();
    String selectedColor = TodoCategory.availableColors[6];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Category'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Category name',
                    hintText: 'Work, Personal, ...',
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Primary Color'),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: TodoCategory.availableColors.map((c) {
                    final isSelected = c == selectedColor;
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedColor = c),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _parseColor(c),
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: Colors.white, width: 3)
                              : null,
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: _parseColor(c).withOpacity(0.5),
                                    blurRadius: 8,
                                  )
                                ]
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (nameCtrl.text.trim().isNotEmpty) {
                  provider.addCategory(TodoCategory(
                    name: nameCtrl.text.trim(),
                    color: selectedColor,
                  ));
                  Navigator.of(ctx).pop();
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(
      BuildContext context, TodoProvider provider, TodoCategory category) {
    final nameCtrl = TextEditingController(text: category.name);
    String selectedColor = category.color;
    List<String> customColors = List.from(category.customColors);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Edit Category'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Category name',
                  ),
                ),
                const SizedBox(height: 16),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Primary Color'),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: TodoCategory.availableColors.map((c) {
                    final isSelected = c == selectedColor;
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedColor = c),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _parseColor(c),
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: Colors.white, width: 3)
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Custom Colors'),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...customColors.map((c) {
                      return Stack(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: _parseColor(c),
                              shape: BoxShape.circle,
                            ),
                          ),
                          Positioned(
                            right: 0,
                            top: 0,
                            child: GestureDetector(
                              onTap: () {
                                setDialogState(() => customColors.remove(c));
                              },
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                    GestureDetector(
                      onTap: () => _addCustomColor(ctx, setDialogState, customColors),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.3),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey),
                        ),
                        child: const Icon(Icons.add, size: 20),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (nameCtrl.text.trim().isNotEmpty) {
                  provider.updateCategory(TodoCategory(
                    id: category.id,
                    name: nameCtrl.text.trim(),
                    color: selectedColor,
                    customColors: customColors,
                  ));
                  Navigator.of(ctx).pop();
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _addCustomColor(BuildContext context, StateSetter setDialogState, List<String> customColors) {
    String newColor = '#FF5722';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState2) => AlertDialog(
          title: const Text('Add Custom Color'),
          content: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: TodoCategory.availableColors.map((c) {
              final isSelected = c == newColor;
              return GestureDetector(
                onTap: () => setDialogState2(() => newColor = c),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _parseColor(c),
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(color: Colors.white, width: 3)
                        : null,
                  ),
                ),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (!customColors.contains(newColor)) {
                  setDialogState(() => customColors.add(newColor));
                }
                Navigator.of(ctx).pop();
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, TodoProvider provider, TodoCategory cat) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text(
            'Delete "${cat.name}"? Todos in this category will be uncategorized.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () {
              if (cat.id != null) provider.deleteCategory(cat.id!);
              Navigator.of(ctx).pop();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
