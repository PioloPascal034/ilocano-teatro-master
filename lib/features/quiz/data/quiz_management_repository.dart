import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/quiz_management_models.dart';

abstract interface class QuizManagementRepository {
  Future<bool> isCurriculumEditor();
  Future<List<ManagedQuiz>> loadQuizzes(String moduleId);
  Future<ManagedQuizDetails?> loadQuizDetails(String quizId);
  Future<ManagedQuiz> createQuiz({
    required String moduleId,
    required String title,
    required String description,
    required int passingScore,
  });
  Future<void> updateQuiz({
    required String quizId,
    required String title,
    required String description,
    required int passingScore,
  });
  Future<void> setPublished({
    required String quizId,
    required bool isPublished,
  });
  Future<void> deleteQuiz(String quizId);
  Future<String> createQuestion({
    required String quizId,
    required String text,
    required String explanation,
  });
  Future<void> updateQuestion({
    required String questionId,
    required String text,
    required String explanation,
  });
  Future<String> createOption({
    required String questionId,
    required String text,
    required bool isCorrect,
  });
  Future<void> updateOption({
    required String optionId,
    required String text,
    required bool isCorrect,
  });
  Future<void> reorderQuestions({
    required String quizId,
    required List<String> questionIds,
  });
}

class SupabaseQuizManagementRepository implements QuizManagementRepository {
  SupabaseQuizManagementRepository({SupabaseClient? client})
    : _configuredClient = client;
  final SupabaseClient? _configuredClient;
  SupabaseClient get _client => _configuredClient ?? Supabase.instance.client;

  void _requireSession() {
    if (_client.auth.currentUser == null) {
      throw StateError('Sign in to manage quizzes.');
    }
  }

  Map<String, dynamic> _quizFromRow(Map<String, dynamic> row) => {
    'id': row['quiz_id'],
    'moduleId': row['module_id'],
    'title': row['title'] ?? '',
    'description': row['description'] ?? '',
    'passingScore': (row['passing_score'] as num?)?.toInt() ?? 70,
    'isPublished': row['is_published'] as bool? ?? false,
  };

  ManagedQuiz _parseQuiz(Map<String, dynamic> row) {
    final data = _quizFromRow(row);
    return ManagedQuiz(
      id: data['id'] as String,
      moduleId: data['moduleId'] as String,
      title: data['title'] as String,
      description: data['description'] as String,
      passingScore: data['passingScore'] as int,
      isPublished: data['isPublished'] as bool,
    );
  }

  @override
  Future<bool> isCurriculumEditor() async {
    _requireSession();
    final value = await _client.rpc('is_curriculum_editor');
    if (value is! bool) {
      throw const FormatException(
        'Invalid curriculum editor permission response.',
      );
    }
    return value;
  }

  @override
  Future<List<ManagedQuiz>> loadQuizzes(String moduleId) async {
    _requireSession();
    final rows = await _client
        .from('quizzes')
        .select(
          'quiz_id,module_id,title,description,passing_score,is_published',
        )
        .eq('module_id', moduleId)
        .order('title');
    return List.unmodifiable(rows.map(_parseQuiz));
  }

  @override
  Future<ManagedQuizDetails?> loadQuizDetails(String quizId) async {
    _requireSession();
    final quizRow = await _client
        .from('quizzes')
        .select(
          'quiz_id,module_id,title,description,passing_score,is_published',
        )
        .eq('quiz_id', quizId)
        .maybeSingle();
    if (quizRow == null) return null;
    final questionRows = await _client
        .from('quiz_questions')
        .select('question_id,quiz_id,question_text,question_order')
        .eq('quiz_id', quizId)
        .order('question_order');
    final ids = questionRows
        .map((row) => row['question_id'] as String)
        .toList();
    final optionRows = ids.isEmpty
        ? <Map<String, dynamic>>[]
        : await _client
              .from('question_options')
              .select('option_id,question_id,option_text,display_order')
              .inFilter('question_id', ids)
              .order('display_order');
    // The answer key and explanations are available only through the editor-gated RPC.
    final details = await isCurriculumEditor()
        ? await _client.rpc(
            'get_quiz_editor_question_details',
            params: {'p_quiz_id': quizId},
          )
        : null;
    final detailsByQuestion = <String, Map<String, dynamic>>{};
    if (details is List) {
      for (final item in details.whereType<Map>()) {
        final row = Map<String, dynamic>.from(item);
        detailsByQuestion[row['question_id'] as String] = row;
      }
    }
    final optionsByQuestion = <String, List<ManagedQuizOption>>{};
    for (final row in optionRows) {
      final qid = row['question_id'] as String;
      final detail = detailsByQuestion[qid];
      final correctness = <String, bool>{};
      if (detail?['options'] is List) {
        for (final item in (detail!['options'] as List).whereType<Map>()) {
          correctness[item['option_id'] as String] =
              item['is_correct'] as bool? ?? false;
        }
      }
      final optionId = row['option_id'] as String;
      optionsByQuestion
          .putIfAbsent(qid, () => [])
          .add(
            ManagedQuizOption(
              id: optionId,
              questionId: qid,
              text: row['option_text'] as String? ?? '',
              displayOrder: (row['display_order'] as num?)?.toInt() ?? 0,
              isCorrect: detailsByQuestion.containsKey(qid)
                  ? correctness[optionId] ?? false
                  : null,
            ),
          );
    }
    final questions = questionRows.map((row) {
      final id = row['question_id'] as String;
      return ManagedQuizQuestion(
        id: id,
        quizId: quizId,
        text: row['question_text'] as String? ?? '',
        explanation: detailsByQuestion[id]?['explanation'] as String? ?? '',
        order: (row['question_order'] as num?)?.toInt() ?? 0,
        options: List.unmodifiable(optionsByQuestion[id] ?? const []),
      );
    }).toList();
    return ManagedQuizDetails(
      quiz: _parseQuiz(quizRow),
      questions: List.unmodifiable(questions),
    );
  }

