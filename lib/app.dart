import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animations/animations.dart';
import 'core/theme/app_theme.dart';
import 'core/services/sync_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/ticker_overlay_service.dart';
import 'providers/todo_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/pomodoro_provider.dart';
import 'ui/screens/home_screen.dart';

class TodoApp extends StatefulWidget {
  const TodoApp({super.key});

  @override
  State<TodoApp> createState() => _TodoAppState();
}

class _TodoAppState extends State<TodoApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initServices();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-sync the floating ticker (permission may have changed in settings,
      // or the overlay may have been stopped while we were away).
      TickerOverlayService.instance.restoreIfEnabled();
    }
  }

  Future<void> _initServices() async {
    try {
      await SyncService.instance.init();
    } catch (_) {}
    NotificationService.instance.setSnoozeCallback((todoId, action) {
      // Handle snooze: this runs in notification callback context
    });

    // Floating task ticker: load the enabled flag and start it after the
    // first frame (the MethodChannel handler only exists once the engine is up).
    TickerOverlayService.instance.load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      TickerOverlayService.instance.restoreIfEnabled();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) {
            final provider = TodoProvider();
            // Push ticker updates whenever todos change (content-diff inside
            // the service keeps the scroll animation smooth).
            provider.addListener(() {
              TickerOverlayService.instance.sync(provider.rawTodos);
            });
            return provider;
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            final themeProvider = ThemeProvider();
            // Keep the floating ticker's accent color in sync with the app.
            themeProvider.addListener(() {
              TickerOverlayService.instance.applyAccent(themeProvider.accentColor.toARGB32());
            });
            return themeProvider;
          },
        ),
        ChangeNotifierProvider(create: (_) => PomodoroProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'Todo App',
            debugShowCheckedModeBanner: false,
            theme: themeProvider.themeData,
            darkTheme: themeProvider.themeData,
            // The theme option determines the brightness (glass/dark = dark,
            // light/neo/minimal/clay = light) — previously hardcoded to light,
            // which made every non-light theme impossible to see.
            themeMode:
                themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
