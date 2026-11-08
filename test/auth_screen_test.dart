import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilocano_teatro_master/app/app_theme.dart';
import 'package:ilocano_teatro_master/features/auth/auth_screen.dart';

void main() {
  testWidgets('welcome offers one shared sign-in and sign-up flow', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const AuthScreen()),
    );

    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Sign up'), findsOneWidget);
    expect(find.text('Student access'), findsNothing);
    expect(find.text('Teacher / Reviewer access'), findsNothing);

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('same sign-in for students, teachers'),
      findsOneWidget,
    );

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign up'));
    await tester.pumpAndSettle();
    expect(
      find.text('Create a student account to begin learning.'),
      findsOneWidget,
    );
    expect(find.text('Create account'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
