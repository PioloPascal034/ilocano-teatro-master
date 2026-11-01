import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilocano_teatro_master/app/app_routes.dart';
import 'package:ilocano_teatro_master/app/app_theme.dart';
import 'package:ilocano_teatro_master/features/shell/app_shell.dart';
import 'package:ilocano_teatro_master/features/teacher/data/teacher_student_progress_repository.dart';
import 'package:ilocano_teatro_master/features/quiz/models/quiz_models.dart';
import 'support/fake_student_learning_repository.dart';
import 'support/fake_identity_repositories.dart';
import 'support/fake_curriculum_repository.dart';
import 'support/fake_quiz_repository.dart';
import 'support/fake_theme_draft_repository.dart';
import 'support/fake_student_dashboard_data_source.dart';
import 'support/fake_teacher_review_repository.dart';
import 'support/fake_notification_repository.dart';
import 'support/fake_story_vault_repository.dart';

Future<void> _pumpShell(
  WidgetTester tester,
  AppRole role, {
  Size size = const Size(1280, 900),
  FakeUserProfileRepository? profileRepository,
  FakeStudentLearningRepository? learningRepository,
  FakeQuizRepository? quizRepository,
  FakeTeacherReviewRepository? teacherReviewRepository,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: AppShell(
        role: role,
        dashboardDataSource: FakeStudentDashboardDataSource(),
        learningRepository:
            learningRepository ?? FakeStudentLearningRepository(),
        profileRepository:
            profileRepository ??
            FakeUserProfileRepository(
              role: role == AppRole.student ? 'student' : 'teacher',
            ),
        teacherProgressRepository: FakeTeacherStudentProgressRepository(
          students: const [
            TeacherStudentProgress(
              id: 'assigned-student',
              fullName: 'Assigned Learner',
              completedLessons: 1,
              totalLessons: 5,
              quizAverage: 80,
            ),
          ],
        ),
        curriculumRepository: FakeCurriculumRepository(),
        quizRepository: quizRepository ?? FakeQuizRepository(),
        themeDraftRepository: FakeThemeDraftRepository(),
        teacherReviewRepository:
            teacherReviewRepository ??
            FakeTeacherReviewRepository(
              assignedStudentIds: const {'assigned-learner'},
              submissions: [
                teacherSubmissionFixture(
                  id: 'submission-fixture',
                  draftId: 'draft-fixture',
                  studentId: 'assigned-learner',
                  studentName: 'Ari Learner',
                  title: 'A Test Theme',
                ),
              ],
            ),
        notificationRepository: FakeNotificationRepository(),
        storyVaultRepository: FakeStoryVaultRepository(
          stories: [
            storyFixture(
              title: 'Test cultural story',
              summary: 'A verified story fixture for the Story Vault test.',
              chapters: [chapterFixture()],
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String label) async {
  final target = find.text(label).first;
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('student story, theme, draft, learning, and quiz paths work', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpShell(
      tester,
      AppRole.student,
      learningRepository: FakeStudentLearningRepository(
        includeVerifiedTestLesson: true,
      ),
    );

    await _tap(tester, 'Story Vault');
    expect(find.text('Ilocano Story Vault'), findsOneWidget);
    expect(find.text('Test cultural story'), findsOneWidget);
    await _tap(tester, 'Overview');
    expect(
      find.text('A verified story fixture for the Story Vault test.'),
      findsOneWidget,
    );
    await _tap(tester, 'Use as theme inspiration');
    expect(find.text('Shape your story’s heart.'), findsOneWidget);
    expect(find.text('Test cultural story'), findsWidgets);

    await tester.enterText(find.byType(TextField).first, 'A test theme');
    await _tap(tester, 'Next');
    expect(find.text('Your central message'), findsOneWidget);
    await _tap(tester, '6. Review and save');
    expect(find.text('Review and save'), findsWidgets);
    await _tap(tester, 'Save draft');
    expect(find.text('Draft saved.'), findsOneWidget);

    await _tap(tester, 'My Drafts');
    expect(find.text('My drafts & submissions'), findsOneWidget);
    expect(find.text('A test theme'), findsOneWidget);

    await _tap(tester, 'My Learning');
    expect(find.text('Your learning path'), findsOneWidget);
    await _tap(tester, 'Continue learning');
    expect(find.text('Verified sample lesson'), findsWidgets);
    expect(
      find.text('Test-only source-reviewed lesson fixture.'),
      findsOneWidget,
    );
    expect(find.textContaining('DEMO LESSON ONLY'), findsNothing);
    await _tap(tester, 'Mark as completed');
    expect(find.text('Completed'), findsOneWidget);
    await _tap(tester, 'My Learning');
    expect(find.text('100% complete'), findsOneWidget);
    await _tap(tester, 'My Progress');
    expect(
      find.textContaining('You have completed 1 of 1 available lessons.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'teacher dashboard, queue review, progress, and content paths work',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _pumpShell(tester, AppRole.teacher);

      expect(find.text('REVIEWER OVERVIEW'), findsOneWidget);
      await _tap(tester, 'Open review queue');
      expect(find.text('THEME ASSESSMENTS'), findsOneWidget);
      await _tap(tester, 'A Test Theme');
      expect(find.text('Theme assessment rubric'), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<int>), findsNWidgets(5));
      await tester.ensureVisible(find.text('Request revision'));
      await tester.pumpAndSettle();
      await _tap(tester, 'Request revision');
      expect(find.text('Rate this criterion.'), findsWidgets);

      await _tap(tester, 'Review queue');
      await _tap(tester, 'Student Progress');
      expect(find.text('LEARNING ACTIVITY'), findsOneWidget);
      expect(find.text('Assigned Learner'), findsOneWidget);
      expect(find.text('1 / 5'), findsWidgets);
      await _tap(tester, 'Assigned Learner');
      expect(find.text('Lessons completed: 1 of 5'), findsOneWidget);
      await _tap(tester, 'Close');

      await _tap(tester, 'Learning Content');
      expect(find.text('Learning content'), findsWidgets);
      expect(find.text('Create module'), findsOneWidget);
      await _tap(tester, 'Manage lessons');
      await _tap(tester, 'Preview');
      expect(find.textContaining('LESSON PREVIEW'), findsOneWidget);
      expect(find.text('First lesson content.'), findsOneWidget);
    },
  );

  testWidgets('student story, builder, and drafts fit mobile width', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpShell(tester, AppRole.student, size: const Size(390, 844));

    await _tap(tester, 'Vault');
    expect(tester.takeException(), isNull);
    await _tap(tester, 'Build');
    expect(find.text('STEP 1 OF 6'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump();
    await _tap(tester, 'Drafts');
    expect(find.text('My Drafts'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _tap(tester, 'More');
    await _tap(tester, 'My Progress');
    expect(find.text('MODULE PROGRESS'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _tap(tester, 'More');
    await _tap(tester, 'Notifications');
    expect(find.text('STUDENT UPDATES'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _tap(tester, 'More');
    await _tap(tester, 'Profile');
    expect(find.text('PERSONAL INFORMATION'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'published modules remain visible while demo lessons are withheld',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _pumpShell(tester, AppRole.student);

      await _tap(tester, 'My Learning');
      expect(
        find.text('5 published modules · 0 approved lessons available.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('5 published seed lessons are hidden'),
        findsOneWidget,
      );
      expect(find.text('Introduction to Theater'), findsOneWidget);
      expect(find.textContaining('DEMO LESSON ONLY'), findsNothing);

      await _tap(tester, 'Start learning');
      expect(find.text('Lessons pending editorial review'), findsOneWidget);
      expect(find.textContaining('published seed lesson'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('profile edits refresh shared account identity', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final profile = FakeUserProfileRepository();
    await _pumpShell(tester, AppRole.student, profileRepository: profile);

    await _tap(tester, 'Profile');
    expect(find.text('student@example.test'), findsWidgets);
    expect(find.text('Student'), findsWidgets);
    await _tap(tester, 'Edit profile');
    await tester.enterText(find.byType(TextFormField).first, 'Ari Rivera');
    await _tap(tester, 'Save profile');
    expect(find.text('Profile changes saved.'), findsOneWidget);

    await _tap(tester, 'Dashboard');
    expect(find.text('Welcome back, Ari.'), findsOneWidget);
    expect(find.text('Ari Rivera'), findsOneWidget);
  });

  testWidgets(
    'profile exposes branded account and confirms sign out on mobile',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _pumpShell(tester, AppRole.student, size: const Size(390, 844));

      await _tap(tester, 'More');
      await _tap(tester, 'Profile');
      expect(find.text('Ilocano Teatro Master'), findsOneWidget);
      expect(find.text('Sign Out'), findsOneWidget);
      await tester.tap(find.text('Sign Out'));
      await tester.pumpAndSettle();
      expect(find.text('Sign out?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Sign out?'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'draft header stays compact and actions remain available on mobile',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _pumpShell(tester, AppRole.student, size: const Size(360, 800));

      await _tap(tester, 'Drafts');
      expect(find.text('My Drafts'), findsOneWidget);
      expect(find.text('New Theme'), findsOneWidget);
      expect(find.byTooltip('Refresh drafts'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('My Learning opens the Supabase-backed quiz route', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpShell(tester, AppRole.student);

    await _tap(tester, 'My Learning');
    await _tap(tester, 'Knowledge checks');
    expect(find.text('Theater Basics'), findsOneWidget);
    await _tap(tester, 'Start quiz');
    expect(find.text('Which answer is correct?'), findsOneWidget);
  });

  testWidgets('student progress shows saved quiz attempt statistics', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpShell(
      tester,
      AppRole.student,
      quizRepository: FakeQuizRepository(
        attempts: [
          QuizAttempt(
            id: 'attempt-previous',
            quizId: 'quiz-1',
            score: 82,
            completedAt: DateTime(2026, 10, 31),
          ),
        ],
      ),
    );

    await _tap(tester, 'My Progress');
    expect(find.textContaining('1 completed attempt'), findsOneWidget);
    expect(find.textContaining('82.0%'), findsOneWidget);
    expect(
      find.text(
        'Quiz results will appear here after quiz tracking is implemented.',
      ),
      findsNothing,
    );
  });

  testWidgets('teacher review and content fit mobile width', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpShell(tester, AppRole.teacher, size: const Size(390, 844));

    await _tap(tester, 'Reviews');
    expect(find.text('THEME ASSESSMENTS'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _tap(tester, 'A Test Theme');
    expect(find.text('Theme assessment rubric'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _tap(tester, 'More');
    await _tap(tester, 'Learning Content');
    expect(find.text('Learning content'), findsWidgets);
    expect(find.text('Create module'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _tap(tester, 'More');
    await _tap(tester, 'Profile');
    expect(find.text('Teacher information'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _tap(tester, 'More');
    await _tap(tester, 'Notifications');
    expect(find.text('REVIEWER UPDATES'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
