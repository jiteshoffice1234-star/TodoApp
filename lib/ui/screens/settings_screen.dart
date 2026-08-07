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

  // Customization settings
  double _fontSize = 15;
  int _accentColor = 0xFF00FFCC.toInt();
  int _bgColor = 0xFF1A1A2E.toInt();
  double _bgAlpha = 0.9;
  bool _isTop = true;
  double _height = 64;

  static const List<Color> _accentPresets = [
    Color(0xFF00FFCC),
    Color(0xFF1976D2),
    Color(0xFF388E3C),
    Color(0xFFD32F2F),
    Color(0xFFFF9800),
    Color(0xFF7B1FA2),
  ];

  static const List<Color> _bgPresets = [
    Color(0xFF1A1A2E),
    Color(0xFF0D1117),
    Color(0xFF1E1E2E),
    Color(0xFF2D2D3D),
    Color(0xFF000000),
    Color(0xFF1A1A1A),
  ];

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
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final service = TickerOverlayService.instance;
    await service.load();
    final granted = await service.hasPermission();
    final running = await service.isRunning();
    final settings = await service.getSettings();
    if (!mounted) return;
    setState(() {
      _enabled = service.isEnabled;
      _permissionGranted = granted;
      _running = running;
      _loading = false;
      // Load settings
      _fontSize = (settings['fontSize'] as num?)?.toDouble() ?? 15;
      _accentColor = settings['accentColor'] as int? ?? 0xFF00FFCC.toInt();
      _bgColor = settings['bgColor'] as int? ?? 0xFF1A1A2E.toInt();
      _bgAlpha = (settings['bgAlpha'] as num?)?.toDouble() ?? 0.9;
      _isTop = settings['isTop'] as bool? ?? true;
      _height = (settings['height'] as num?)?.toDouble() ?? 64;
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
            ),
          );
        }
        await service.requestPermission();
      } else {
        await service.start();
        if (mounted) setState(() => _running = true);
        await NotificationService.instance.requestPermission();
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
              'using other apps. Long-press the ticker bar for quick settings.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enable ticker'),
              subtitle: Text(
                _loading
                    ? '...'
                    : _enabled
                        ? (_running ? 'Active - showing pending tasks' : 'Starting...')
                        : 'Off',
              ),
              value: _enabled,
              onChanged: _onEnabledChanged,
            ),
            if (_enabled) ...[const Divider(), const SizedBox(height: 4)],
            if (_enabled) ...[
              // Permission status
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
              const Divider(),
              // --- CUSTOMIZATION SECTION ---
              Text('Customization', style: theme.textTheme.titleSmall),
              const SizedBox(height: 12),

              // Font size
              Row(
                children: [
                  const Icon(Icons.text_fields, size: 20),
                  const SizedBox(width: 8),
                  const Text('Font size'),
                  Expanded(
                    child: Slider(
                      value: _fontSize,
                      min: 8,
                      max: 30,
                      divisions: 22,
                      label: '${_fontSize.round()}sp',
                      onChanged: (v) {
                        setState(() => _fontSize = v);
                        TickerOverlayService.instance.setFontSize(v);
                      },
                    ),
                  ),
                  Text('${_fontSize.round()}sp', style: theme.textTheme.bodySmall),
                ],
              ),

              // Height
              Row(
                children: [
                  const Icon(Icons.height, size: 20),
                  const SizedBox(width: 8),
                  const Text('Height'),
                  Expanded(
                    child: Slider(
                      value: _height,
                      min: 40,
                      max: 120,
                      divisions: 80,
                      label: '${_height.round()}dp',
                      onChanged: (v) {
                        setState(() => _height = v);
                        TickerOverlayService.instance.setHeight(v);
                      },
                    ),
                  ),
                  Text('${_height.round()}dp', style: theme.textTheme.bodySmall),
                ],
              ),

              // Opacity
              Row(
                children: [
                  const Icon(Icons.opacity, size: 20),
                  const SizedBox(width: 8),
                  const Text('Opacity'),
                  Expanded(
                    child: Slider(
                      value: _bgAlpha,
                      min: 0.3,
                      max: 1.0,
                      divisions: 7,
                      label: '${(_bgAlpha * 100).round()}%',
                      onChanged: (v) {
                        setState(() => _bgAlpha = v);
                        TickerOverlayService.instance.setBgOpacity(v);
                      },
                    ),
                  ),
                  Text('${(_bgAlpha * 100).round()}%', style: theme.textTheme.bodySmall),
                ],
              ),

              // Position toggle
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Position at top'),
                subtitle: Text(_isTop ? 'Top of screen' : 'Bottom of screen'),
                value: _isTop,
                onChanged: (v) {
                  setState(() => _isTop = v);
                  TickerOverlayService.instance.setPosition(v);
                },
              ),

              const SizedBox(height: 8),

              // Accent color
              Text('Accent color', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _accentPresets.map((c) {
                  final isSelected = _accentColor == c.value;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _accentColor = c.value);
                      TickerOverlayService.instance.applyAccent(c.value);
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.white, width: 3)
                            : null,
                        boxShadow: isSelected
                            ? [BoxShadow(color: c.withOpacity(0.5), blurRadius: 8)]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 18)
                          : null,
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 12),

              // Background color
              Text('Background color', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _bgPresets.map((c) {
                  final isSelected = _bgColor == c.value;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _bgColor = c.value);
                      TickerOverlayService.instance.setBgColor(c.value);
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.white, width: 3)
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 18)
                          : null,
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),
              const Divider(),

              // Tips
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.info_outline),
                title: Text('Tips'),
                subtitle: Text(
                  'Long-press the ticker bar for a popup menu with quick settings. '
                  'Drag to reposition it anywhere on screen.'
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
