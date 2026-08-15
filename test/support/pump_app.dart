import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps [app] and lets the drift streams deliver their first values.
Future<void> pumpRallyStampApp(WidgetTester tester, Widget app) async {
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}

/// Tears the tree down inside the test body so drift's stream-cleanup timers
/// run before the binding checks for pending timers.
Future<void> closeApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

Future<void> tapTab(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(NavigationDestination, label));
  await tester.pumpAndSettle();
}
