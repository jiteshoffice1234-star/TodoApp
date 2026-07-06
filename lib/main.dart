import 'package:flutter/material.dart';
import 'app.dart';
import 'core/services/widget_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await WidgetService.instance.init();
  await WidgetService.instance.updateWidget();
  runApp(const TodoApp());
}
