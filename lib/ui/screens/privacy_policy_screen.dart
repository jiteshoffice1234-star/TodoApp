import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Privacy Policy', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text('Last updated: July 2026', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 16),
                  _section(theme, '1. Data Collection', 'This application does NOT collect, store, or transmit any personal data. All data you create (todos, settings, tags) is stored exclusively on your local device.'),
                  _section(theme, '2. Local Storage', 'Data is stored in a local SQLite database (Flutter) or JSON file (Electron) on your device. No cloud storage is used unless you explicitly configure your own Firebase project for cloud sync.'),
                  _section(theme, '3. Permissions', 'Microphone access is requested ONLY when you use the voice input feature. Audio is processed on-device via Google Speech Services and is not transmitted to any third-party server by this app.'),
                  _section(theme, '4. Third-Party Services', 'This app does not integrate any analytics, advertising, or tracking services. Optional Firebase Cloud Sync requires you to provide your own Firebase project credentials.'),
                  _section(theme, '5. Data Security', 'All data remains on your device under your control. No encryption is applied to local storage since data never leaves your device. You can export or delete your data at any time.'),
                  _section(theme, '6. Changes', 'This privacy policy may be updated occasionally. Any changes will be reflected in the app.'),
                  _section(theme, '7. Contact', 'For questions about this privacy policy, open an issue on the GitHub repository.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(ThemeData theme, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(body, style: const TextStyle(fontSize: 14, height: 1.5)),
        ],
      ),
    );
  }
}
