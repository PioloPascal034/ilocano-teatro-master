import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/learning_models.dart';

abstract interface class StudentLearningRepository {
  Future<StudentLearningCatalog> loadCatalog();

  Future<LearningModule?> loadModule(String moduleId);

  Future<LearningLesson?> loadLesson({
    required String moduleId,
    required String lessonId,
  });

  Future<void> markLessonInProgress(String lessonId);

  Future<void> markLessonCompleted(String lessonId);
}

class SupabaseStudentLearningRepository implements StudentLearningRepository {
  SupabaseStudentLearningRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String get _studentId {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('Sign in to view your learning progress.');
    }
    return user.id;
  }

  @override
  Future<StudentLearningCatalog> loadCatalog() async {
    final studentId = _studentId;
    final moduleRows = await _client
        .from('learning_modules')
        .select('module_id, title, description, display_order')
        .eq('is_published', true)
        .order('display_order');
    final publishedModuleIds = moduleRows
        .map((row) => row['module_id'] as String)
        .toSet();
    final queriedLessonRows = await _client
        .from('lessons')
        .select(
          'lesson_id, module_id, title, objectives, content, lesson_order',
        )
        .eq('is_published', true)
        .order('lesson_order');
    final placeholderCounts = <String, int>{};
    for (final row in queriedLessonRows) {
      final moduleId = row['module_id'] as String;
      if (!publishedModuleIds.contains(moduleId)) continue;
      if (isSeedPlaceholderLesson(row['content'] as String?)) {
        placeholderCounts.update(
          moduleId,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
    }
    final lessonRows = queriedLessonRows
        .where((row) => publishedModuleIds.contains(row['module_id'] as String))
        .where((row) => !isSeedPlaceholderLesson(row['content'] as String?))
        .toList();
    final progressRows = await _client
        .from('lesson_progress')
        .select('lesson_id, status, updated_at')
        .eq('student_id', studentId)
        .order('updated_at', ascending: false);

    final progressByLesson = <String, String>{};
    for (final row in progressRows) {
      progressByLesson[row['lesson_id'] as String] = row['status'] as String;
    }

    final lessonsByModule = <String, List<LearningLesson>>{};
    for (final row in lessonRows) {
      final lessonId = row['lesson_id'] as String;
      final moduleId = row['module_id'] as String;
      final status = progressByLesson[lessonId];
      lessonsByModule
          .putIfAbsent(moduleId, () => [])
          .add(
            LearningLesson(
              id: lessonId,
              moduleId: moduleId,
              title: row['title'] as String? ?? '',
              lessonOrder: (row['lesson_order'] as num?)?.toInt() ?? 0,
              objectives: row['objectives'] as String?,
              content: row['content'] as String? ?? '',
              isCompleted: status == 'completed',
              isInProgress: status == 'in_progress',
            ),
          );
    }

    final modules = moduleRows.map((row) {
      final id = row['module_id'] as String;
      final lessons = List<LearningLesson>.of(
        lessonsByModule[id] ?? const <LearningLesson>[],
      );
      lessons.sort((a, b) => a.lessonOrder.compareTo(b.lessonOrder));
      return LearningModule(
        id: id,
        title: row['title'] as String? ?? '',
        description: row['description'] as String? ?? '',
        displayOrder: (row['display_order'] as num?)?.toInt() ?? 0,
        lessons: List.unmodifiable(lessons),
        placeholderLessonCount: placeholderCounts[id] ?? 0,
      );
    }).toList();
    return StudentLearningCatalog(
      modules: List.unmodifiable(modules),
      placeholderLessonCount: placeholderCounts.values.fold(0, (a, b) => a + b),
    );
  }

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
    final studentId = _studentId;
    final existing = await _client
        .from('lesson_progress')
        .select('status')
        .eq('student_id', studentId)
        .eq('lesson_id', lessonId)
        .maybeSingle();
    if (existing?['status'] == 'completed') return;
    await _client.from('lesson_progress').upsert({
      'student_id': studentId,
      'lesson_id': lessonId,
      'status': 'in_progress',
      'completed_at': null,
    }, onConflict: 'student_id,lesson_id');
  }

  @override
  Future<void> markLessonCompleted(String lessonId) async {
    final studentId = _studentId;
    await _client.from('lesson_progress').upsert({
      'student_id': studentId,
      'lesson_id': lessonId,
      'status': 'completed',
      'completed_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'student_id,lesson_id');
  }
}
