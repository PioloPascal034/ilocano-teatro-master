class AvailableQuiz {
  const AvailableQuiz({
    required this.id,
    required this.moduleId,
    required this.moduleTitle,
    required this.title,
    required this.description,
    required this.passingScore,
  });

  final String id;
  final String moduleId;
  final String moduleTitle;
  final String title;
  final String description;
  final int passingScore;
}

class QuizOption {
  const QuizOption({
    required this.id,
    required this.text,
    required this.displayOrder,
  });

  final String id;
  final String text;
  final int displayOrder;
}

class QuizQuestion {
  const QuizQuestion({
    required this.id,
    required this.text,
    required this.questionOrder,
    required this.options,
  });

  final String id;
  final String text;
  final int questionOrder;
  final List<QuizOption> options;
}

class StudentQuiz {
  const StudentQuiz({required this.quiz, required this.questions});

  final AvailableQuiz quiz;
  final List<QuizQuestion> questions;
}

class QuizAttempt {
  const QuizAttempt({
    required this.id,
    required this.quizId,
    required this.score,
    required this.completedAt,
  });

  final String id;
  final String quizId;
  final double score;
  final DateTime completedAt;
}

class QuizResult {
  const QuizResult({
    required this.attemptId,
    required this.score,
    required this.correctAnswers,
    required this.totalQuestions,
  });

  final String attemptId;
  final double score;
  final int correctAnswers;
  final int totalQuestions;
}
