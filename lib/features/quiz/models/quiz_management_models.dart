class ManagedQuiz {
  const ManagedQuiz({
    required this.id,
    required this.moduleId,
    required this.title,
    required this.description,
    required this.passingScore,
    required this.isPublished,
  });

  final String id;
  final String moduleId;
  final String title;
  final String description;
  final int passingScore;
  final bool isPublished;
}

class ManagedQuizOption {
  const ManagedQuizOption({
    required this.id,
    required this.questionId,
    required this.text,
    required this.displayOrder,
    this.isCorrect,
  });

  final String id;
  final String questionId;
  final String text;
  final int displayOrder;

  /// Null when the signed-in reader is not authorized to access the answer key.
  final bool? isCorrect;
}

class ManagedQuizQuestion {
  const ManagedQuizQuestion({
    required this.id,
    required this.quizId,
    required this.text,
    required this.explanation,
    required this.order,
    required this.options,
  });

  final String id;
  final String quizId;
  final String text;
  final String explanation;
  final int order;
  final List<ManagedQuizOption> options;
}

class ManagedQuizDetails {
  const ManagedQuizDetails({required this.quiz, required this.questions});

  final ManagedQuiz quiz;
  final List<ManagedQuizQuestion> questions;
}
