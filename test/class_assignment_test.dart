import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilocano_teatro_master/app/app_routes.dart';
import 'package:ilocano_teatro_master/app/app_theme.dart';
import 'package:ilocano_teatro_master/features/profile/class_assignment_panel.dart';
import 'package:ilocano_teatro_master/features/profile/class_assignment.dart';
import 'support/fake_identity_repositories.dart';

void main() {
  test('class code model identifies expiry', () {
    expect(
      ActiveClassCode(
        id: 'code',
        code: 'IT-TEST',
        expiresAt: DateTime.now().toUtc().subtract(const Duration(minutes: 1)),
      ).isExpired,
      isTrue,
    );
  });

  testWidgets('student sees unassigned state and joins with a valid code', (
    tester,
  ) async {
    final repository = FakeUserProfileRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ClassAssignmentPanel(
            role: AppRole.student,
            repository: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Unassigned'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'IT-TESTCODE');
    await tester.tap(find.text('Join class'));
    await tester.pumpAndSettle();
    expect(find.text('Test Teacher'), findsOneWidget);
    expect(repository.teacherConnection, isNotNull);
  });

  testWidgets('student shows understandable invalid-code error', (
    tester,
  ) async {
    final repository = FakeUserProfileRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ClassAssignmentPanel(
            role: AppRole.student,
            repository: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'IT-BAD');
    await tester.tap(find.text('Join class'));
    await tester.pumpAndSettle();
    expect(find.textContaining('invalid, expired, or revoked'), findsOneWidget);
  });

  testWidgets('teacher can generate, view, and revoke a class code', (
    tester,
  ) async {
    final repository = FakeUserProfileRepository(role: 'teacher');
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ClassAssignmentPanel(
            role: AppRole.teacher,
            repository: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Generate class code'));
    await tester.pumpAndSettle();
    expect(find.text('IT-TESTCODE'), findsOneWidget);
    await tester.tap(find.text('Revoke'));
    await tester.pumpAndSettle();
    expect(find.text('Generate class code'), findsOneWidget);
    expect(repository.activeClassCode, isNull);
  });
}
