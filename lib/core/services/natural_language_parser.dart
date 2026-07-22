import '../../data/models/todo.dart';
import '../../data/models/recurring_config.dart';

class ParsedTodo {
  final String title;
  final String? priority;
  final DateTime? dueDate;
  final List<String> tags;
  final RecurringConfig? recurring;
  final bool hasReminder;
  final DateTime? reminderAt;

  ParsedTodo({
    required this.title,
    this.priority,
    this.dueDate,
    this.tags = const [],
    this.recurring,
    this.hasReminder = false,
    this.reminderAt,
  });
}

class NaturalLanguageParser {
  static final List<RegExp> _priorityPatterns = [
    RegExp(r'!p1|!high|\bhigh\s+priority\b', caseSensitive: false),
    RegExp(r'!p2|!medium|\bmedium\s+priority\b', caseSensitive: false),
    RegExp(r'!p3|!low|\blow\s+priority\b', caseSensitive: false),
  ];

  static final Map<String, String> _priorityMap = {
    '!p1': 'high', '!high': 'high', 'high priority': 'high',
    '!p2': 'medium', '!medium': 'medium', 'medium priority': 'medium',
    '!p3': 'low', '!low': 'low', 'low priority': 'low',
  };

  static final RegExp _tagPattern = RegExp(r'#(\w[\w\-]*)');
  static final RegExp _datePattern = RegExp(
    r'\b(today|tomorrow|next\s+week|mon|tue|wed|thu|fri|sat|sun|'
    r'monday|tuesday|wednesday|thursday|friday|saturday|sunday|'
    r'(\d{1,2})[/-](\d{1,2})([/-](\d{2,4}))?)\b',
    caseSensitive: false,
  );
  static final RegExp _timePattern = RegExp(
    r'\b(\d{1,2}):(\d{2})\s*(am|pm)?\b|\b(\d{1,2})\s*(am|pm)\b',
    caseSensitive: false,
  );
  static final RegExp _recurringPattern = RegExp(
    r'\b(daily|weekly|monthly|yearly|every\s+day|every\s+week|every\s+month)\b',
    caseSensitive: false,
  );
  static final RegExp _reminderPattern = RegExp(
    r'\b(remind\s+me|reminder|notify|alert)\b',
    caseSensitive: false,
  );

  static ParsedTodo parse(String input) {
    String remaining = input;
    String? priority;
    List<String> tags = [];
    DateTime? dueDate;
    RecurringConfig? recurring;
    bool hasReminder = false;
    DateTime? reminderAt;

    for (final entry in _priorityMap.entries) {
      if (remaining.contains(RegExp(RegExp.escape(entry.key), caseSensitive: false))) {
        priority = entry.value;
        remaining = remaining.replaceAll(RegExp(RegExp.escape(entry.key), caseSensitive: false), '');
        break;
      }
    }
    if (priority == null) {
      for (var i = 0; i < _priorityPatterns.length; i++) {
        final match = _priorityPatterns[i].firstMatch(remaining);
        if (match != null) {
          priority = ['high', 'medium', 'low'][i];
          remaining = remaining.replaceAll(_priorityPatterns[i], '');
          break;
        }
      }
    }

    tags = _tagPattern.allMatches(remaining).map((m) => m.group(1)!).toList();
    remaining = remaining.replaceAll(_tagPattern, '');

    final dateMatch = _datePattern.firstMatch(remaining);
    if (dateMatch != null) {
      dueDate = _parseDate(dateMatch.group(0)!);
      remaining = remaining.replaceRange(dateMatch.start, dateMatch.end, '');
    }

    final timeMatch = _timePattern.firstMatch(remaining);
    if (timeMatch != null && dueDate != null) {
      final parsed = _parseTime(timeMatch.group(0)!);
      if (parsed != null) {
        dueDate = DateTime(
          dueDate.year, dueDate.month, dueDate.day,
          parsed.hour, parsed.minute,
        );
      }
      remaining = remaining.replaceRange(timeMatch.start, timeMatch.end, '');
    }

    final recurMatch = _recurringPattern.firstMatch(remaining);
    if (recurMatch != null) {
      recurring = _parseRecurring(recurMatch.group(0)!);
      remaining = remaining.replaceRange(recurMatch.start, recurMatch.end, '');
    }

    if (_reminderPattern.hasMatch(remaining)) {
      hasReminder = true;
      reminderAt = dueDate ?? DateTime.now().add(const Duration(hours: 1));
      remaining = remaining.replaceAll(_reminderPattern, '');
    }

    final title = remaining.trim().replaceAll(RegExp(r'\s+'), ' ');

    return ParsedTodo(
      title: title,
      priority: priority,
      dueDate: dueDate,
      tags: tags,
      recurring: recurring,
      hasReminder: hasReminder,
      reminderAt: reminderAt,
    );
  }

  static DateTime? _parseDate(String input) {
    final now = DateTime.now();
    switch (input.toLowerCase()) {
      case 'today':
        return DateTime(now.year, now.month, now.day);
      case 'tomorrow':
        return DateTime(now.year, now.month, now.day + 1);
      case 'next week':
        return DateTime(now.year, now.month, now.day + 7);
      case 'mon': case 'monday':
        return _nextWeekday(DateTime.monday);
      case 'tue': case 'tuesday':
        return _nextWeekday(DateTime.tuesday);
      case 'wed': case 'wednesday':
        return _nextWeekday(DateTime.wednesday);
      case 'thu': case 'thursday':
        return _nextWeekday(DateTime.thursday);
      case 'fri': case 'friday':
        return _nextWeekday(DateTime.friday);
      case 'sat': case 'saturday':
        return _nextWeekday(DateTime.saturday);
      case 'sun': case 'sunday':
        return _nextWeekday(DateTime.sunday);
    }
    return null;
  }

  static DateTime _nextWeekday(int target) {
    final now = DateTime.now();
    var daysUntil = target - now.weekday;
    if (daysUntil <= 0) daysUntil += 7;
    return DateTime(now.year, now.month, now.day + daysUntil);
  }

  static _TimeOfDay? _parseTime(String input) {
    final match = RegExp(r'(\d{1,2}):(\d{2})\s*(am|pm)?', caseSensitive: false).firstMatch(input);
    if (match != null) {
      var hour = int.parse(match.group(1)!);
      final minute = int.parse(match.group(2)!);
      final ampm = match.group(3)?.toLowerCase();
      if (ampm == 'pm' && hour < 12) hour += 12;
      if (ampm == 'am' && hour == 12) hour = 0;
      return _TimeOfDay(hour, minute);
    }
    final match2 = RegExp(r'(\d{1,2})\s*(am|pm)', caseSensitive: false).firstMatch(input);
    if (match2 != null) {
      var hour = int.parse(match2.group(1)!);
      final ampm = match2.group(2)?.toLowerCase();
      if (ampm == 'pm' && hour < 12) hour += 12;
      if (ampm == 'am' && hour == 12) hour = 0;
      return _TimeOfDay(hour, 0);
    }
    return null;
  }

  static RecurringConfig? _parseRecurring(String input) {
    switch (input.toLowerCase()) {
      case 'daily': case 'every day':
        return RecurringConfig(type: RecurrenceType.daily);
      case 'weekly': case 'every week':
        return RecurringConfig(type: RecurrenceType.weekly);
      case 'monthly': case 'every month':
        return RecurringConfig(type: RecurrenceType.monthly);
      case 'yearly':
        return RecurringConfig(type: RecurrenceType.yearly);
    }
    return null;
  }
}

class _TimeOfDay {
  final int hour;
  final int minute;
  _TimeOfDay(this.hour, this.minute);
}
