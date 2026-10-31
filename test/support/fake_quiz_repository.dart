import 'package:ilocano_teatro_master/features/quiz/data/quiz_repository.dart';
import 'package:ilocano_teatro_master/features/quiz/models/quiz_models.dart';

class FakeQuizRepository implements QuizRepository {
  FakeQuizRepository({
    this.quizzes = const [
      AvailableQuiz(
        id: 'quiz-1',
        moduleId: 'module-1',
        moduleTitle: 'Introduction to Theater',
        title: 'Theater Basics',
        description: 'A short knowledge check.',
        passingScore: 70,
      ),
    ],
    List<QuizAttempt> attempts = const [],
    this.quiz,
    this.homeError,
    this.quizError,
    this.submitError,
  }) : _attempts = List<QuizAttempt>.of(attempts);

  final List<AvailableQuiz> quizzes;
  final List<QuizAttempt> _attempts;
  final StudentQuiz? quiz;
  final Object? homeError;
  final Object? quizError;
  final Object? submitError;
  Map<String, String>? submittedAnswers;

  List<QuizAttempt> get attempts => List.unmodifiable(_attempts);

  StudentQuiz get _defaultQuiz =>
      quiz ??
      StudentQuiz(
        quiz: quizzes.isEmpty
            ? const AvailableQuiz(
                id: 'quiz-1',
                moduleId: 'module-1',
                moduleTitle: 'Module',
                title: 'Quiz',
                description: '',
                passingScore: 70,
              )
            : quizzes.first,
        questions: const [
          QuizQuestion(
            id: 'question-1',
            text: 'Which answer is correct?',
            questionOrder: 1,
            options: [
              QuizOption(id: 'option-a', text: 'First choice', displayOrder: 1),
              QuizOption(
                id: 'option-b',
                text: 'Second choice',
                displayOrder: 2,
              ),
            ],
          ),
          QuizQuestion(
            id: 'question-2',
            text: 'Choose another answer.',
            questionOrder: 2,
            options: [
              QuizOption(id: 'option-c', text: 'Third choice', displayOrder: 1),
              QuizOption(
                id: 'option-d',
                text: 'Fourth choice',
                displayOrder: 2,
              ),
            ],
          ),
        ],
      );

  @override
  Future<List<AvailableQuiz>> loadAvailableQuizzes() async {
    if (homeError != null) throw homeError!;
    return quizzes;
  }

  @override
  Future<StudentQuiz?> loadQuiz(String quizId) async {
    if (quizError != null) throw quizError!;
    final data = _defaultQuiz;
    return data.quiz.id == quizId ? data : null;
  }

  @override
  Future<List<QuizAttempt>> loadMyAttempts() async {
    if (homeError != null) throw homeError!;
    return List.unmodifiable(_attempts);
  }

  @override
  Future<QuizResult> submitAnswers({
    required String quizId,
    required Map<String, String> answersByQuestion,
  }) async {
    if (submitError != null) throw submitError!;
    submittedAnswers = Map.unmodifiable(answersByQuestion);
    final quiz = _defaultQuiz;
    const correctByQuestion = {
      'question-1': 'option-b',
      'question-2': 'option-c',
    };
    final correct = answersByQuestion.entries
        .where((entry) => correctByQuestion[entry.key] == entry.value)
        .length;
    final score = correct / quiz.questions.length * 100;
    _attempts.insert(
      0,
      QuizAttempt(
        id: 'attempt-${_attempts.length + 1}',
        quizId: quizId,
        score: score,
        completedAt: DateTime.now(),
      ),
    );
    return QuizResult(
      attemptId: 'attempt-new',
      score: score,
      correctAnswers: correct,
      totalQuestions: quiz.questions.length,
    );
  }
}
