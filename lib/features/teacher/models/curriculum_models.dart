class CurriculumLesson {
  const CurriculumLesson({
    required this.id,
    required this.moduleId,
    required this.title,
    required this.objectives,
    required this.content,
    required this.lessonOrder,
    required this.isPublished,
    this.sections = const <String, String>{},
    this.needsContentReview = false,
    this.overview = '',
    this.estimatedReadingMinutes,
  });

  final String id;
  final String moduleId;
  final String title;
  final String? objectives;
  final String content;
  final int lessonOrder;
  final bool isPublished;

  /// Optional structured lesson sections. Empty means legacy plain text.
  final Map<String, String> sections;
  final bool needsContentReview;
  final String overview;
  final int? estimatedReadingMinutes;
}

class CurriculumModule {
  const CurriculumModule({
    required this.id,
    required this.title,
    required this.description,
    required this.displayOrder,
    required this.isPublished,
    required this.lessons,
    this.placeholderLessonCount = 0,
    this.publishedPlaceholderLessonCount = 0,
    this.unpublishedPlaceholderLessonCount = 0,
  });

  final String id;
  final String title;
  final String description;
  final int displayOrder;
  final bool isPublished;
  final List<CurriculumLesson> lessons;
  final int placeholderLessonCount;
  final int publishedPlaceholderLessonCount;
  final int unpublishedPlaceholderLessonCount;
}
