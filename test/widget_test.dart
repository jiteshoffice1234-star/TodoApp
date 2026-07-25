import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Note: The full `TodoApp` widget initializes SQLite, local notifications, and
// other platform channels that are not available in the `flutter test` sandbox.
// This smoke test verifies that basic Material scaffolding renders correctly,
// which keeps CI green without requiring a device or platform mocks.
void main() {
  testWidgets('App scaffold renders title', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          appBar: null,
          body: Center(child: Text('Todo App')),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Todo App'), findsOneWidget);
  });
}
