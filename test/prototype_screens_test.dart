import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilocano_teatro_master/app/app_routes.dart';
import 'package:ilocano_teatro_master/app/app_theme.dart';
import 'package:ilocano_teatro_master/features/dashboard/data/student_dashboard_data_source.dart';
import 'package:ilocano_teatro_master/features/dashboard/models/student_dashboard_data.dart';
import 'package:ilocano_teatro_master/features/shell/app_shell.dart';
import 'package:ilocano_teatro_master/features/teacher/data/teacher_student_progress_repository.dart';
import 'support/fake_student_learning_repository.dart';
import 'support/fake_identity_repositories.dart';

class _EmptyDashboardDataSource implements StudentDashboardDataSource {
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

Future<void> _pumpShell(
  WidgetTester tester,
  AppRole role, {
  Size size = const Size(1280, 900),
  FakeUserProfileRepository? profileRepository,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: AppShell(
        role: role,
        dashboardDataSource: _EmptyDashboardDataSource(),
        learningRepository: FakeStudentLearningRepository(),
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
    await _pumpShell(tester, AppRole.student);

    await _tap(tester, 'Story Vault');
    expect(find.text('Ilocano Story Vault'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Angalo');
    await tester.pumpAndSettle();
    expect(find.text('Angalo'), findsWidgets);
    expect(find.text('Biag ni Lam-ang'), findsNothing);
    await _tap(tester, 'Read story');
    expect(
      find.text(
        'A creation legend about the giant Angalo and the shaping of the world.',
      ),
      findsOneWidget,
    );
    await _tap(tester, 'Use as theme inspiration');
    expect(find.text('Shape your story’s heart.'), findsOneWidget);
    expect(find.text('Angalo'), findsOneWidget);

    await _tap(tester, 'Next');
    expect(find.text('Your central message'), findsOneWidget);
    await _tap(tester, 'Review & Save');
    expect(find.text('Your theater concept'), findsOneWidget);
    await _tap(tester, 'Save draft');
    expect(find.text('Save this draft in demo mode?'), findsOneWidget);
    await _tap(tester, 'Keep editing');

    await _tap(tester, 'My Drafts');
    expect(find.text('My drafts & submissions'), findsOneWidget);
    await _tap(tester, 'View details');
    expect(find.text('Student concept'), findsOneWidget);
    expect(find.text('Reviewer feedback'), findsOneWidget);

    await _tap(tester, 'My Learning');
    expect(find.text('Your learning path'), findsOneWidget);
    await _tap(tester, 'Continue learning');
    expect(find.text('What Is Theater?'), findsWidgets);
    expect(
      find.textContaining('DEMO LESSON ONLY: Replace with teacher-approved'),
      findsOneWidget,
    );
    await _tap(tester, 'Mark as completed');
    expect(find.text('Lesson completion saved.'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    await _tap(tester, 'My Learning');
    expect(find.text('100% complete'), findsOneWidget);
    await _tap(tester, 'My Progress');
    expect(
      find.textContaining('You have completed 1 of 5 published lessons.'),
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
      await _tap(tester, 'When the River Speaks');
      expect(find.text('Theme assessment rubric'), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<int>), findsNWidgets(5));
      await tester.ensureVisible(find.text('Request revision'));
      await tester.pumpAndSettle();
      await _tap(tester, 'Request revision');
      expect(find.text('Score this criterion.'), findsWidgets);

      await _tap(tester, 'Review queue');
      await _tap(tester, 'Student Progress');
      expect(find.text('LEARNING ACTIVITY'), findsOneWidget);
      expect(find.text('Assigned Learner'), findsOneWidget);
      expect(find.text('1 / 5'), findsWidgets);
      await _tap(tester, 'Assigned Learner');
      expect(find.text('Lessons completed: 1 of 5'), findsOneWidget);
      await _tap(tester, 'Close');

      await _tap(tester, 'Learning Content');
      expect(find.text('APPROVED CURRICULUM · DEMO DATA'), findsOneWidget);
      await _tap(tester, 'View module');
      expect(find.text('LESSON PREVIEW'), findsOneWidget);
      await _tap(tester, 'Roles in a Theater Production');
      expect(find.text('Roles in a Theater Production'), findsWidgets);
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
    expect(find.text('My drafts & submissions'), findsOneWidget);
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

  testWidgets('teacher review and content fit mobile width', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpShell(tester, AppRole.teacher, size: const Size(390, 844));

    await _tap(tester, 'Reviews');
    expect(find.text('THEME ASSESSMENTS'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _tap(tester, 'When the River Speaks');
    expect(find.text('Theme assessment rubric'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _tap(tester, 'More');
    await _tap(tester, 'Learning Content');
    expect(find.textContaining('APPROVED CURRICULUM'), findsOneWidget);
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
