import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilocano_teatro_master/app/app_routes.dart';
import 'package:ilocano_teatro_master/app/app_theme.dart';
import 'package:ilocano_teatro_master/features/dashboard/models/student_dashboard_data.dart';
import 'package:ilocano_teatro_master/features/shell/app_shell.dart';
import 'support/fake_identity_repositories.dart';
import 'support/fake_student_learning_repository.dart';
import 'support/fake_curriculum_repository.dart';
import 'support/fake_quiz_repository.dart';
import 'support/fake_theme_draft_repository.dart';
import 'support/fake_student_dashboard_data_source.dart';
import 'support/fake_teacher_review_repository.dart';

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
          dashboardDataSource: FakeStudentDashboardDataSource(
            profile: const StudentDashboardProfile(
              fullName: 'Ignored fallback',
            ),
          ),
          learningRepository: FakeStudentLearningRepository(),
          profileRepository: FakeUserProfileRepository(),
          teacherProgressRepository: FakeTeacherStudentProgressRepository(),
          curriculumRepository: FakeCurriculumRepository(),
          quizRepository: FakeQuizRepository(),
          themeDraftRepository: FakeThemeDraftRepository(),
          teacherReviewRepository: FakeTeacherReviewRepository(
            assignedStudentIds: const {},
            submissions: const [],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome back, Test.'), findsOneWidget);
    expect(find.text('Test Student'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
