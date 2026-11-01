import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilocano_teatro_master/app/app_theme.dart';
import 'package:ilocano_teatro_master/app/app_routes.dart';
import 'package:ilocano_teatro_master/features/shell/app_shell.dart';
import 'package:ilocano_teatro_master/features/drafts/data/theme_draft_repository.dart';
import 'support/fake_student_learning_repository.dart';
import 'support/fake_identity_repositories.dart';
import 'support/fake_curriculum_repository.dart';
import 'support/fake_quiz_repository.dart';
import 'support/fake_theme_draft_repository.dart';
import 'support/fake_student_dashboard_data_source.dart';
import 'support/fake_teacher_review_repository.dart';
import 'support/fake_story_vault_repository.dart';

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

void main() {
  Future<void> pumpShell(
    WidgetTester tester, {
    required AppRole role,
    required _RouteObserver observer,
    required Size size,
    FakeThemeDraftRepository? draftRepository,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        navigatorObservers: [observer],
        home: AppShell(
          role: role,
          dashboardDataSource: FakeStudentDashboardDataSource(),
          learningRepository: FakeStudentLearningRepository(),
          profileRepository: FakeUserProfileRepository(
            role: role == AppRole.student ? 'student' : 'teacher',
          ),
          teacherProgressRepository: FakeTeacherStudentProgressRepository(),
          curriculumRepository: FakeCurriculumRepository(),
          quizRepository: FakeQuizRepository(),
          themeDraftRepository: draftRepository ?? FakeThemeDraftRepository(),
          teacherReviewRepository: FakeTeacherReviewRepository(
            assignedStudentIds: const {},
            submissions: const [],
          ),
          storyVaultRepository: FakeStoryVaultRepository(
            stories: [
              storyFixture(
                chapters: [
                  chapterFixture(),
                  chapterFixture(
                    id: 'chapter-2',
                    title: 'Second chapter',
                    order: 2,
                  ),
                ],
              ),
            ],
          ),
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
      await tester.tap(find.text('Overview').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Read chapter').first);
      await tester.pumpAndSettle();
      expect(find.text('Chapter one'), findsOneWidget);
      expect(find.text('Test chapter content.'), findsOneWidget);
      await tester.tap(find.text('Mark as Read'));
      await tester.pumpAndSettle();
      expect(find.text('Chapter marked as read.'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Second chapter'), findsOneWidget);
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

  testWidgets('My Drafts reopens and updates the selected incomplete draft', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = FakeThemeDraftRepository();
    final saved = await repository.saveDraft(
      ThemeDraft(
        id: '',
        title: 'Saved incomplete concept',
        status: 'draft',
        updatedAt: DateTime(2026, 11, 1),
        centralMessage: 'A saved message',
      ),
    );
    await pumpShell(
      tester,
      role: AppRole.student,
      observer: _RouteObserver(),
      size: const Size(1280, 900),
      draftRepository: repository,
    );

    await tester.tap(find.text('My Drafts').first);
    await tester.pumpAndSettle();
    expect(find.text('Continue editing'), findsOneWidget);
    expect(find.text('Submit for review'), findsNothing);
    await tester.tap(find.text('Continue editing'));
    await tester.pumpAndSettle();

    expect(find.text('Saved incomplete concept'), findsOneWidget);
    await tester.tap(find.text('2. Central message'));
    await tester.pumpAndSettle();
    expect(find.text('A saved message'), findsOneWidget);
    await tester.enterText(
      find.byType(TextField).first,
      'Updated saved message',
    );
    await tester.tap(find.text('Save draft'));
    await tester.pumpAndSettle();

    expect(repository.drafts, hasLength(1));
    expect(repository.drafts.single.id, saved.id);
    expect(repository.drafts.single.centralMessage, 'Updated saved message');
    expect(repository.drafts.single.status, 'draft');
    expect(tester.takeException(), isNull);
  });
}
