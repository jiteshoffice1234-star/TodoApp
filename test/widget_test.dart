import 'package:flutter_test/flutter_test.dart';

import 'package:todo_app/main.dart';

void main() {
  testWidgets('App loads without errors', (WidgetTester tester) async {
    await tester.pumpWidget(const TodoApp());
    await tester.pump();

    expect(find.text('Todo App'), findsOneWidget);
  });
}
