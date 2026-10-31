import 'package:ilocano_teatro_master/features/learning/data/student_learning_repository.dart';
import 'package:ilocano_teatro_master/features/learning/models/learning_models.dart';

class FakeStudentLearningRepository implements StudentLearningRepository {
  FakeStudentLearningRepository({
    this.studentId = 'student-a',
    Map<String, Map<String, String>>? progressByStudent,
  }) : progressByStudent = progressByStudent ?? {};

  final String studentId;
  final Map<String, Map<String, String>> progressByStudent;

  Map<String, String> get _progress =>
      progressByStudent.putIfAbsent(studentId, () => {});

  static const _seed =
      <
        ({
          String moduleId,
          String moduleTitle,
          String moduleDescription,
          int moduleOrder,
          String lessonId,
          String lessonTitle,
          String? objectives,
          String content,
        })
      >[
        (
          moduleId: 'module-1',
          moduleTitle: 'Introduction to Theater',
          moduleDescription:
              'Basic theater concepts, genres, and production roles.',
          moduleOrder: 1,
          lessonId: 'lesson-1',
          lessonTitle: 'What Is Theater?',
          objectives: 'Define theater and identify its basic elements.',
          content:
              'DEMO LESSON ONLY: Replace with teacher-approved instructional material before release.',
        ),
        (
          moduleId: 'module-2',
          moduleTitle: 'Ilocano Culture and Storytelling',
          moduleDescription:
              'Regional oral traditions and respectful cultural adaptation.',
          moduleOrder: 2,
          lessonId: 'lesson-2',
          lessonTitle: 'Understanding Ilocano Folklore',
          objectives:
              'Identify cultural sources and acknowledge their origins.',
          content:
              'DEMO LESSON ONLY: Teacher verification and cultural-source review required.',
        ),
        (
          moduleId: 'module-3',
          moduleTitle: 'Fundamentals of Playwriting',
          moduleDescription:
              'Plot, character, dialogue, conflict, and stage directions.',
          moduleOrder: 3,
          lessonId: 'lesson-3',
          lessonTitle: 'Plot, Characters, and Conflict',
          objectives: 'Identify plot components and dramatic conflict.',
          content:
              'DEMO LESSON ONLY: Replace with teacher-approved instructional material before release.',
        ),
        (
          moduleId: 'module-4',
          moduleTitle: 'Theater Theme Development',
          moduleDescription: 'Identify central messages and dramatic themes.',
          moduleOrder: 4,
          lessonId: 'lesson-4',
          lessonTitle: 'Finding the Central Message',
          objectives: 'Draft a clear theme statement.',
          content:
              'DEMO LESSON ONLY: Replace with teacher-approved instructional material before release.',
        ),
        (
          moduleId: 'module-5',
          moduleTitle: 'Preparing a Stage Play Concept',
          moduleDescription: 'Audience, staging, and concept-note preparation.',
          moduleOrder: 5,
          lessonId: 'lesson-5',
          lessonTitle: 'Writing a Concept Note',
          objectives:
              'Describe the audience, setting, and practical stage plan.',
          content:
              'DEMO LESSON ONLY: Replace with teacher-approved instructional material before release.',
        ),
      ];

  List<LearningLesson> _lessons(String moduleId) {
    final row = _seed.firstWhere((item) => item.moduleId == moduleId);
    final status = _progress[row.lessonId];
    return [
      LearningLesson(
        id: row.lessonId,
        moduleId: row.moduleId,
        title: row.lessonTitle,
        lessonOrder: 1,
        objectives: row.objectives,
        content: row.content,
        isCompleted: status == 'completed',
        isInProgress: status == 'in_progress',
      ),
    ];
  }

  @override
  Future<StudentLearningCatalog> loadCatalog() async => StudentLearningCatalog(
    modules: [
      for (final row in _seed)
        LearningModule(
          id: row.moduleId,
          title: row.moduleTitle,
          description: row.moduleDescription,
          displayOrder: row.moduleOrder,
          lessons: _lessons(row.moduleId),
        ),
    ],
  );

  @override
  Future<LearningModule?> loadModule(String moduleId) async {
    final catalog = await loadCatalog();
    for (final module in catalog.modules) {
      if (module.id == moduleId) return module;
    }
    return null;
  }

  @override
  Future<LearningLesson?> loadLesson({
    required String moduleId,
    required String lessonId,
  }) async {
    final module = await loadModule(moduleId);
    if (module == null) return null;
    for (final lesson in module.lessons) {
      if (lesson.id == lessonId) return lesson;
    }
    return null;
  }

  @override
  Future<void> markLessonInProgress(String lessonId) async {
    if (_progress[lessonId] != 'completed') {
      _progress[lessonId] = 'in_progress';
    }
  }

  @override
  Future<void> markLessonCompleted(String lessonId) async {
    _progress[lessonId] = 'completed';
  }
}
