import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilocano_teatro_master/app/app_routes.dart';
import 'package:ilocano_teatro_master/app/app_theme.dart';
import 'package:ilocano_teatro_master/features/dashboard/data/student_dashboard_data_source.dart';
import 'package:ilocano_teatro_master/features/dashboard/models/student_dashboard_data.dart';
import 'package:ilocano_teatro_master/features/shell/app_shell.dart';
import 'support/fake_identity_repositories.dart';
import 'support/fake_student_learning_repository.dart';
import 'support/fake_curriculum_repository.dart';
import 'support/fake_quiz_repository.dart';

class _EmptyDashboardSource implements StudentDashboardDataSource {
  @override
  Future<StudentDashboardProfile> loadProfile() async =>
      const StudentDashboardProfile(fullName: 'Ignored fallback');

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
  testWidgets('student app shell renders shared identity and empty learning', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AppShell(
          role: AppRole.student,
          dashboardDataSource: _EmptyDashboardSource(),
          learningRepository: FakeStudentLearningRepository(),
          profileRepository: FakeUserProfileRepository(),
          teacherProgressRepository: FakeTeacherStudentProgressRepository(),
          curriculumRepository: FakeCurriculumRepository(),
          quizRepository: FakeQuizRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome back, Test.'), findsOneWidget);
    expect(find.text('Test Student'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
