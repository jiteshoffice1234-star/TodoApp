import 'package:flutter/material.dart';
import 'privacy_policy_screen.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Help & About')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Features', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  _featureItem('📝', 'Create, edit, delete, and organize todos'),
                  _featureItem('🎨', '6 visual themes: Light, Dark, Neo, Glass, Minimal, Clay'),
                  _featureItem('🔄', 'Recurring tasks (daily, weekly, monthly, yearly)'),
                  _featureItem('⏰', 'Reminders with push notifications'),
                  _featureItem('🍅', 'Pomodoro timer with session tracking'),
                  _featureItem('📅', 'Calendar view with due date overview'),
                  _featureItem('📊', 'Statistics and charts'),
                  _featureItem('🏷️', 'Tags with custom colors'),
                  _featureItem('📋', 'Subtasks with progress tracking'),
                  _featureItem('🎤', 'Voice input for hands-free creation'),
                  _featureItem('🔍', 'Search, filter, sort, multi-select'),
                  _featureItem('☁️', 'Cloud sync (Firebase — configure your own project)'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Privacy', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  const Text(
                    'All your data is stored locally on your device. '
                    'No analytics, tracking, or telemetry. '
                    'Cloud sync is optional and requires your own Firebase project.',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            color: theme.colorScheme.primaryContainer,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen())),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.privacy_tip, color: theme.colorScheme.onPrimaryContainer),
                    const SizedBox(width: 12),
                    Text('Privacy Policy', style: TextStyle(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w500,
                    )),
                    const Spacer(),
                    Icon(Icons.chevron_right, color: theme.colorScheme.onPrimaryContainer),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Version', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  const Text('3.2.0', style: TextStyle(fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(
                    'Built with Flutter, Dart, and Electron',
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _featureItem(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$emoji  ', style: const TextStyle(fontSize: 16)),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
