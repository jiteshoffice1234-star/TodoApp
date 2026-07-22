import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/database/database_helper.dart';

class PomodoroProvider extends ChangeNotifier {
  static const int workDuration = 25;
  static const int shortBreakDuration = 5;
  static const int longBreakDuration = 15;

  Timer? _timer;
  int _remainingSeconds = workDuration * 60;
  int _totalSeconds = workDuration * 60;
  bool _isRunning = false;
  bool _isBreak = false;
  bool _isStopped = true;
  int _sessionCount = 0;
  int? _currentTodoId;

  int get remainingSeconds => _remainingSeconds;
  int get totalSeconds => _totalSeconds;
  bool get isRunning => _isRunning;
  bool get isBreak => _isBreak;
  bool get isStopped => _isStopped;
  int get sessionCount => _sessionCount;
  int? get currentTodoId => _currentTodoId;

  double get progress => _totalSeconds > 0 ? 1 - (_remainingSeconds / _totalSeconds) : 0;

  String get formattedTime {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void startWork({int? todoId}) {
    _currentTodoId = todoId;
    _isBreak = false;
    _isStopped = false;
    _totalSeconds = workDuration * 60;
    _remainingSeconds = _totalSeconds;
    _startTimer();
  }

  void startShortBreak() {
    _isBreak = true;
    _isStopped = false;
    _totalSeconds = shortBreakDuration * 60;
    _remainingSeconds = _totalSeconds;
    _startTimer();
  }

  void startLongBreak() {
    _isBreak = true;
    _isStopped = false;
    _totalSeconds = longBreakDuration * 60;
    _remainingSeconds = _totalSeconds;
    _startTimer();
  }

  void _startTimer() {
    _isRunning = true;
    notifyListeners();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
        notifyListeners();
      } else {
        _onTimerComplete();
      }
    });
  }

  void pause() {
    _timer?.cancel();
    _isRunning = false;
    notifyListeners();
  }

  void resume() {
    if (!_isRunning && _remainingSeconds > 0) {
      _startTimer();
    }
  }

  void reset() {
    _timer?.cancel();
    _isRunning = false;
    _isBreak = false;
    _remainingSeconds = workDuration * 60;
    _totalSeconds = workDuration * 60;
    notifyListeners();
  }

  void stop() {
    _timer?.cancel();
    _isRunning = false;
    _isStopped = true;
    _isBreak = false;
    _remainingSeconds = workDuration * 60;
    _totalSeconds = workDuration * 60;
    notifyListeners();
  }

  void skip() {
    _timer?.cancel();
    _isRunning = false;
    _onTimerComplete();
  }

  void _onTimerComplete() {
    _timer?.cancel();
    _isRunning = false;

    if (!_isBreak) {
      _sessionCount++;
      if (_currentTodoId != null) {
        _saveSession();
      }
    }
    notifyListeners();
  }

  Future<void> _saveSession() async {
    if (_currentTodoId != null) {
      await DatabaseHelper.instance.savePomodoroSession(
        _currentTodoId!,
        DateTime.now().subtract(Duration(minutes: workDuration)),
        workDuration,
        true,
      );
    }
  }

  Future<int> getTodoPomodoroCount(int todoId) async {
    return await DatabaseHelper.instance.getPomodoroCount(todoId);
  }

  Future<int> getTodoPomodoroMinutes(int todoId) async {
    return await DatabaseHelper.instance.getPomodoroMinutes(todoId);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
