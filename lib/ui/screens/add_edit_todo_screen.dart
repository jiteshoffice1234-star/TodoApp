import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../data/models/todo.dart';
import '../../data/models/subtask.dart';
import '../../data/models/recurring_config.dart';
import '../../providers/todo_provider.dart';
import '../../core/theme/color_utils.dart';

class AddEditTodoScreen extends StatefulWidget {
  final Todo? todo;

  const AddEditTodoScreen({super.key, this.todo});

  @override
  State<AddEditTodoScreen> createState() => _AddEditTodoScreenState();
}

class _AddEditTodoScreenState extends State<AddEditTodoScreen> {
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _tagCtrl;
  late TextEditingController _subtaskCtrl;
  late String _priority;
  late DateTime? _dueDate;
  late int? _categoryId;
  late List<String> _tags;
  late List<Subtask> _subtasks;
  late RecurringConfig _recurringConfig;
  late bool _hasReminder;
  late DateTime? _reminderAt;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.todo?.title ?? '');
    _descCtrl = TextEditingController(text: widget.todo?.description ?? '');
    _tagCtrl = TextEditingController();
    _subtaskCtrl = TextEditingController();
    _priority = widget.todo?.priority ?? 'medium';
    _dueDate = widget.todo?.dueDate;
    _categoryId = widget.todo?.categoryId;
    _tags = List.from(widget.todo?.tags ?? []);
    _subtasks = List.from(widget.todo?.subtasks ?? []);
    _recurringConfig = widget.todo?.recurringConfig ?? RecurringConfig(type: RecurrenceType.none);
    _hasReminder = widget.todo?.hasReminder ?? false;
    _reminderAt = widget.todo?.reminderAt;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _tagCtrl.dispose();
    _subtaskCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TodoProvider>();
    final categories = provider.categories;
    final theme = Theme.of(context);
    final isEditing = widget.todo != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Todo' : 'New Todo'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'What needs to be done?',
              ),
              autofocus: true,
              maxLength: 200,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Title is required' : null,
            ),
            const SizedBox(height: 16),
            
            // Rich Text Description
            Text('Description', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Add details...',
              ),
              maxLines: 5,
            ),
            const SizedBox(height: 20),
            
            // Priority
            Text('Priority', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'high', label: Text('High')),
                ButtonSegment(value: 'medium', label: Text('Medium')),
                ButtonSegment(value: 'low', label: Text('Low')),
              ],
              selected: {_priority},
              onSelectionChanged: (v) => setState(() => _priority = v.first),
            ),
            const SizedBox(height: 20),
            
            // Due Date
            Text('Due Date', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(
                      _dueDate != null
                          ? DateFormat('MMM d, yyyy').format(_dueDate!)
                          : 'Pick date',
                    ),
                    onPressed: _pickDate,
                  ),
                ),
                if (_dueDate != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() => _dueDate = null),
                  ),
                ],
              ],
            ),
            if (_dueDate != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ActionChip(
                    label: const Text('Today'),
                    onPressed: () =>
                        setState(() => _dueDate = DateTime.now()),
                  ),
                  ActionChip(
                    label: const Text('Tomorrow'),
                    onPressed: () => setState(
                        () => _dueDate = DateTime.now().add(const Duration(days: 1))),
                  ),
                  ActionChip(
                    label: const Text('Next week'),
                    onPressed: () => setState(
                        () => _dueDate = DateTime.now().add(const Duration(days: 7))),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            
            // Category
            Text('Category', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            DropdownButtonFormField<int?>(
              value: _categoryId,
              decoration: const InputDecoration(
                hintText: 'No category',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('None')),
                ...categories.map((c) => DropdownMenuItem(
                      value: c.id,
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: _parseColor(c.color),
                            radius: 6,
                          ),
                          const SizedBox(width: 8),
                          Text(c.name),
                        ],
                      ),
                    )),
              ],
              onChanged: (v) => setState(() => _categoryId = v),
            ),
            const SizedBox(height: 20),
            
            // Tags
            Text('Tags', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tagCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Add a tag',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (value) => _addTag(value),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _addTag(_tagCtrl.text),
                  icon: const Icon(Icons.add_circle),
                ),
              ],
            ),
            if (_tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _tags.map((tag) {
                  return Chip(
                    label: Text(tag),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () => setState(() => _tags.remove(tag)),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 20),
            
            // Subtasks
            Text('Subtasks', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _subtaskCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Add a subtask',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (value) => _addSubtask(value),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _addSubtask(_subtaskCtrl.text),
                  icon: const Icon(Icons.add_circle),
                ),
              ],
            ),
            if (_subtasks.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...List.generate(_subtasks.length, (index) {
                final subtask = _subtasks[index];
                return Card(
                  child: ListTile(
                    leading: Checkbox(
                      value: subtask.isDone,
                      onChanged: (v) {
                        setState(() {
                          _subtasks[index] = subtask.copyWith(isDone: v ?? false);
                        });
                      },
                    ),
                    title: Text(
                      subtask.title,
                      style: TextStyle(
                        decoration: subtask.isDone
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () {
                        setState(() {
                          _subtasks.removeAt(index);
                        });
                      },
                    ),
                  ),
                );
              }),
            ],
            const SizedBox(height: 20),
            
            // Recurring
            Text('Recurring', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            DropdownButtonFormField<RecurrenceType>(
              value: _recurringConfig.type,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
              items: RecurrenceType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(_getRecurrenceLabel(type)),
                );
              }).toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    _recurringConfig = _recurringConfig.copyWith(type: v);
                  });
                }
              },
            ),
            if (_recurringConfig.type != RecurrenceType.none) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Repeat every '),
                  SizedBox(
                    width: 60,
                    child: TextFormField(
                      initialValue: _recurringConfig.interval.toString(),
                      keyboardType: TextInputType.number,
                      onChanged: (v) {
                        final interval = int.tryParse(v) ?? 1;
                        setState(() {
                          _recurringConfig = _recurringConfig.copyWith(interval: interval);
                        });
                      },
                    ),
                  ),
                  const Text(' time(s)'),
                ],
              ),
            ],
            const SizedBox(height: 20),
            
            // Reminder
            SwitchListTile(
              title: const Text('Set Reminder'),
              subtitle: _hasReminder && _reminderAt != null
                  ? Text(DateFormat('MMM d, yyyy HH:mm').format(_reminderAt!))
                  : null,
              value: _hasReminder,
              onChanged: (v) async {
                if (v) {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _dueDate ?? DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(DateTime.now().add(const Duration(hours: 1))),
                    );
                    if (time != null) {
                      setState(() {
                        _hasReminder = true;
                        _reminderAt = DateTime(
                          picked.year,
                          picked.month,
                          picked.day,
                          time.hour,
                          time.minute,
                        );
                      });
                    }
                  }
                } else {
                  setState(() {
                    _hasReminder = false;
                    _reminderAt = null;
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  String _getRecurrenceLabel(RecurrenceType type) {
    switch (type) {
      case RecurrenceType.none:
        return 'None';
      case RecurrenceType.daily:
        return 'Daily';
      case RecurrenceType.weekly:
        return 'Weekly';
      case RecurrenceType.monthly:
        return 'Monthly';
      case RecurrenceType.yearly:
        return 'Yearly';
      case RecurrenceType.custom:
        return 'Custom';
    }
  }

  Color _parseColor(String hex) => parseHexColor(hex);

  void _addTag(String tag) {
    final trimmed = tag.trim();
    if (trimmed.isNotEmpty && !_tags.contains(trimmed)) {
      setState(() {
        _tags.add(trimmed);
        _tagCtrl.clear();
      });
    }
  }

  void _addSubtask(String title) {
    final trimmed = title.trim();
    if (trimmed.isNotEmpty) {
      setState(() {
        _subtasks.add(Subtask(title: trimmed, sortOrder: _subtasks.length));
        _subtaskCtrl.clear();
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<TodoProvider>();
    
    final todo = Todo(
      id: widget.todo?.id,
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      priority: _priority,
      dueDate: _dueDate,
      categoryId: _categoryId,
      isDone: widget.todo?.isDone ?? false,
      tags: _tags,
      attachments: widget.todo?.attachments ?? [],
      recurringConfig: _recurringConfig,
      subtasks: _subtasks,
      hasReminder: _hasReminder,
      reminderAt: _reminderAt,
      sortOrder: widget.todo?.sortOrder ?? 0,
    );
    
    provider.saveTodo(todo);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(widget.todo != null ? 'Todo updated' : 'Todo added'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.of(context).pop();
  }
}
