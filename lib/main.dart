import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'core/services/notification_service.dart';
import 'core/services/widget_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    try {
      await NotificationService.instance.init();
      await WidgetService.instance.init();
    } catch (e) {
      debugPrint('Native service init failed: $e');
    }
  }

  runApp(const TodoApp());
}
