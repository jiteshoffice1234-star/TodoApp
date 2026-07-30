import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/pomodoro_provider.dart';
import '../../providers/todo_provider.dart';
import '../../data/models/todo.dart';

class PomodoroScreen extends StatefulWidget {
  final Todo? todo;

  const PomodoroScreen({super.key, this.todo});

  @override
  State<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends State<PomodoroScreen> {
  int? _selectedTodoId;
  int _dailyFocusMinutes = 0;

  @override
  void initState() {
    super.initState();
    _selectedTodoId = widget.todo?.id;
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshDaily());
  }

  Future<void> _refreshDaily() async {
    final p = context.read<PomodoroProvider>();
    final mins = await p.getDailyFocusMinutes();
    if (mounted) setState(() => _dailyFocusMinutes = mins);
  }

  @override
  Widget build(BuildContext context) {
    final pomodoro = context.watch<PomodoroProvider>();
    final todoProv = context.watch<TodoProvider>();
    final theme = Theme.of(context);

    final pending = todoProv.todos.where((t) => !t.isDone).toList();
    final goal = pomodoro.dailyFocusGoal;
    final focusPct = goal > 0 ? (_dailyFocusMinutes / goal).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Focus Mode'),
        actions: [
          if (widget.todo != null)
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () => _showTodoInfo(context),
            ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                value: _selectedTodoId,
                decoration: const InputDecoration(
                  labelText: 'Focus on task',
                  prefixIcon: Icon(Icons.touch_app, size: 20),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('No specific task')),
                  ...pending.map((t) => DropdownMenuItem(
                    value: t.id,
                    child: Text(t.title, overflow: TextOverflow.ellipsis),
                  )),
                ],
                onChanged: (v) => setState(() => _selectedTodoId = v),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 250, height: 250,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 250, height: 250,
                      child: CircularProgressIndicator(
                        value: pomodoro.progress,
                        strokeWidth: 12,
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          pomodoro.isBreak ? Colors.green : theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          pomodoro.formattedTime,
                          style: theme.textTheme.displayMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          pomodoro.isBreak ? 'Break Time' : 'Focus Time',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ...List.generate(4, (index) {
                    final isActive = index < pomodoro.sessionCount % 4;
                    return Animate(
                      effects: [
                        ScaleEffect(
                          begin: const Offset(0, 0),
                          end: const Offset(1, 1),
                          duration: 400.ms,
                          curve: Curves.easeOutBack,
                        ),
                        if (isActive)
                          FadeEffect(
                            begin: 0,
                            end: 1,
                            duration: 300.ms,
                          ),
                      ],
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 12, height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isActive ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest,
                        ),
                      ),
                    );
                  }),
                  const SizedBox(width: 12),
                  Text('Session ${pomodoro.sessionCount + 1}',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6))),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: pomodoro.reset,
                    icon: const Icon(Icons.replay),
                    style: IconButton.styleFrom(backgroundColor: theme.colorScheme.surfaceContainerHighest),
                  ),
                  const SizedBox(width: 16),
                  FilledButton.icon(
                    onPressed: pomodoro.isRunning ? pomodoro.pause : pomodoro.resume,
                    icon: Icon(pomodoro.isRunning ? Icons.pause : Icons.play_arrow),
                    label: Text(pomodoro.isRunning ? 'Pause' : 'Start'),
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16)),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    onPressed: pomodoro.stop,
                    icon: const Icon(Icons.stop),
                    style: IconButton.styleFrom(
                      backgroundColor: theme.colorScheme.errorContainer,
                      foregroundColor: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    onPressed: pomodoro.skip,
                    icon: const Icon(Icons.skip_next),
                    style: IconButton.styleFrom(backgroundColor: theme.colorScheme.surfaceContainerHighest),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (pomodoro.isStopped)
                Wrap(
                  spacing: 8,
                  children: [
                    ActionChip(label: const Text('25 min'), onPressed: () => _startFocus(pomodoro, 25)),
                    ActionChip(label: const Text('15 min'), onPressed: () => _startFocus(pomodoro, 15)),
                    ActionChip(label: const Text('5 min break'), onPressed: pomodoro.startShortBreak),
                  ],
                ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Text('🎯', style: TextStyle(fontSize: 20)),
                        const SizedBox(width: 8),
                        Text('Daily Focus Goal', style: theme.textTheme.titleSmall),
                        const Spacer(),
                        Text('$_dailyFocusMinutes / $goal min',
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6))),
                        IconButton(
                          icon: const Icon(Icons.settings, size: 18),
                          onPressed: () => _editFocusGoal(context, pomodoro),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: focusPct,
                        minHeight: 8,
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          focusPct >= 1.0 ? Colors.green : theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    if (focusPct >= 1.0) ...[
                      const SizedBox(height: 8),
                      Text('Goal reached!', style: theme.textTheme.bodySmall?.copyWith(color: Colors.green)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startFocus(PomodoroProvider p, int minutes) {
    p.startWork(todoId: _selectedTodoId, durationMinutes: minutes);
    _refreshDaily();
  }

  void _editFocusGoal(BuildContext context, PomodoroProvider pomodoro) {
    final ctrl = TextEditingController(text: pomodoro.dailyFocusGoal.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Daily Focus Goal'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Minutes per day'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final v = int.tryParse(ctrl.text);
              if (v != null && v > 0) pomodoro.setFocusGoal(v);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showTodoInfo(BuildContext context) {
    final pomodoro = context.read<PomodoroProvider>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Focus Stats'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total Sessions: ${pomodoro.sessionCount}'),
            if (widget.todo != null) ...[
              const SizedBox(height: 8),
              Text('Todo: ${widget.todo!.title}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
