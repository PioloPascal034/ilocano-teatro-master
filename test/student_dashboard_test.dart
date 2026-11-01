import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilocano_teatro_master/app/app_routes.dart';
import 'package:ilocano_teatro_master/app/app_theme.dart';
import 'package:ilocano_teatro_master/features/dashboard/data/student_dashboard_data_source.dart';
import 'package:ilocano_teatro_master/features/dashboard/models/student_dashboard_data.dart';
import 'package:ilocano_teatro_master/features/dashboard/student_dashboard.dart';
import 'support/fake_student_dashboard_data_source.dart';

const _profile = StudentDashboardProfile(
  fullName: 'Maria Alvarado',
  yearLevel: 'Grade 10',
  section: 'Section Rizal',
);

const _learning = StudentLearningOverview(
  modules: [
    StudentModuleProgress(
      id: 'module-1',
      title: 'Introduction to Theater',
      description:
          'Discover the language and possibilities of live performance.',
      displayOrder: 1,
      lessonCount: 4,
      completedLessonCount: 1,
    ),
  ],
  completedLessonCount: 1,
  publishedLessonCount: 4,
  averageQuizScore: 82,
  resumeLesson: StudentResumeLesson(
    title: 'Elements of Theater',
    moduleTitle: 'Introduction to Theater',
    lessonOrder: 2,
    moduleOrder: 1,
    moduleLessonCount: 4,
  ),
);

final _drafts = [
  StudentRecentDraft(
    id: 'draft-1',
    title: 'When the River Speaks',
    status: 'draft',
    updatedAt: DateTime(2026, 10, 31),
    centralMessage: 'Courage grows when a community helps one another.',
  ),
];

Widget _dashboard({
  required StudentDashboardDataSource dataSource,
  required ValueChanged<AppDestination> onNavigate,
}) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: StudentDashboard(dataSource: dataSource, onNavigate: onNavigate),
    ),
  ),
);

void main() {
  testWidgets('renders Supabase-backed dashboard values and actions', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1100, 1200);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final destinations = <AppDestination>[];
    final dataSource = FakeStudentDashboardDataSource(
      profile: _profile,
      learning: _learning,
      drafts: _drafts,
    );

    await tester.pumpWidget(
      _dashboard(dataSource: dataSource, onNavigate: destinations.add),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome back, Maria.'), findsOneWidget);
    expect(find.text('25%'), findsWidgets);
    expect(find.text('82%'), findsOneWidget);
    expect(find.text('Introduction to Theater'), findsWidgets);
    expect(find.text('When the River Speaks'), findsOneWidget);
    expect(
      find.text('Lesson 2 of 4 · Introduction to Theater'),
      findsOneWidget,
    );

    await tester.tap(find.text('Continue lesson'));
    expect(destinations.last, AppDestination.learning);

    await tester.ensureVisible(find.text('Build your theme'));
    await tester.tap(find.text('Build your theme'));
    expect(destinations.last, AppDestination.themeBuilder);

    await tester.ensureVisible(find.text('View all drafts'));
    await tester.tap(find.text('View all drafts'));
    expect(destinations.last, AppDestination.drafts);
  });

  testWidgets('shows honest empty states when there is no published content', (
    tester,
  ) async {
    final dataSource = FakeStudentDashboardDataSource(
      profile: _profile,
      learning: const StudentLearningOverview(
        modules: [],
        completedLessonCount: 0,
        publishedLessonCount: 0,
        averageQuizScore: null,
      ),
      drafts: const [],
    );
    await tester.pumpWidget(
      _dashboard(dataSource: dataSource, onNavigate: (_) {}),
    );
    await tester.pumpAndSettle();

    expect(find.text('No published lessons yet'), findsWidgets);
    expect(find.text('No published modules yet'), findsOneWidget);
    expect(find.text('No drafts yet'), findsOneWidget);
    expect(find.text('No quiz scores yet'), findsOneWidget);
  });

  testWidgets('dashboard content fits a narrow Android-sized layout', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final destinations = <AppDestination>[];
    final dataSource = FakeStudentDashboardDataSource(
      profile: _profile,
      learning: _learning,
      drafts: _drafts,
    );

    await tester.pumpWidget(
      _dashboard(dataSource: dataSource, onNavigate: destinations.add),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Build your theme'));
    await tester.pump();

    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Build your theme'));
    expect(destinations.last, AppDestination.themeBuilder);
  });

  testWidgets('database sections expose errors with retry actions', (
    tester,
  ) async {
    final dataSource = FakeStudentDashboardDataSource(
      profile: _profile,
      learning: _learning,
      drafts: _drafts,
      failProfile: true,
      failLearning: true,
      failDrafts: true,
    );
    await tester.pumpWidget(
      _dashboard(dataSource: dataSource, onNavigate: (_) {}),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('We could not load your student profile.'),
      findsOneWidget,
    );
    expect(
      find.text('We could not load your learning progress.'),
      findsOneWidget,
    );
    expect(
      find.text('We could not load your learning modules.'),
      findsOneWidget,
    );
    expect(find.text('We could not load your drafts.'), findsOneWidget);
    expect(find.text('Retry'), findsNWidgets(4));
    expect(find.text('Try again'), findsOneWidget);
  });
}
