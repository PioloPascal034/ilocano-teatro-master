import 'package:flutter_test/flutter_test.dart';

import 'support/fake_student_learning_repository.dart';

void main() {
  test(
    'published demo lesson rows stay hidden while their modules remain visible',
    () async {
      final catalog = await FakeStudentLearningRepository().loadCatalog();

      expect(catalog.modules, hasLength(5));
      expect(catalog.totalLessons, 0);
      expect(catalog.placeholderLessonCount, 5);
      expect(catalog.modules.every((module) => module.lessons.isEmpty), isTrue);
      expect(
        catalog.modules.every((module) => module.placeholderLessonCount == 1),
        isTrue,
      );
      expect(catalog.continueRoute, isNull);
    },
  );

  test(
    'approved lessons remain available alongside filtered seed placeholders',
    () async {
      final catalog = await FakeStudentLearningRepository(
        includeVerifiedTestLesson: true,
      ).loadCatalog();

      expect(catalog.modules, hasLength(5));
      expect(catalog.totalLessons, 1);
      expect(catalog.placeholderLessonCount, 4);
      expect(
        catalog.modules.first.lessons.single.title,
        'Verified sample lesson',
      );
      expect(catalog.modules.first.placeholderLessonCount, 0);
    },
  );
}
