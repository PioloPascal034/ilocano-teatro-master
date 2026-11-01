class CurriculumLesson {
  const CurriculumLesson({
    required this.id,
    required this.moduleId,
    required this.title,
    required this.objectives,
    required this.content,
    required this.lessonOrder,
    required this.isPublished,
    this.needsContentReview = false,
  });

  final String id;
  final String moduleId;
  final String title;
  final String? objectives;
  final String content;
  final int lessonOrder;
  final bool isPublished;
  final bool needsContentReview;
}

class CurriculumModule {
  const CurriculumModule({
    required this.id,
    required this.title,
    required this.description,
    required this.displayOrder,
    required this.isPublished,
    required this.lessons,
  });

  final String id;
  final String title;
  final String description;
  final int displayOrder;
  final bool isPublished;
  final List<CurriculumLesson> lessons;
}
