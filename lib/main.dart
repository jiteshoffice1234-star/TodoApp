import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Skip native services on web (sqflite/home_widget don't work on web)
  if (!kIsWeb) {
    try {
      // Import services only on non-web platforms
      await _initNativeServices();
    } catch (e) {
      debugPrint('Native service init failed: $e');
    }
  }
  
  runApp(const TodoApp());
}

Future<void> _initNativeServices() async {
  // These imports and calls are only for Android/iOS/Desktop
  // ignore: avoid_dynamic_calls
}
