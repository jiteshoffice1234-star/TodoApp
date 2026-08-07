import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/todo.dart';
import '../data/repositories/todo_repository.dart';

/// Drives the Android floating task ticker — an always-on-top overlay bar
/// (like the desktop PiP ticker) that shows pending todos even while the
/// app is backgrounded or other apps are open.
///
/// Implementation notes:
///  - Native side: [TickerOverlayService] (Kotlin) + `TYPE_APPLICATION_OVERLAY`
///    window, bridged via `todo_app/ticker_overlay` MethodChannel.
///  - Requires the `SYSTEM_ALERT_WINDOW` ("Display over other apps")
///    permission, requested from the Settings screen.
///  - Runs as a foreground service so it survives the app being backgrounded.
class TickerOverlayService {
  TickerOverlayService._();

  static final TickerOverlayService instance = TickerOverlayService._();

  static const MethodChannel _channel = MethodChannel('todo_app/ticker_overlay');
  static const String _enabledKey = 'ticker_overlay_enabled';

  static const Map<String, String> _priorityIcons = {
    'high': '🔴',
    'medium': '🟠',
    'low': '🟢',
  };

  bool _enabled = false;
  bool _loaded = false;
  String _lastContent = '';
  int? _accentArgb;

  /// Mirrors the native service state so [sync] skips wasted work when the
  /// bar isn't actually visible.
  bool _overlayRunning = false;

  /// Only Android supports the overlay; everything else is a no-op.
  bool get isSupported => !kIsWeb && Platform.isAndroid;

  bool get isEnabled => _enabled;

  Future<void> load() async {
    if (_loaded || !isSupported) return;
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_enabledKey) ?? false;
    _loaded = true;
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    if (!isSupported) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
  }

  Future<bool> hasPermission() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('hasOverlayPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens the system "Display over other apps" settings page.
  Future<void> requestPermission() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('requestOverlayPermission');
    } catch (_) {}
  }

  Future<bool> isRunning() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('isTickerRunning') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Starts the overlay (if enabled + permission granted) with current content.
  Future<void> start() async {
    if (!isSupported || !_enabled) return;
    if (!await hasPermission()) return;
    final content = _buildContent(await TodoRepository().getAll());
    _lastContent = content;
    try {
      await _channel.invokeMethod<void>('startTicker', {
        'content': content,
        if (_accentArgb != null) 'accent': _accentArgb,
      });
      _overlayRunning = true;
    } catch (_) {}
  }

  /// Syncs the overlay bar's accent color to the app theme (ARGB int, same
  /// encoding as Flutter's Color.value). Falls back to the default green
  /// until the theme reports in.
  void applyAccent(int argb) {
    _accentArgb = argb;
    if (!isSupported || !_enabled) return;
    try {
      _channel.invokeMethod<void>('setTickerAccent', {'accent': argb});
    } catch (_) {}
  }

  Future<void> stop() async {
    if (!isSupported) return;
    _lastContent = '';
    _overlayRunning = false;
    try {
      await _channel.invokeMethod<void>('stopTicker');
    } catch (_) {}
  }

  /// Pushes new content to the overlay only when it actually changed
  /// (keeps the scroll animation smooth — same trick as the desktop ticker).
  Future<void> sync(List<Todo> todos) async {
    if (!isSupported || !_enabled || !_overlayRunning) return;
    final content = _buildContent(todos);
    if (content == _lastContent) return;
    _lastContent = content;
    try {
      await _channel.invokeMethod<void>('updateTicker', {'content': content});
    } catch (_) {}
  }

  /// Called on app launch/resume: if the ticker was left enabled, restart it.
  /// When it's already running there's nothing to do — the in-process provider
  /// listener keeps it in sync, and re-reading the whole DB on every resume
  /// would only add waste. This also re-evaluates the permission, which the
  /// user may have granted/revoked in system settings.
  Future<void> restoreIfEnabled() async {
    await load();
    if (!isSupported || !_enabled) return;
    if (!await hasPermission()) return;

    _overlayRunning = await isRunning();
    if (!_overlayRunning) {
      await start();
    }
  }

  /// Builds the ticker text the same way the desktop app does:
  /// priority emoji + title (+ ⚠️ when overdue), for every pending todo.
  String _buildContent(List<Todo> todos) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final pending = todos.where((t) => !t.isDone).toList();
    if (pending.isEmpty) return '✅ All caught up — no pending tasks!';

    final parts = pending.map((t) {
      final icon = _priorityIcons[t.priority] ?? '🎯';
      var item = '$icon ${t.title}';
      final due = t.dueDate;
      final isOverdue = due != null && due.isBefore(today);
      if (isOverdue) item += ' ⚠️';
      return item;
    });

    return parts.join('   ▸   ');
  }
}
