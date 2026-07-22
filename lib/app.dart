import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'providers/todo_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/pomodoro_provider.dart';
import 'ui/screens/home_screen.dart';

class TodoApp extends StatelessWidget {
  const TodoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TodoProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => PomodoroProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'Todo App',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(accentColor: themeProvider.accentColor),
            darkTheme: AppTheme.dark(accentColor: themeProvider.accentColor),
            themeMode: themeProvider.themeMode,
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
