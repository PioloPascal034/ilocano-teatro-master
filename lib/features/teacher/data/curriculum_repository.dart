import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/curriculum_models.dart';

abstract interface class CurriculumRepository {
  Future<bool> isCurriculumEditor();

  Future<List<CurriculumModule>> loadModules();

  Future<CurriculumModule> createModule({
    required String title,
    required String description,
  });

  Future<void> updateModule({
    required String moduleId,
    required String title,
    required String description,
  });

  Future<void> setModulePublished({
    required String moduleId,
    required bool isPublished,
  });

  Future<CurriculumLesson> createLesson({
    required String moduleId,
    required String title,
    required String? objectives,
    required String content,
  });

  Future<void> updateLesson({
    required String lessonId,
    required String title,
    required String? objectives,
    required String content,
  });

  Future<void> setLessonPublished({
    required String lessonId,
    required bool isPublished,
  });

  Future<void> reorderLessons({
    required String moduleId,
    required List<String> lessonIds,
  });
}

class SupabaseCurriculumRepository implements CurriculumRepository {
  SupabaseCurriculumRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  void _requireSession() {
    if (_client.auth.currentUser == null) {
      throw StateError('Sign in to view learning content.');
    }
  }

  @override
  Future<bool> isCurriculumEditor() async {
    _requireSession();
    final result = await _client.rpc('is_curriculum_editor');
    if (result is! bool) {
      throw const FormatException(
        'The curriculum editor permission check returned an invalid result.',
      );
    }
    return result;
  }

  @override
  Future<List<CurriculumModule>> loadModules() async {
    _requireSession();
    // Do not add publication filters here. RLS supplies published rows to
    // ordinary teachers and all rows to authorized curriculum editors.
    final moduleRows = await _client
        .from('learning_modules')
        .select('module_id, title, description, display_order, is_published')
        .order('display_order');
    final lessonRows = await _client
        .from('lessons')
        .select(
          'lesson_id, module_id, title, objectives, content, lesson_order, is_published',
        )
        .order('lesson_order');

    final lessonsByModule = <String, List<CurriculumLesson>>{};
    for (final row in lessonRows) {
      final lesson = CurriculumLesson(
        id: row['lesson_id'] as String,
        moduleId: row['module_id'] as String,
        title: row['title'] as String? ?? '',
        objectives: row['objectives'] as String?,
        content: row['content'] as String? ?? '',
        lessonOrder: (row['lesson_order'] as num?)?.toInt() ?? 0,
        isPublished: row['is_published'] as bool? ?? false,
      );
      lessonsByModule.putIfAbsent(lesson.moduleId, () => []).add(lesson);
    }

    return List.unmodifiable(
      moduleRows.map((row) {
        final moduleId = row['module_id'] as String;
        final lessons = List<CurriculumLesson>.of(
          lessonsByModule[moduleId] ?? const <CurriculumLesson>[],
        )..sort((a, b) => a.lessonOrder.compareTo(b.lessonOrder));
        return CurriculumModule(
          id: moduleId,
          title: row['title'] as String? ?? '',
          description: row['description'] as String? ?? '',
          displayOrder: (row['display_order'] as num?)?.toInt() ?? 0,
          isPublished: row['is_published'] as bool? ?? false,
          lessons: List.unmodifiable(lessons),
        );
      }),
    );
  }

  @override
  Future<CurriculumModule> createModule({
    required String title,
    required String description,
  }) async {
    _requireSession();
    final rows = await _client
        .from('learning_modules')
        .select('display_order')
        .order('display_order', ascending: false)
        .limit(1);
    final displayOrder = rows.isEmpty
        ? 1
        : ((rows.first['display_order'] as num?)?.toInt() ?? 0) + 1;
    final row = await _client
        .from('learning_modules')
        .insert({
          'title': title.trim(),
          'description': description.trim(),
          'display_order': displayOrder,
          'is_published': false,
        })
        .select('module_id, title, description, display_order, is_published')
        .single();
    return CurriculumModule(
      id: row['module_id'] as String,
      title: row['title'] as String? ?? '',
      description: row['description'] as String? ?? '',
      displayOrder: (row['display_order'] as num?)?.toInt() ?? 0,
      isPublished: row['is_published'] as bool? ?? false,
      lessons: const [],
    );
  }

  @override
  Future<void> updateModule({
    required String moduleId,
    required String title,
    required String description,
  }) async {
    _requireSession();
    await _client
        .from('learning_modules')
        .update({'title': title.trim(), 'description': description.trim()})
        .eq('module_id', moduleId);
  }

  @override
  Future<void> setModulePublished({
    required String moduleId,
    required bool isPublished,
  }) async {
    _requireSession();
    await _client
        .from('learning_modules')
        .update({'is_published': isPublished})
        .eq('module_id', moduleId);
  }

  @override
  Future<CurriculumLesson> createLesson({
    required String moduleId,
    required String title,
    required String? objectives,
    required String content,
  }) async {
    _requireSession();
    final rows = await _client
        .from('lessons')
        .select('lesson_order')
        .eq('module_id', moduleId)
        .order('lesson_order', ascending: false)
        .limit(1);
    final lessonOrder = rows.isEmpty
        ? 1
        : ((rows.first['lesson_order'] as num?)?.toInt() ?? 0) + 1;
    final row = await _client
        .from('lessons')
        .insert({
          'module_id': moduleId,
          'title': title.trim(),
          'objectives': _emptyToNull(objectives),
          'content': content.trim(),
          'lesson_order': lessonOrder,
          'is_published': false,
        })
        .select(
          'lesson_id, module_id, title, objectives, content, lesson_order, is_published',
        )
        .single();
    return _lessonFromRow(row);
  }

  @override
  Future<void> updateLesson({
    required String lessonId,
    required String title,
    required String? objectives,
    required String content,
  }) async {
    _requireSession();
    await _client
        .from('lessons')
        .update({
          'title': title.trim(),
          'objectives': _emptyToNull(objectives),
          'content': content.trim(),
        })
        .eq('lesson_id', lessonId);
  }

  @override
  Future<void> setLessonPublished({
    required String lessonId,
    required bool isPublished,
  }) async {
    _requireSession();
    await _client
        .from('lessons')
        .update({'is_published': isPublished})
        .eq('lesson_id', lessonId);
  }

  @override
  Future<void> reorderLessons({
    required String moduleId,
    required List<String> lessonIds,
  }) async {
    _requireSession();
    await _client.rpc(
      'reorder_module_lessons',
      params: {'p_module_id': moduleId, 'p_lesson_ids': lessonIds},
    );
  }

  CurriculumLesson _lessonFromRow(Map<String, dynamic> row) => CurriculumLesson(
    id: row['lesson_id'] as String,
    moduleId: row['module_id'] as String,
    title: row['title'] as String? ?? '',
    objectives: row['objectives'] as String?,
    content: row['content'] as String? ?? '',
    lessonOrder: (row['lesson_order'] as num?)?.toInt() ?? 0,
    isPublished: row['is_published'] as bool? ?? false,
  );

  String? _emptyToNull(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }
}
