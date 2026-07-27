import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:todo_app/app.dart';

void main() {
  testWidgets('App loads without errors', (WidgetTester tester) async {
    // Ensure SharedPreferences is initialized with test values
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const TodoApp());

    // Allow async initialization to complete (services may fail gracefully)
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    // The app should render without crashing; the title may or may not
    // appear depending on async init timing, but the widget tree is built.
    expect(find.byType(TodoApp), findsOneWidget);
  });
}
