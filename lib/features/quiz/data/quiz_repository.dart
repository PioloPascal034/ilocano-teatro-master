import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/quiz_models.dart';

abstract interface class QuizRepository {
  Future<List<AvailableQuiz>> loadAvailableQuizzes();

  Future<StudentQuiz?> loadQuiz(String quizId);

  Future<List<QuizAttempt>> loadMyAttempts();

  Future<QuizResult> submitAnswers({
    required String quizId,
    required Map<String, String> answersByQuestion,
  });
}

class SupabaseQuizRepository implements QuizRepository {
  SupabaseQuizRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  User get _student {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Sign in to take a quiz.');
    return user;
  }

  @override
  Future<List<AvailableQuiz>> loadAvailableQuizzes() async {
    _student;
    final modules = await _client
        .from('learning_modules')
        .select('module_id, title')
        .eq('is_published', true);
    final moduleTitles = <String, String>{
      for (final row in modules)
        row['module_id'] as String: row['title'] as String? ?? '',
    };
    final quizzes = await _client
        .from('quizzes')
        .select('quiz_id, module_id, title, description, passing_score')
        .eq('is_published', true)
        .order('title');
    return List.unmodifiable(
      quizzes
          .where((row) => moduleTitles.containsKey(row['module_id']))
          .map(
            (row) => AvailableQuiz(
              id: row['quiz_id'] as String,
              moduleId: row['module_id'] as String,
              moduleTitle: moduleTitles[row['module_id'] as String] ?? '',
              title: row['title'] as String? ?? '',
              description: row['description'] as String? ?? '',
              passingScore: (row['passing_score'] as num?)?.toInt() ?? 70,
            ),
          ),
    );
  }

  @override
  Future<StudentQuiz?> loadQuiz(String quizId) async {
    _student;
    final quizRow = await _client
        .from('quizzes')
        .select('quiz_id, module_id, title, description, passing_score')
        .eq('quiz_id', quizId)
        .eq('is_published', true)
        .maybeSingle();
    if (quizRow == null) return null;

    final moduleRow = await _client
        .from('learning_modules')
        .select('title')
        .eq('module_id', quizRow['module_id'] as String)
        .eq('is_published', true)
        .maybeSingle();
    if (moduleRow == null) return null;

    final questionRows = await _client
        .from('quiz_questions')
        .select('question_id, question_text, question_order')
        .eq('quiz_id', quizId)
        .order('question_order');
    final questionIds = questionRows
        .map((row) => row['question_id'] as String)
        .toList();
    final optionRows = questionIds.isEmpty
        ? const <Map<String, dynamic>>[]
        : await _client
              .from('question_options')
              .select('option_id, question_id, option_text, display_order')
              .inFilter('question_id', questionIds)
              .order('display_order');

    final optionsByQuestion = <String, List<QuizOption>>{};
    for (final row in optionRows) {
      final questionId = row['question_id'] as String;
      optionsByQuestion
          .putIfAbsent(questionId, () => [])
          .add(
            QuizOption(
              id: row['option_id'] as String,
              text: row['option_text'] as String? ?? '',
              displayOrder: (row['display_order'] as num?)?.toInt() ?? 0,
            ),
          );
    }

    final questions = questionRows.map((row) {
      final id = row['question_id'] as String;
      final options = List<QuizOption>.of(
        optionsByQuestion[id] ?? const <QuizOption>[],
      )..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
      return QuizQuestion(
        id: id,
        text: row['question_text'] as String? ?? '',
        questionOrder: (row['question_order'] as num?)?.toInt() ?? 0,
        options: List.unmodifiable(options),
      );
    }).toList();

    return StudentQuiz(
      quiz: AvailableQuiz(
        id: quizRow['quiz_id'] as String,
        moduleId: quizRow['module_id'] as String,
        moduleTitle: moduleRow['title'] as String? ?? '',
        title: quizRow['title'] as String? ?? '',
        description: quizRow['description'] as String? ?? '',
        passingScore: (quizRow['passing_score'] as num?)?.toInt() ?? 70,
      ),
      questions: List.unmodifiable(questions),
    );
  }

  @override
  Future<List<QuizAttempt>> loadMyAttempts() async {
    final user = _student;
    final rows = await _client
        .from('quiz_attempts')
        .select('attempt_id, quiz_id, score, completed_at')
        .eq('student_id', user.id)
        .not('completed_at', 'is', null)
        .order('completed_at', ascending: false);
    return List.unmodifiable(
      rows
          .where((row) => row['score'] is num && row['completed_at'] != null)
          .map(
            (row) => QuizAttempt(
              id: row['attempt_id'] as String,
              quizId: row['quiz_id'] as String,
              score: (row['score'] as num).toDouble(),
              completedAt: DateTime.parse(row['completed_at'] as String),
            ),
          ),
    );
  }

  @override
  Future<QuizResult> submitAnswers({
    required String quizId,
    required Map<String, String> answersByQuestion,
  }) async {
    _student;
    if (answersByQuestion.isEmpty) {
      throw ArgumentError('Answer every question before submitting.');
    }
    final response = await _client.rpc(
      'submit_quiz',
      params: {'p_quiz_id': quizId, 'p_answers': answersByQuestion},
    );
    if (response is! Map) {
      throw const FormatException(
        'The quiz submission returned an invalid result.',
      );
    }
    final result = Map<String, dynamic>.from(response);
    return QuizResult(
      attemptId: result['attempt_id'] as String,
      score: (result['score'] as num).toDouble(),
      correctAnswers: (result['correct'] as num).toInt(),
      totalQuestions: (result['total'] as num).toInt(),
    );
  }
}
