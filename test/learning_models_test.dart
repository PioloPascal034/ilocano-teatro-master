import 'package:flutter_test/flutter_test.dart';
import 'package:ilocano_teatro_master/features/learning/models/learning_models.dart';

LearningLesson _lesson(
  String id, {
  bool completed = false,
  bool inProgress = false,
}) => LearningLesson(
  id: id,
  moduleId: 'module',
  title: id,
  lessonOrder: 1,
  objectives: null,
  content: '',
  isCompleted: completed,
  isInProgress: inProgress,
);

void main() {
  test('calculates only from published lessons supplied by the repository', () {
    final catalog = StudentLearningCatalog(
      modules: [
        LearningModule(
          id: 'module-1',
          title: 'Module One',
          description: '',
          displayOrder: 1,
          lessons: [_lesson('lesson-1', completed: true), _lesson('lesson-2')],
        ),
        LearningModule(
          id: 'module-2',
          title: 'Module Two',
          description: '',
          displayOrder: 2,
          lessons: const [],
        ),
      ],
    );

    expect(catalog.totalLessons, 2);
    expect(catalog.completedLessons, 1);
    expect(catalog.overallCompletion, .5);
    expect(catalog.modules.first.completion, .5);
    expect(catalog.modules.last.completion, 0);
  });

  test('continue route prefers in-progress then first incomplete lesson', () {
    final catalog = StudentLearningCatalog(
      modules: [
        LearningModule(
          id: 'module-1',
          title: 'One',
          description: '',
          displayOrder: 1,
          lessons: [_lesson('done', completed: true), _lesson('next')],
        ),
        LearningModule(
          id: 'module-2',
          title: 'Two',
          description: '',
          displayOrder: 2,
          lessons: [_lesson('resume', inProgress: true)],
        ),
      ],
    );

    final route = catalog.continueRoute;
    expect(route?.moduleId, 'module-2');
    expect(route?.lessonId, 'resume');
  });

  test('returns no continuation if all published lessons are complete', () {
    final catalog = StudentLearningCatalog(
      modules: [
        LearningModule(
          id: 'module-1',
          title: 'One',
          description: '',
          displayOrder: 1,
          lessons: [_lesson('done', completed: true)],
        ),
      ],
    );

    expect(catalog.continueRoute, isNull);
    expect(const StudentLearningCatalog(modules: []).overallCompletion, 0);
  });
}
