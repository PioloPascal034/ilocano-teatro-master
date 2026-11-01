import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilocano_teatro_master/features/teacher/models/teacher_review_models.dart';
import 'package:ilocano_teatro_master/features/teacher/teacher_review_screens.dart';
import 'support/fake_teacher_review_repository.dart';

Widget _page(Widget child) => MaterialApp(
  theme: ThemeData(useMaterial3: true),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  testWidgets(
    'queue limits submissions to assigned students and supports search/status filters',
    (tester) async {
      final repository = FakeTeacherReviewRepository(
        assignedStudentIds: const {'student-assigned'},
        submissions: [
          teacherSubmissionFixture(
            id: 'assigned-1',
            draftId: 'draft-1',
            studentId: 'student-assigned',
            studentName: 'Ari Learner',
            title: 'The Shared River',
          ),
          teacherSubmissionFixture(
            id: 'unassigned-1',
            draftId: 'draft-2',
            studentId: 'student-other',
            studentName: 'Other Student',
            title: 'Other Theme',
          ),
          teacherSubmissionFixture(
            id: 'approved-1',
            draftId: 'draft-3',
            studentId: 'student-assigned',
            studentName: 'Bea Reader',
            title: 'Approved Concept',
            status: 'approved',
            review: SavedSubmissionReview(
              id: 'review-1',
              decision: 'approved',
              comment: 'Saved approval feedback.',
              reviewedAt: DateTime(2026, 10, 30),
              scores: {},
            ),
          ),
        ],
      );
      await tester.pumpWidget(
        _page(
          ReviewQueueScreen(repository: repository, onOpenSubmission: (_) {}),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ari Learner'), findsOneWidget);
      expect(find.text('Other Student'), findsNothing);
      expect(find.text('Approved Concept'), findsNothing);

      await tester.enterText(find.byType(TextField).first, 'River');
      await tester.pumpAndSettle();
      expect(find.text('The Shared River'), findsOneWidget);
      expect(find.text('Ari Learner'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'no match');
      await tester.pumpAndSettle();
      expect(find.text('No submissions match'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, '');
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Approved').last);
      await tester.pumpAndSettle();
      expect(find.text('Approved Concept'), findsOneWidget);
      expect(find.text('Bea Reader'), findsOneWidget);
    },
  );

  testWidgets(
    'submission view reads immutable snapshot and displays prior review history',
    (tester) async {
      final savedReview = SavedSubmissionReview(
        id: 'review-v1',
        decision: 'revision_requested',
        comment: 'Please clarify the final stage image.',
        reviewedAt: DateTime(2026, 10, 29),
        scores: const {'criterion-theme': 2},
      );
      final repository = FakeTeacherReviewRepository(
        assignedStudentIds: const {'student-1'},
        submissions: [
          teacherSubmissionFixture(
            id: 'submission-v2',
            draftId: 'draft-1',
            studentId: 'student-1',
            studentName: 'Student One',
            status: 'revision_requested',
            version: 2,
            review: savedReview,
          ),
        ],
      );
      await tester.pumpWidget(
        _page(
          SubmissionReviewScreen(
            repository: repository,
            submissionId: 'submission-v2',
            onBack: () {},
            onReviewCompleted: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Communities grow through mutual care.'),
        findsOneWidget,
      );
      expect(
        find.text('A leader must decide whether to share scarce water.'),
        findsOneWidget,
      );
      expect(
        find.text('Version 2 · Current · Revision requested · 30 Oct 2026'),
        findsOneWidget,
      );
      expect(
        find.text('Please clarify the final stage image.'),
        findsOneWidget,
      );
      expect(find.text('Theme assessment rubric'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'rubric is required and feedback is saved through repository request',
    (tester) async {
      final repository = FakeTeacherReviewRepository(
        assignedStudentIds: const {'student-1'},
        submissions: [
          teacherSubmissionFixture(
            id: 'submission-1',
            draftId: 'draft-1',
            studentId: 'student-1',
            studentName: 'Student One',
          ),
        ],
      );
      var completed = false;
      await tester.pumpWidget(
        _page(
          SubmissionReviewScreen(
            repository: repository,
            submissionId: 'submission-1',
            onBack: () {},
            onReviewCompleted: () => completed = true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DropdownButtonFormField<int>), findsNWidgets(5));
      await tester.ensureVisible(find.text('Request revision'));
      await tester.tap(find.text('Request revision'));
      await tester.pumpAndSettle();
      expect(repository.savedReviews, isEmpty);
      expect(find.text('Rate this criterion.'), findsWidgets);

      final ratingFields = tester
          .widgetList<DropdownButtonFormField<int>>(
            find.byType(DropdownButtonFormField<int>),
          )
          .toList();
      for (var index = 0; index < ratingFields.length; index++) {
        ratingFields[index].onChanged?.call((index % 4) + 1);
        await tester.pump();
      }
      await tester.enterText(
        find.byType(TextFormField).last,
        'Strengthen the ending for the audience.',
      );
      await tester.ensureVisible(find.text('Request revision'));
      await tester.tap(find.text('Request revision'));
      await tester.pumpAndSettle();
      expect(repository.savedReviews, hasLength(1));
      expect(repository.savedReviews.single.decision, 'revision_requested');
      expect(repository.savedReviews.single.scores.values.toList(), [
        1,
        2,
        3,
        4,
        1,
      ]);
      expect(completed, isTrue);
    },
  );

  testWidgets(
    'approval uses the eligible review workflow and mobile layout stays bounded',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = FakeTeacherReviewRepository(
        assignedStudentIds: const {'student-1'},
        submissions: [
          teacherSubmissionFixture(
            id: 'submission-mobile',
            draftId: 'draft-mobile',
            studentId: 'student-1',
            studentName: 'Student One',
          ),
        ],
      );
      await tester.pumpWidget(
        _page(
          SubmissionReviewScreen(
            repository: repository,
            submissionId: 'submission-mobile',
            onBack: () {},
            onReviewCompleted: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final fields = tester
          .widgetList<DropdownButtonFormField<int>>(
            find.byType(DropdownButtonFormField<int>),
          )
          .toList();
      for (var index = 0; index < fields.length; index++) {
        fields[index].onChanged?.call(4);
        await tester.pump();
      }
      await tester.enterText(
        find.byType(TextFormField).last,
        'Strong concept and staging.',
      );
      await tester.ensureVisible(find.text('Approve submission'));
      await tester.tap(find.text('Approve submission'));
      await tester.pumpAndSettle();
      expect(repository.savedReviews.single.decision, 'approved');
      expect(find.textContaining('Weighted rubric preview:'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'queue displays retryable errors and assigned-student empty state',
    (tester) async {
      final empty = FakeTeacherReviewRepository(
        assignedStudentIds: const {},
        submissions: const [],
      );
      await tester.pumpWidget(
        _page(ReviewQueueScreen(repository: empty, onOpenSubmission: (_) {})),
      );
      await tester.pumpAndSettle();
      expect(find.text('No assigned submissions'), findsOneWidget);

      final failing = FakeTeacherReviewRepository(
        assignedStudentIds: const {},
        submissions: const [],
        failQueue: true,
      );
      await tester.pumpWidget(
        _page(
          ReviewQueueScreen(
            key: const ValueKey('failed-queue'),
            repository: failing,
            onOpenSubmission: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('queue unavailable'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    },
  );

  testWidgets('queue exposes a loading state before the repository resolves', (
    tester,
  ) async {
    final repository = FakeTeacherReviewRepository(
      assignedStudentIds: const {},
      submissions: const [],
    );
    await tester.pumpWidget(
      _page(
        ReviewQueueScreen(repository: repository, onOpenSubmission: (_) {}),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('No assigned submissions'), findsOneWidget);
  });
}
