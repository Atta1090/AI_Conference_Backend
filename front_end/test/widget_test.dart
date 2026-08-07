// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:translation/ui/login_screen.dart';

void main() {
  testWidgets('Login screen builds', (WidgetTester tester) async {
    // Build UI without Firebase initialization (only widget construction).
    await tester.pumpWidget(
      const MaterialApp(
        home: LoginScreen(),
      ),
    );

    await tester.pump();

    // Login mode shows 2 fields: email + password.
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Login'), findsWidgets);
  });
}
