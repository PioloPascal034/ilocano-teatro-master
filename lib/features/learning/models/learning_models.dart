bool isSeedPlaceholderLesson(String? content) =>
    (content ?? '').trimLeft().toUpperCase().startsWith('DEMO LESSON ONLY:');

class LearningLessonRoute {
  const LearningLessonRoute({required this.moduleId, required this.lessonId});

  final String moduleId;
  final String lessonId;
}

class LearningLesson {
  const LearningLesson({
    required this.id,
    required this.moduleId,
    required this.title,
    required this.lessonOrder,
    required this.objectives,
    required this.content,
    this.isCompleted = false,
    this.isInProgress = false,
  });

  final String id;
  final String moduleId;
  final String title;
  final int lessonOrder;
  final String? objectives;
  final String content;
  final bool isCompleted;
  final bool isInProgress;
}

class LearningModule {
  const LearningModule({
    required this.id,
    required this.title,
    required this.description,
    required this.displayOrder,
    required this.lessons,
  });

  final String id;
  final String title;
  final String description;
  final int displayOrder;
  final List<LearningLesson> lessons;

  int get completedLessonCount =>
      lessons.where((lesson) => lesson.isCompleted).length;

  double get completion =>
      lessons.isEmpty ? 0 : completedLessonCount / lessons.length;
}

class StudentLearningCatalog {
  const StudentLearningCatalog({required this.modules});

  final List<LearningModule> modules;

  int get totalLessons =>
      modules.fold(0, (total, module) => total + module.lessons.length);

  int get completedLessons =>
      modules.fold(0, (total, module) => total + module.completedLessonCount);

  double get overallCompletion =>
      totalLessons == 0 ? 0 : completedLessons / totalLessons;

  LearningModule? moduleById(String id) {
    for (final module in modules) {
      if (module.id == id) return module;
    }
    return null;
  }

  LearningLesson? lessonById(String id) {
    for (final module in modules) {
      for (final lesson in module.lessons) {
        if (lesson.id == id) return lesson;
      }
    }
    return null;
  }

  LearningLessonRoute? get continueRoute {
    for (final module in modules) {
      for (final lesson in module.lessons) {
        if (lesson.isInProgress && !lesson.isCompleted) {
          return LearningLessonRoute(moduleId: module.id, lessonId: lesson.id);
        }
      }
    }
    for (final module in modules) {
      for (final lesson in module.lessons) {
        if (!lesson.isCompleted) {
          return LearningLessonRoute(moduleId: module.id, lessonId: lesson.id);
        }
      }
    }
    return null;
  }
}
