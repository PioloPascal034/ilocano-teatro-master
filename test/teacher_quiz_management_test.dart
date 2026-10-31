import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilocano_teatro_master/app/app_theme.dart';
import 'package:ilocano_teatro_master/features/quiz/models/quiz_management_models.dart';
import 'package:ilocano_teatro_master/features/quiz/teacher_quiz_management_screen.dart';
import 'support/fake_quiz_management_repository.dart';

Future<void> pumpScreen(
  WidgetTester tester,
  FakeQuizManagementRepository repo, {
  Size size = const Size(1000, 850),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: TeacherQuizManagementScreen(
              moduleId: 'module-1',
              repository: repo,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tapText(WidgetTester tester, String text) async {
  final target = find.text(text).first;
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Curriculum Editor gets create controls; ordinary teacher is read-only',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final editor = FakeQuizManagementRepository();
      await pumpScreen(tester, editor);
      expect(find.text('Create quiz'), findsOneWidget);
      final reader = FakeQuizManagementRepository(editor: false);
      reader.quizzes.add(
        const ManagedQuiz(
          id: 'published',
          moduleId: 'module-1',
          title: 'Published quiz',
          description: '',
          passingScore: 70,
          isPublished: true,
        ),
      );
      await pumpScreen(tester, reader);
      expect(find.text('Create quiz'), findsNothing);
      expect(find.text('Published quiz'), findsOneWidget);
      expect(find.text('View'), findsOneWidget);
      expect(find.text('Manage'), findsNothing);
    },
  );

  testWidgets('creates an unpublished quiz and edits metadata', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = FakeQuizManagementRepository();
    await pumpScreen(tester, repo);
    await tapText(tester, 'Create quiz');
    await tester.enterText(find.byType(TextFormField).at(0), 'Stage Quiz');
    await tester.enterText(find.byType(TextFormField).at(1), 'Quiz overview');
    await tester.enterText(find.byType(TextFormField).at(2), '80');
    await tapText(tester, 'Save quiz');
    expect(repo.quizzes.single.isPublished, isFalse);
    expect(find.text('Stage Quiz'), findsOneWidget);
    await tapText(tester, 'Manage');
    await tapText(tester, 'Edit quiz details');
    await tester.enterText(find.byType(TextFormField).at(0), 'Updated quiz');
    await tapText(tester, 'Save changes');
    expect(find.text('Updated quiz'), findsNWidgets(2));
  });

  testWidgets(
    'question form requires one selected correct option and saves options',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = FakeQuizManagementRepository();
      repo.quizzes.add(
        const ManagedQuiz(
          id: 'qz',
          moduleId: 'module-1',
          title: 'Quiz',
          description: '',
          passingScore: 70,
          isPublished: false,
        ),
      );
      await pumpScreen(tester, repo);
      await tapText(tester, 'Manage');
      await tapText(tester, 'Add question');
      await tester.enterText(find.byType(TextFormField).at(0), 'Question?');
      await tester.enterText(find.byType(TextFormField).at(1), 'Because');
      await tester.enterText(find.byType(TextFormField).at(2), 'Correct');
      await tester.enterText(find.byType(TextFormField).at(3), 'Incorrect');
      await tapText(tester, 'Save question');
      final question = repo.questions['qz']!.single;
      expect(question.options, hasLength(2));
      expect(
        question.options.where((option) => option.isCorrect == true),
        hasLength(1),
      );
    },
  );

  testWidgets(
    'publish asks confirmation and database validation errors are visible',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = FakeQuizManagementRepository();
      repo.quizzes.add(
        const ManagedQuiz(
          id: 'qz',
          moduleId: 'module-1',
          title: 'Quiz',
          description: '',
          passingScore: 70,
          isPublished: false,
        ),
      );
      await pumpScreen(tester, repo);
      await tapText(tester, 'Publish');
      expect(find.text('Publish quiz?'), findsOneWidget);
      await tapText(tester, 'Publish quiz');
      expect(repo.quizzes.single.isPublished, isFalse);
      expect(find.textContaining('at least two options'), findsOneWidget);
    },
  );

  testWidgets('attempt-locked content shows database rejection', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = FakeQuizManagementRepository();
    repo.lockEdits = true;
    repo.quizzes.add(
      const ManagedQuiz(
        id: 'qz',
        moduleId: 'module-1',
        title: 'Quiz',
        description: '',
        passingScore: 70,
        isPublished: false,
      ),
    );
    await pumpScreen(tester, repo);
    await tapText(tester, 'Manage');
    await tapText(tester, 'Add question');
    await tester.enterText(find.byType(TextFormField).at(0), 'Question');
    await tester.enterText(find.byType(TextFormField).at(2), 'Option A');
    await tester.enterText(find.byType(TextFormField).at(3), 'Option B');
    await tapText(tester, 'Save question');
    expect(
      find.textContaining('locked after the first attempt'),
      findsOneWidget,
    );
  });

  testWidgets(
    'question sequence can be sent through complete reorder request',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = FakeQuizManagementRepository();
      const quiz = ManagedQuiz(
        id: 'qz',
        moduleId: 'module-1',
        title: 'Quiz',
        description: '',
        passingScore: 70,
        isPublished: false,
      );
      repo.quizzes.add(quiz);
      repo.questions['qz'] = [
        const ManagedQuizQuestion(
          id: 'one',
          quizId: 'qz',
          text: 'First',
          explanation: '',
          order: 1,
          options: [],
        ),
        const ManagedQuizQuestion(
          id: 'two',
          quizId: 'qz',
          text: 'Second',
          explanation: '',
          order: 2,
          options: [],
        ),
      ];
      await pumpScreen(tester, repo);
      await tapText(tester, 'Manage');
      await tester.tap(find.byTooltip('Move question up').last);
      await tester.pumpAndSettle();
      expect(repo.reorderRequest, ['two', 'one']);
    },
  );

  testWidgets(
    'mobile layout remains within viewport and editor sees actual answer flags',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = FakeQuizManagementRepository();
      repo.quizzes.add(
        const ManagedQuiz(
          id: 'qz',
          moduleId: 'module-1',
          title: 'Quiz',
          description: '',
          passingScore: 70,
          isPublished: false,
        ),
      );
      repo.questions['qz'] = [
        const ManagedQuizQuestion(
          id: 'one',
          quizId: 'qz',
          text: 'Question',
          explanation: 'Reason',
          order: 1,
          options: [
            ManagedQuizOption(
              id: 'a',
              questionId: 'one',
              text: 'Right',
              displayOrder: 1,
              isCorrect: true,
            ),
          ],
        ),
      ];
      await pumpScreen(tester, repo, size: const Size(390, 844));
      await tapText(tester, 'Manage');
      expect(find.text('✓ Right'), findsOneWidget);
      expect(find.textContaining('Explanation: Reason'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('student-style preview does not reveal the answer key', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = FakeQuizManagementRepository();
    repo.quizzes.add(
      const ManagedQuiz(
        id: 'qz',
        moduleId: 'module-1',
        title: 'Quiz',
        description: '',
        passingScore: 70,
        isPublished: false,
      ),
    );
    repo.questions['qz'] = [
      const ManagedQuizQuestion(
        id: 'one',
        quizId: 'qz',
        text: 'Question?',
        explanation: 'Private explanation',
        order: 1,
        options: [
          ManagedQuizOption(
            id: 'option-1',
            questionId: 'one',
            text: 'Right option',
            displayOrder: 1,
            isCorrect: true,
          ),
        ],
      ),
    ];
    await pumpScreen(tester, repo);
    await tapText(tester, 'Manage');
    await tapText(tester, 'Preview quiz');
    expect(find.text('Quiz · Preview'), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
  });
}