  @override
  Future<ManagedQuiz> createQuiz({
    required String moduleId,
    required String title,
    required String description,
    required int passingScore,
  }) async {
    _requireSession();
    final row = await _client
        .from('quizzes')
        .insert({
          'module_id': moduleId,
          'title': title.trim(),
          'description': description.trim(),
          'passing_score': passingScore,
          'is_published': false,
        })
        .select(
          'quiz_id,module_id,title,description,passing_score,is_published',
        )
        .single();
    return _parseQuiz(row);
  }

  @override
  Future<void> updateQuiz({
    required String quizId,
    required String title,
    required String description,
    required int passingScore,
  }) async {
    _requireSession();
    await _client
        .from('quizzes')
        .update({
          'title': title.trim(),
          'description': description.trim(),
          'passing_score': passingScore,
        })
        .eq('quiz_id', quizId);
  }

  @override
  Future<void> setPublished({
    required String quizId,
    required bool isPublished,
  }) async {
    _requireSession();
    await _client
        .from('quizzes')
        .update({'is_published': isPublished})
        .eq('quiz_id', quizId);
  }

  @override
  Future<void> deleteQuiz(String quizId) async {
    _requireSession();
    await _client.rpc('delete_curriculum_quiz', params: {'p_quiz_id': quizId});
  }

  @override
  Future<String> createQuestion({
    required String quizId,
    required String text,
    required String explanation,
  }) async {
    _requireSession();
    final rows = await _client
        .from('quiz_questions')
        .select('question_order')
        .eq('quiz_id', quizId)
        .order('question_order', ascending: false)
        .limit(1);
    final order = rows.isEmpty
        ? 1
        : ((rows.first['question_order'] as num?)?.toInt() ?? 0) + 1;
    final row = await _client
        .from('quiz_questions')
        .insert({
          'quiz_id': quizId,
          'question_text': text.trim(),
          'explanation': explanation.trim(),
          'question_order': order,
        })
        .select('question_id')
        .single();
    return row['question_id'] as String;
  }

  @override
  Future<void> updateQuestion({
    required String questionId,
    required String text,
    required String explanation,
  }) async {
    _requireSession();
    await _client
        .from('quiz_questions')
        .update({
          'question_text': text.trim(),
          'explanation': explanation.trim(),
        })
        .eq('question_id', questionId);
  }

  @override
  Future<String> createOption({
    required String questionId,
    required String text,
    required bool isCorrect,
  }) async {
    _requireSession();
    final rows = await _client
        .from('question_options')
        .select('display_order')
        .eq('question_id', questionId)
        .order('display_order', ascending: false)
        .limit(1);
    final order = rows.isEmpty
        ? 1
        : ((rows.first['display_order'] as num?)?.toInt() ?? 0) + 1;
    final row = await _client
        .from('question_options')
        .insert({
          'question_id': questionId,
          'option_text': text.trim(),
          'is_correct': isCorrect,
          'display_order': order,
        })
        .select('option_id')
        .single();
    return row['option_id'] as String;
  }

  @override
  Future<void> updateOption({
    required String optionId,
    required String text,
    required bool isCorrect,
  }) async {
    _requireSession();
    await _client
        .from('question_options')
        .update({'option_text': text.trim(), 'is_correct': isCorrect})
        .eq('option_id', optionId);
  }

  @override
  Future<void> reorderQuestions({
    required String quizId,
    required List<String> questionIds,
  }) async {
    _requireSession();
    await _client.rpc(
      'reorder_quiz_questions',
      params: {'p_quiz_id': quizId, 'p_question_ids': questionIds},
    );
  }
}
