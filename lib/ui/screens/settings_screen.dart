import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/ticker_overlay_service.dart';
import '../../core/services/notification_service.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;

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
                  Text(
                    'Theme',
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ThemeOption.values.map((option) {
                      final isSelected = themeProvider.themeOption == option;
                      return ChoiceChip(
                        label: Text('${option.emoji} ${option.label}'),
                        selected: isSelected,
                        onSelected: (_) => themeProvider.setTheme(option),
                        showCheckmark: false,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  ListTile(
                    leading: const Icon(Icons.palette),
                    title: const Text('Accent Color'),
                    subtitle: const Text('Only for Light/Dark themes'),
                    contentPadding: EdgeInsets.zero,
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
          // Floating task ticker (Android only)
          if (TickerOverlayService.instance.isSupported) ...[const _TickerOverlaySection()],
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
                    subtitle: Text('3.3.0'),
                  ),
                  const ListTile(
                    leading: Icon(Icons.star_outline),
                    title: Text('Features'),
                    subtitle: Text(
                      '6 themes, Recurring tasks, Subtasks, Calendar view, Pomodoro timer, '
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

/// Settings section for the Android always-on-top floating task ticker.
class _TickerOverlaySection extends StatefulWidget {
  const _TickerOverlaySection();

  @override
  State<_TickerOverlaySection> createState() => _TickerOverlaySectionState();
}

class _TickerOverlaySectionState extends State<_TickerOverlaySection>
    with WidgetsBindingObserver {
  bool _loading = true;
  bool _enabled = false;
  bool _permissionGranted = false;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Returning from the system "Display over other apps" settings page.
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final service = TickerOverlayService.instance;
    await service.load();
    final granted = await service.hasPermission();
    final running = await service.isRunning();
    if (!mounted) return;
    setState(() {
      _enabled = service.isEnabled;
      _permissionGranted = granted;
      _running = running;
      _loading = false;
    });
  }

  Future<void> _onEnabledChanged(bool value) async {
    final service = TickerOverlayService.instance;
    setState(() => _enabled = value);
    if (value) {
      await service.setEnabled(true);
      if (!await service.hasPermission()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Grant "Display over other apps" permission to show the floating ticker',
              ),
            );
          );
        }
        await service.requestPermission();
      } else {
        await service.start();
        // Optimistic: the native service attaches slightly after the channel
        // call returns, so show it as active right away.
        if (mounted) setState(() => _running = true);
        // Best effort: keeps the foreground-service notification visible
        // (Android 13+).
        await NotificationService.instance.requestPermission();
        // Give the native service a moment to attach before re-checking.
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    } else {
      await service.setEnabled(false);
      await service.stop();
    }
    _refresh();
  }

  Future<void> _openPermissionSettings() async {
    await TickerOverlayService.instance.requestPermission();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Floating Task Ticker', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Shows your pending tasks in an always-on-top bar, even while '
              'using other apps',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enable ticker'),
              subtitle: Text(
                _loading
                    ? '…'
                    : _enabled
                        ? (_running ? 'Active — showing pending tasks' : 'Starting…')
                        : 'Off',
              ),
              value: _enabled,
              onChanged: _onEnabledChanged,
            ),
            if (_enabled) ...[const Divider(), const SizedBox(height: 4)],
            if (_enabled) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  _permissionGranted ? Icons.check_circle : Icons.warning_amber,
                  color: _permissionGranted
                      ? Colors.green
                      : theme.colorScheme.error,
                ),
                title: Text(
                  _permissionGranted
                      ? 'Overlay permission granted'
                      : 'Needs "Display over other apps" permission',
                ),
                trailing: TextButton(
                  onPressed: _openPermissionSettings,
                  child: const Text('Manage'),
                ),
              ),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.info_outline),
                title: Text('Tip: long-press the ticker bar to stop it'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
