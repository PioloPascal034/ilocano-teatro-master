import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilocano_teatro_master/app/app_theme.dart';
import 'package:ilocano_teatro_master/app/app_routes.dart';
import 'package:ilocano_teatro_master/features/dashboard/data/student_dashboard_data_source.dart';
import 'package:ilocano_teatro_master/features/dashboard/models/student_dashboard_data.dart';
import 'package:ilocano_teatro_master/features/shell/app_shell.dart';
import 'support/fake_student_learning_repository.dart';
import 'support/fake_identity_repositories.dart';

class _RouteObserver extends NavigatorObserver {
  int replacements = 0;

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    replacements++;
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }
}

List<double> _scaleValues(WidgetTester tester) => find
    .byType(ScaleTransition)
    .evaluate()
    .map((element) => (element.widget as ScaleTransition).scale.value)
    .toList();

class _FakeDashboardDataSource implements StudentDashboardDataSource {
  @override
  Future<StudentDashboardProfile> loadProfile() async =>
      const StudentDashboardProfile(fullName: 'Maria Alvarado');

  @override
  Future<StudentLearningOverview> loadLearningOverview() async =>
      const StudentLearningOverview(
        modules: [],
        completedLessonCount: 0,
        publishedLessonCount: 0,
        averageQuizScore: null,
      );

  @override
  Future<List<StudentRecentDraft>> loadRecentDrafts() async => const [];
}

void main() {
  Future<void> pumpShell(
    WidgetTester tester, {
    required AppRole role,
    required _RouteObserver observer,
    required Size size,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        navigatorObservers: [observer],
        home: AppShell(
          role: role,
          dashboardDataSource: _FakeDashboardDataSource(),
          learningRepository: FakeStudentLearningRepository(),
          profileRepository: FakeUserProfileRepository(
            role: role == AppRole.student ? 'student' : 'teacher',
          ),
          teacherProgressRepository: FakeTeacherStudentProgressRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> select(
    WidgetTester tester,
    String label,
    String pageTitle,
  ) async {
    final scaleBefore = _scaleValues(tester);
    await tester.tap(find.text(label).first);
    await tester.pumpAndSettle();
    expect(find.text(pageTitle), findsWidgets);
    expect(_scaleValues(tester), scaleBefore);
    await tester.pump(const Duration(milliseconds: 300));
    expect(_scaleValues(tester), scaleBefore);
  }

  testWidgets(
    'student navigation switches content without replacing the shell',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final observer = _RouteObserver();
      await pumpShell(
        tester,
        role: AppRole.student,
        observer: observer,
        size: const Size(1280, 900),
      );

      await select(tester, 'My Learning', 'Your learning path');
      await select(tester, 'Story Vault', 'Ilocano Story Vault');
      await select(tester, 'Theme Builder', 'Shape your story’s heart.');
      await select(tester, 'My Drafts', 'My drafts & submissions');
      await select(tester, 'Dashboard', 'STUDENT SPACE');

      expect(observer.replacements, 0);
    },
  );

  testWidgets(
    'teacher navigation switches content without replacing the shell',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final observer = _RouteObserver();
      await pumpShell(
        tester,
        role: AppRole.teacher,
        observer: observer,
        size: const Size(1280, 900),
      );

      await select(tester, 'Review Queue', 'Review queue');
      await select(tester, 'Student Progress', 'Student progress');
      expect(find.text('No students assigned yet'), findsOneWidget);
      await select(tester, 'Learning Content', 'Learning content');
      await select(tester, 'Dashboard', 'Open review queue');

      expect(observer.replacements, 0);
    },
  );

  testWidgets('mobile bottom navigation switches pages without scaling', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final observer = _RouteObserver();
    await pumpShell(
      tester,
      role: AppRole.student,
      observer: observer,
      size: const Size(390, 844),
    );

    await select(tester, 'Learn', 'Your learning path');
    await select(tester, 'Vault', 'Ilocano Story Vault');

    expect(observer.replacements, 0);
  });
}
