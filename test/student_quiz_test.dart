import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilocano_teatro_master/app/app_theme.dart';
import 'package:ilocano_teatro_master/features/quiz/models/quiz_models.dart';
import 'package:ilocano_teatro_master/features/quiz/student_quiz_screen.dart';
import 'support/fake_quiz_repository.dart';

Future<void> _pump(
  WidgetTester tester,
  FakeQuizRepository repository, {
  Size size = const Size(1000, 900),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: StudentQuizScreen(
              repository: repository,
              onNavigate: (_) {},
            ),
          ),
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
  testWidgets(
    'student answers and submits through repository, then sees result',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = FakeQuizRepository();
      await _pump(tester, repository);

      expect(find.text('Theater Basics'), findsOneWidget);
      await _tap(tester, 'Start quiz');
      expect(find.text('Which answer is correct?'), findsOneWidget);
      expect(find.text('Second choice'), findsOneWidget);
      await _tap(tester, 'Second choice');
      await _tap(tester, 'Next question');
      await _tap(tester, 'Third choice');
      await _tap(tester, 'Review answers');
      expect(find.text('Review your answers'), findsOneWidget);
      await _tap(tester, 'Submit quiz');

      expect(find.text('QUIZ RESULT'), findsOneWidget);
      expect(find.text('100.0%'), findsOneWidget);
      expect(repository.submittedAnswers, {
        'question-1': 'option-b',
        'question-2': 'option-c',
      });
      await _tap(tester, 'Knowledge checks');
      expect(find.text('Previous attempts'), findsOneWidget);
      expect(find.text('100.0%'), findsOneWidget);
    },
  );

  testWidgets('review identifies unanswered questions before submission', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = FakeQuizRepository();
    await _pump(tester, repository);

    await _tap(tester, 'Start quiz');
    await _tap(tester, 'Second choice');
    await _tap(tester, 'Next question');
    await _tap(tester, 'Review answers');

    expect(find.textContaining('Answer all 1 remaining'), findsOneWidget);
    expect(repository.submittedAnswers, isNull);
  });

  testWidgets('empty quiz content and empty quiz list are honest', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final emptyQuiz = StudentQuiz(
      quiz: const AvailableQuiz(
        id: 'quiz-empty',
        moduleId: 'module-1',
        moduleTitle: 'Module',
        title: 'Empty quiz',
        description: '',
        passingScore: 70,
      ),
      questions: const [],
    );
    await _pump(
      tester,
      FakeQuizRepository(quizzes: [emptyQuiz.quiz], quiz: emptyQuiz),
    );
    await _tap(tester, 'Start quiz');
    expect(find.text('Quiz content is not yet available'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await _pump(tester, FakeQuizRepository(quizzes: const []));
    expect(find.text('Quiz content is not yet available'), findsOneWidget);
    expect(find.text('DEMO DATA'), findsNothing);
  });

  testWidgets('previous attempt scores are shown from repository records', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pump(
      tester,
      FakeQuizRepository(
        attempts: [
          QuizAttempt(
            id: 'attempt-12345678',
            quizId: 'quiz-1',
            score: 85,
            completedAt: DateTime(2026, 10, 31),
          ),
        ],
      ),
    );

    expect(find.text('Previous attempts'), findsOneWidget);
    expect(find.text('85.0%'), findsWidgets);
  });

  testWidgets('student quiz layout fits mobile width', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pump(tester, FakeQuizRepository(), size: const Size(390, 844));
    expect(tester.takeException(), isNull);
    await _tap(tester, 'Start quiz');
    expect(tester.takeException(), isNull);
  });

  testWidgets('home and quiz loading errors show retryable messages', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pump(
      tester,
      FakeQuizRepository(homeError: StateError('attempt query unavailable')),
    );
    expect(find.text('attempt query unavailable'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await _pump(
      tester,
      FakeQuizRepository(
        quizError: StateError('quiz question query unavailable'),
      ),
    );
    await _tap(tester, 'Start quiz');
    expect(find.text('quiz question query unavailable'), findsOneWidget);
  });
}
