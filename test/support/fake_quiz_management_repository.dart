import 'package:ilocano_teatro_master/features/quiz/data/quiz_management_repository.dart';
import 'package:ilocano_teatro_master/features/quiz/models/quiz_management_models.dart';

class FakeQuizManagementRepository implements QuizManagementRepository {
  FakeQuizManagementRepository({this.editor = true, this.loadError})
    : quizzes = [];
  bool editor;
  final Object? loadError;
  final List<ManagedQuiz> quizzes;
  final Map<String, List<ManagedQuizQuestion>> questions = {};
  List<String> reorderRequest = [];
  int _next = 1;
  bool lockEdits = false;

  @override
  Future<bool> isCurriculumEditor() async => editor;
  @override
  Future<List<ManagedQuiz>> loadQuizzes(String moduleId) async {
    if (loadError != null) throw loadError!;
    return quizzes
        .where(
          (quiz) => quiz.moduleId == moduleId && (editor || quiz.isPublished),
        )
        .toList();
  }

  @override
  Future<ManagedQuizDetails?> loadQuizDetails(String quizId) async {
    final quiz = quizzes.where((item) => item.id == quizId).firstOrNull;
    if (quiz == null || (!editor && !quiz.isPublished)) return null;
    return ManagedQuizDetails(quiz: quiz, questions: questions[quizId] ?? []);
  }

  @override
  Future<ManagedQuiz> createQuiz({
    required String moduleId,
    required String title,
    required String description,
    required int passingScore,
  }) async {
    if (!editor) throw StateError('Curriculum editor permission required');
    final item = ManagedQuiz(
      id: 'quiz-${_next++}',
      moduleId: moduleId,
      title: title,
      description: description,
      passingScore: passingScore,
      isPublished: false,
    );
    quizzes.add(item);
    return item;
  }

  @override
  Future<void> updateQuiz({
    required String quizId,
    required String title,
    required String description,
    required int passingScore,
  }) async {
    final i = quizzes.indexWhere((q) => q.id == quizId);
    final q = quizzes[i];
    quizzes[i] = ManagedQuiz(
      id: q.id,
      moduleId: q.moduleId,
      title: title,
      description: description,
      passingScore: passingScore,
      isPublished: q.isPublished,
    );
  }

  @override
  Future<void> setPublished({
    required String quizId,
    required bool isPublished,
  }) async {
    final i = quizzes.indexWhere((q) => q.id == quizId);
    final q = quizzes[i];
    if (isPublished) {
      final qs = questions[quizId] ?? [];
      if (qs.isEmpty ||
          qs.any(
            (question) =>
                question.options.length < 2 ||
                question.options
                        .where((option) => option.isCorrect == true)
                        .length !=
                    1,
          )) {
        throw StateError(
          'Each question needs at least two options and exactly one correct option.',
        );
      }
    }
    quizzes[i] = ManagedQuiz(
      id: q.id,
      moduleId: q.moduleId,
      title: q.title,
      description: q.description,
      passingScore: q.passingScore,
      isPublished: isPublished,
    );
  }

  @override
  Future<String> createQuestion({
    required String quizId,
    required String text,
    required String explanation,
  }) async {
    if (lockEdits) {
      throw StateError('Quiz questions are locked after the first attempt');
    }
    final id = 'question-${_next++}';
    final list = questions.putIfAbsent(quizId, () => []);
    list.add(
      ManagedQuizQuestion(
        id: id,
        quizId: quizId,
        text: text,
        explanation: explanation,
        order: list.length + 1,
        options: const [],
      ),
    );
    return id;
  }

  @override
  Future<void> updateQuestion({
    required String questionId,
    required String text,
    required String explanation,
  }) async {
    for (final entry in questions.entries) {
      final i = entry.value.indexWhere((q) => q.id == questionId);
      if (i < 0) continue;
      final old = entry.value[i];
      entry.value[i] = ManagedQuizQuestion(
        id: old.id,
        quizId: old.quizId,
        text: text,
        explanation: explanation,
        order: old.order,
        options: old.options,
      );
      return;
    }
  }

  @override
  Future<String> createOption({
    required String questionId,
    required String text,
    required bool isCorrect,
  }) async {
    final id = 'option-${_next++}';
    for (final entry in questions.entries) {
      final i = entry.value.indexWhere((q) => q.id == questionId);
      if (i < 0) continue;
      final q = entry.value[i];
      final options = [
        ...q.options,
        ManagedQuizOption(
          id: id,
          questionId: questionId,
          text: text,
          displayOrder: q.options.length + 1,
          isCorrect: isCorrect,
        ),
      ];
      entry.value[i] = ManagedQuizQuestion(
        id: q.id,
        quizId: q.quizId,
        text: q.text,
        explanation: q.explanation,
        order: q.order,
        options: options,
      );
      return id;
    }
    throw StateError('Question missing');
  }

  @override
  Future<void> updateOption({
    required String optionId,
    required String text,
    required bool isCorrect,
  }) async {
    for (final entry in questions.entries) {
      for (var i = 0; i < entry.value.length; i++) {
        final q = entry.value[i];
        final options = [...q.options];
        final oi = options.indexWhere((o) => o.id == optionId);
        if (oi < 0) continue;
        final old = options[oi];
        options[oi] = ManagedQuizOption(
          id: old.id,
          questionId: old.questionId,
          text: text,
          displayOrder: old.displayOrder,
          isCorrect: isCorrect,
        );
        entry.value[i] = ManagedQuizQuestion(
          id: q.id,
          quizId: q.quizId,
          text: q.text,
          explanation: q.explanation,
          order: q.order,
          options: options,
        );
        return;
      }
    }
  }

  @override
  Future<void> reorderQuestions({
    required String quizId,
    required List<String> questionIds,
  }) async {
    reorderRequest = List.of(questionIds);
    final byId = {for (final q in questions[quizId] ?? []) q.id: q};
    questions[quizId] = [
      for (var i = 0; i < questionIds.length; i++)
        _copy(byId[questionIds[i]]!, i + 1),
    ];
  }

  ManagedQuizQuestion _copy(ManagedQuizQuestion q, int order) =>
      ManagedQuizQuestion(
        id: q.id,
        quizId: q.quizId,
        text: q.text,
        explanation: q.explanation,
        order: order,
        options: q.options,
      );
}
