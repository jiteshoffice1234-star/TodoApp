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
  @override
  Widget build(BuildContext context) {
    final pomodoro = context.watch<PomodoroProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pomodoro Timer'),
        actions: [
          if (widget.todo != null)
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () => _showTodoInfo(context),
            ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Timer circle
            SizedBox(
              width: 250,
              height: 250,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 250,
                    height: 250,
                    child: CircularProgressIndicator(
                      value: pomodoro.progress,
                      strokeWidth: 12,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        pomodoro.isBreak
                            ? Colors.green
                            : theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        pomodoro.formattedTime,
                        style: theme.textTheme.displayMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
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
            const SizedBox(height: 40),
            // Session indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                final isActive = index < pomodoro.sessionCount % 4;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surfaceContainerHighest,
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),
            Text(
              'Session ${pomodoro.sessionCount + 1}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 40),
            // Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Reset
                IconButton(
                  onPressed: pomodoro.reset,
                  icon: const Icon(Icons.replay),
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
                const SizedBox(width: 16),
                // Play/Pause
                FilledButton.icon(
                  onPressed: pomodoro.isRunning ? pomodoro.pause : pomodoro.resume,
                  icon: Icon(pomodoro.isRunning ? Icons.pause : Icons.play_arrow),
                  label: Text(pomodoro.isRunning ? 'Pause' : 'Start'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                ),
                const SizedBox(width: 16),
                // Skip
                IconButton(
                  onPressed: pomodoro.skip,
                  icon: const Icon(Icons.skip_next),
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
            // Quick start buttons
            if (!pomodoro.isRunning && pomodoro.remainingSeconds == 25 * 60)
              Wrap(
                spacing: 8,
                children: [
                  ActionChip(
                    label: const Text('25 min'),
                    onPressed: () => pomodoro.startWork(todoId: widget.todo?.id),
                  ),
                  ActionChip(
                    label: const Text('15 min'),
                    onPressed: () {
                      pomodoro.startWork(todoId: widget.todo?.id);
                    },
                  ),
                  ActionChip(
                    label: const Text('5 min break'),
                    onPressed: pomodoro.startShortBreak,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _showTodoInfo(BuildContext context) {
    final pomodoro = context.read<PomodoroProvider>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pomodoro Stats'),
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
