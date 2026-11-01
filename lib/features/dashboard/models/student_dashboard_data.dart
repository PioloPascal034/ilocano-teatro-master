class StudentDashboardProfile {
  const StudentDashboardProfile({
    required this.fullName,
    this.yearLevel,
    this.section,
    this.school,
  });

  final String fullName;
  final String? yearLevel;
  final String? section;
  final String? school;

  String get firstName {
    final name = fullName.trim();
    if (name.isEmpty) return '';
    return name.split(RegExp(r'\s+')).first;
  }
}

class StudentModuleProgress {
  const StudentModuleProgress({
    required this.id,
    required this.title,
    required this.description,
    required this.displayOrder,
    required this.lessonCount,
    required this.completedLessonCount,
    this.placeholderLessonCount = 0,
  });

  final String id;
  final String title;
  final String description;
  final int displayOrder;
  final int lessonCount;
  final int completedLessonCount;
  final int placeholderLessonCount;

  bool get hasLessons => lessonCount > 0;
  bool get isComplete => hasLessons && completedLessonCount >= lessonCount;
  double get completion => hasLessons ? completedLessonCount / lessonCount : 0;
}

class StudentResumeLesson {
  const StudentResumeLesson({
    required this.title,
    required this.moduleTitle,
    required this.lessonOrder,
    required this.moduleOrder,
    required this.moduleLessonCount,
  });

  final String title;
  final String moduleTitle;
  final int lessonOrder;
  final int moduleOrder;
  final int moduleLessonCount;
}

class StudentLearningOverview {
  const StudentLearningOverview({
    required this.modules,
    required this.completedLessonCount,
    required this.publishedLessonCount,
    required this.averageQuizScore,
    this.placeholderLessonCount = 0,
    this.resumeLesson,
  });

  final List<StudentModuleProgress> modules;
  final int completedLessonCount;
  final int publishedLessonCount;
  final double? averageQuizScore;
  final int placeholderLessonCount;
  final StudentResumeLesson? resumeLesson;

  int get completedModuleCount =>
      modules.where((module) => module.isComplete).length;
  double get overallCompletion => publishedLessonCount == 0
      ? 0
      : completedLessonCount / publishedLessonCount;
}

class StudentRecentDraft {
  const StudentRecentDraft({
    required this.id,
    required this.title,
    required this.status,
    required this.updatedAt,
    this.centralMessage,
  });

  final String id;
  final String title;
  final String status;
  final DateTime updatedAt;
  final String? centralMessage;
}
