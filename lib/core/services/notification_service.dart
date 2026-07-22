import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../../data/models/todo.dart';
import '../../data/models/recurring_config.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._init();
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  NotificationService._init();

  Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationAction,
    );
    _initialized = true;
  }

  void _onNotificationAction(NotificationResponse response) {
    if (response.actionId == null) return;
    final todoId = int.tryParse(response.payload ?? '');
    if (todoId == null) return;
    _snoozeCallback?.call(todoId, response.actionId!);
  }

  void Function(int todoId, String action)? _snoozeCallback;

  void setSnoozeCallback(void Function(int todoId, String action) cb) {
    _snoozeCallback = cb;
  }

  void scheduleSnoozedReminder(int todoId, String title, String description, Duration fromNow) {
    final reminderTime = DateTime.now().add(fromNow);
    final tzDateTime = tz.TZDateTime.from(reminderTime, tz.local);

    _plugin.zonedSchedule(
      todoId,
      'Reminder: $title',
      description.isNotEmpty ? description : 'Todo reminder',
      tzDateTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'todo_reminders',
          'Todo Reminders',
          channelDescription: 'Notifications for todo reminders',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> scheduleReminder(Todo todo) async {
    if (!todo.hasReminder || todo.reminderAt == null) return;
    if (todo.reminderAt!.isBefore(DateTime.now())) return;

    final tzDateTime = tz.TZDateTime.from(todo.reminderAt!, tz.local);
    
    await _plugin.zonedSchedule(
      todo.id ?? 0,
      'Reminder: ${todo.title}',
      todo.description.isNotEmpty ? todo.description : 'You have a todo due soon',
      tzDateTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'todo_reminders',
          'Todo Reminders',
          channelDescription: 'Notifications for todo reminders',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelReminder(int todoId) async {
    await _plugin.cancel(todoId);
  }

  Future<void> cancelAllReminders() async {
    await _plugin.cancelAll();
  }

  Future<void> scheduleRecurringReminder(Todo todo) async {
    if (todo.recurringConfig.type == RecurrenceType.none) return;
    if (!todo.hasReminder || todo.reminderAt == null) return;

    final nextDue = todo.recurringConfig.getNextOccurrence(
      todo.dueDate ?? DateTime.now(),
    );
    
    if (nextDue != null) {
      final reminderTime = nextDue.subtract(const Duration(hours: 1));
      if (reminderTime.isAfter(DateTime.now())) {
        final todoWithNewReminder = todo.copyWith(
          reminderAt: reminderTime,
        );
        await scheduleReminder(todoWithNewReminder);
      }
    }
  }
}
