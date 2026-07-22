import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/todo_provider.dart';
import '../../providers/pomodoro_provider.dart';
import '../../data/models/recurring_config.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TodoProvider>();
    final pomodoro = context.watch<PomodoroProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStreakCard(provider, theme),
            const SizedBox(height: 16),
            _buildCompletionChart(provider, theme),
            const SizedBox(height: 16),
            _buildCategoryChart(provider, theme),
            const SizedBox(height: 16),
            _buildSubtaskStats(provider, theme),
            const SizedBox(height: 16),
            _buildRecurringStats(provider, theme),
            const SizedBox(height: 16),
            _buildPomodoroStats(pomodoro, theme),
            const SizedBox(height: 16),
            _buildQuickStats(provider, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildStreakCard(TodoProvider provider, ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.local_fire_department,
                size: 40,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Streak',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '${provider.currentStreak} days',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletionChart(TodoProvider provider, ThemeData theme) {
    final stats = provider.completionStats;
    final completed = stats['completed'] ?? 0;
    final pending = stats['pending'] ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Completion Overview',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 50,
                  sections: [
                    PieChartSectionData(
                      value: completed.toDouble(),
                      title: '$completed',
                      color: Colors.green,
                      radius: 50,
                      titleStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    PieChartSectionData(
                      value: pending.toDouble(),
                      title: '$pending',
                      color: Colors.orange,
                      radius: 50,
                      titleStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegend(Colors.green, 'Completed ($completed)'),
                const SizedBox(width: 20),
                _buildLegend(Colors.orange, 'Pending ($pending)'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(text),
      ],
    );
  }

  Widget _buildCategoryChart(TodoProvider provider, ThemeData theme) {
    final stats = provider.categoryStats;
    
    if (stats.isEmpty) {
      return const SizedBox.shrink();
    }

    final colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.purple,
      Colors.orange,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
    ];

    final sections = <PieChartSectionData>[];
    var i = 0;
    stats.forEach((name, count) {
      sections.add(PieChartSectionData(
        value: count.toDouble(),
        title: '$count',
        color: colors[i % colors.length],
        radius: 40,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ));
      i++;
    });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'By Category',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections: sections,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: stats.entries.toList().asMap().entries.map((entry) {
                final idx = entry.key;
                final e = entry.value;
                return _buildLegend(colors[idx % colors.length], '${e.key} (${e.value})');
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubtaskStats(TodoProvider provider, ThemeData theme) {
    final todosWithSubtasks = provider.todos.where((t) => t.hasSubtasks).toList();
    final totalSubtasks = todosWithSubtasks.fold<int>(0, (sum, t) => sum + t.subtasks.length);
    final completedSubtasks = todosWithSubtasks.fold<int>(0, (sum, t) => sum + t.subtasks.where((s) => s.isDone).length);

    if (todosWithSubtasks.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Subtask Progress',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.checklist, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$completedSubtasks / $totalSubtasks subtasks completed',
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: totalSubtasks > 0 ? completedSubtasks / totalSubtasks : 0,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecurringStats(TodoProvider provider, ThemeData theme) {
    final recurringTodos = provider.todos.where(
      (t) => t.recurringConfig.type != RecurrenceType.none,
    ).toList();

    if (recurringTodos.isEmpty) return const SizedBox.shrink();

    final stats = <String, int>{};
    for (final todo in recurringTodos) {
      final label = todo.recurringConfig.label;
      stats[label] = (stats[label] ?? 0) + 1;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recurring Tasks',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            ...stats.entries.map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.repeat, size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(child: Text(entry.key)),
                  Text(
                    '${entry.value}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildPomodoroStats(PomodoroProvider pomodoro, ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pomodoro Sessions',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  'Sessions',
                  pomodoro.sessionCount,
                  Icons.timer,
                  theme,
                ),
                _buildStatItem(
                  'Focus Time',
                  pomodoro.sessionCount * 25,
                  Icons.access_time,
                  theme,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats(TodoProvider provider, ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Stats',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Total', provider.allCount, Icons.list_alt, theme),
                _buildStatItem('Done', provider.doneCount, Icons.check_circle, theme),
                _buildStatItem('Pending', provider.pendingCount, Icons.pending, theme),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, int count, IconData icon, ThemeData theme) {
    return Column(
      children: [
        Icon(icon, size: 32, color: theme.colorScheme.primary),
        const SizedBox(height: 8),
        Text(
          '$count',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
