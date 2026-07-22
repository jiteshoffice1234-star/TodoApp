import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Theme section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Appearance',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  // Theme mode
                  ListTile(
                    leading: Icon(
                      themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                    ),
                    title: const Text('Theme Mode'),
                    subtitle: Text(
                      themeProvider.isDarkMode ? 'Dark' : 'Light',
                    ),
                    trailing: Switch(
                      value: themeProvider.isDarkMode,
                      onChanged: (_) => themeProvider.toggleTheme(),
                    ),
                  ),
                  const Divider(),
                  // Accent color
                  ListTile(
                    leading: const Icon(Icons.palette),
                    title: const Text('Accent Color'),
                    subtitle: const Text('Choose your accent color'),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ThemeProvider.availableColors.map((color) {
                      final isSelected = themeProvider.accentColor == color;
                      return GestureDetector(
                        onTap: () => themeProvider.setAccentColor(color),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(color: Colors.white, width: 3)
                                : null,
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: color.withOpacity(0.5),
                                      blurRadius: 8,
                                    )
                                  ]
                                : null,
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, color: Colors.white, size: 20)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // About section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'About',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  const ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('Version'),
                    subtitle: Text('3.0.0'),
                  ),
                  const ListTile(
                    leading: Icon(Icons.star_outline),
                    title: Text('Features'),
                    subtitle: Text(
                      'Recurring tasks, Subtasks, Calendar view, Pomodoro timer, '
                      'Multi-select, Rich text, Customizable themes',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
