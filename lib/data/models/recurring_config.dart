enum RecurrenceType { none, daily, weekly, monthly, yearly, custom }

class RecurringConfig {
  final RecurrenceType type;
  final int interval;
  final List<int> daysOfWeek;
  final int? dayOfMonth;
  final DateTime? endDate;
  final bool hasEnd;

  RecurringConfig({
    this.type = RecurrenceType.none,
    this.interval = 1,
    this.daysOfWeek = const [],
    this.dayOfMonth,
    this.endDate,
    this.hasEnd = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type.index,
      'interval': interval,
      'daysOfWeek': daysOfWeek.join(','),
      'dayOfMonth': dayOfMonth,
      'endDate': endDate?.millisecondsSinceEpoch,
      'hasEnd': hasEnd ? 1 : 0,
    };
  }

  factory RecurringConfig.fromMap(Map<String, dynamic> map) {
    return RecurringConfig(
      type: RecurrenceType.values[map['type'] as int? ?? 0],
      interval: map['interval'] as int? ?? 1,
      daysOfWeek: (map['daysOfWeek'] as String?)?.split(',').where((d) => d.isNotEmpty).map(int.parse).toList() ?? [],
      dayOfMonth: map['dayOfMonth'] as int?,
      endDate: map['endDate'] != null ? DateTime.fromMillisecondsSinceEpoch(map['endDate'] as int) : null,
      hasEnd: (map['hasEnd'] as int? ?? 0) == 1,
    );
  }

  RecurringConfig copyWith({
    RecurrenceType? type,
    int? interval,
    List<int>? daysOfWeek,
    int? dayOfMonth,
    DateTime? endDate,
    bool? hasEnd,
  }) {
    return RecurringConfig(
      type: type ?? this.type,
      interval: interval ?? this.interval,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      endDate: endDate ?? this.endDate,
      hasEnd: hasEnd ?? this.hasEnd,
    );
  }

  DateTime? getNextOccurrence(DateTime from) {
    if (type == RecurrenceType.none) return null;

    DateTime next;
    switch (type) {
      case RecurrenceType.daily:
        next = from.add(Duration(days: interval));
      case RecurrenceType.weekly:
        next = from.add(Duration(days: 7 * interval));
      case RecurrenceType.monthly:
        next = DateTime(from.year, from.month + interval, from.day);
      case RecurrenceType.yearly:
        next = DateTime(from.year + interval, from.month, from.day);
      case RecurrenceType.custom:
        if (daysOfWeek.isNotEmpty) {
          next = _getNextWeekday(from);
        } else if (dayOfMonth != null) {
          next = _getNextMonthDay(from);
        } else {
          next = from.add(Duration(days: interval));
        }
      case RecurrenceType.none:
        return null;
    }

    if (hasEnd && endDate != null && next.isAfter(endDate!)) {
      return null;
    }

    return next;
  }

  DateTime _getNextWeekday(DateTime from) {
    var next = from.add(const Duration(days: 1));
    while (!daysOfWeek.contains(next.weekday % 7)) {
      next = next.add(const Duration(days: 1));
    }
    return next;
  }

  DateTime _getNextMonthDay(DateTime from) {
    var nextMonth = from.month + 1;
    var nextYear = from.year;
    if (nextMonth > 12) {
      nextMonth = 1;
      nextYear++;
    }
    final maxDay = DateTime(nextYear, nextMonth + 1, 0).day;
    final day = (dayOfMonth ?? 1).clamp(1, maxDay);
    return DateTime(nextYear, nextMonth, day);
  }

  String get label {
    switch (type) {
      case RecurrenceType.none:
        return 'None';
      case RecurrenceType.daily:
        return interval == 1 ? 'Daily' : 'Every $interval days';
      case RecurrenceType.weekly:
        return interval == 1 ? 'Weekly' : 'Every $interval weeks';
      case RecurrenceType.monthly:
        return interval == 1 ? 'Monthly' : 'Every $interval months';
      case RecurrenceType.yearly:
        return interval == 1 ? 'Yearly' : 'Every $interval years';
      case RecurrenceType.custom:
        if (daysOfWeek.isNotEmpty) {
          return 'Custom weekly';
        }
        return 'Custom';
    }
  }
}
