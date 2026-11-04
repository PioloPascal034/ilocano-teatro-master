import 'package:supabase_flutter/supabase_flutter.dart';

import '../../learning/models/learning_models.dart';
import '../../learning/data/lesson_schema.dart';
import '../models/curriculum_models.dart';

abstract interface class CurriculumRepository {
  bool get supportsLessonMetadata;
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
    Map<String, String> sections = const <String, String>{},
    String overview = '',
    int? estimatedReadingMinutes,
  });

  Future<void> updateLesson({
    required String lessonId,
    required String title,
    required String? objectives,
    required String content,
    Map<String, String> sections = const <String, String>{},
    String overview = '',
    int? estimatedReadingMinutes,
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
  bool _hasMetadata = false;

  @override
  bool get supportsLessonMetadata => _hasMetadata;

  void _requireSession() {
    if (_client.auth.currentUser == null) {
      throw StateError('Sign in to view learning content.');
    }
  }

  Future<void> _requireEditor() async {
    _requireSession();
    if (!await isCurriculumEditor()) {
      throw StateError(
        'Curriculum Editor permission is required to change lessons.',
      );
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
    final editor = await isCurriculumEditor();
    // Do not add publication filters here. RLS supplies published rows to
    // ordinary teachers and all rows to authorized curriculum editors.
    final moduleRows = await _client
        .from('learning_modules')
        .select('module_id, title, description, display_order, is_published')
        .order('display_order');
    final loaded = await loadLessonRows(_client);
    _hasMetadata = loaded.hasMetadata;
    final queriedLessonRows = loaded.rows;
    final lessonRows = queriedLessonRows.where((row) {
      final placeholder = isSeedPlaceholderLesson(row['content'] as String?);
      return editor || !placeholder;
    });
    final publishedPlaceholderCounts = <String, int>{};
    final unpublishedPlaceholderCounts = <String, int>{};
    for (final row in queriedLessonRows) {
      if (!isSeedPlaceholderLesson(row['content'] as String?)) continue;
      final moduleId = row['module_id'] as String;
      final counts = row['is_published'] == true
          ? publishedPlaceholderCounts
          : unpublishedPlaceholderCounts;
      counts.update(moduleId, (count) => count + 1, ifAbsent: () => 1);
    }

    final lessonsByModule = <String, List<CurriculumLesson>>{};
    for (final row in lessonRows) {
      final lesson = CurriculumLesson(
        id: row['lesson_id'] as String,
        moduleId: row['module_id'] as String,
        title: row['title'] as String? ?? '',
        objectives: row['objectives'] as String?,
        content: row['content'] as String? ?? '',
        sections: _sectionsFromRow(row['sections']),
        overview: row['overview'] as String? ?? '',
        estimatedReadingMinutes: (row['estimated_reading_minutes'] as num?)
            ?.toInt(),
        lessonOrder: (row['lesson_order'] as num?)?.toInt() ?? 0,
        isPublished: row['is_published'] as bool? ?? false,
        needsContentReview: isSeedPlaceholderLesson(row['content'] as String?),
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
          placeholderLessonCount:
              (publishedPlaceholderCounts[moduleId] ?? 0) +
              (unpublishedPlaceholderCounts[moduleId] ?? 0),
          publishedPlaceholderLessonCount:
              publishedPlaceholderCounts[moduleId] ?? 0,
          unpublishedPlaceholderLessonCount:
              unpublishedPlaceholderCounts[moduleId] ?? 0,
        );
      }),
    );
  }

  @override
  Future<CurriculumModule> createModule({
    required String title,
    required String description,
  }) async {
    await _requireEditor();
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
    await _requireEditor();
    final rows = await _client
        .from('learning_modules')
        .update({'title': title.trim(), 'description': description.trim()})
        .eq('module_id', moduleId)
        .select('module_id');
    if (rows.isEmpty) throw StateError('The module was not updated.');
  }

  @override
  Future<void> setModulePublished({
    required String moduleId,
    required bool isPublished,
  }) async {
    await _requireEditor();
    final rows = await _client
        .from('learning_modules')
        .update({'is_published': isPublished})
        .eq('module_id', moduleId)
        .select('module_id');
    if (rows.isEmpty) {
      throw StateError('The module publication state was not updated.');
    }
  }

  @override
  Future<CurriculumLesson> createLesson({
    required String moduleId,
    required String title,
    required String? objectives,
    required String content,
    Map<String, String> sections = const <String, String>{},
    String overview = '',
    int? estimatedReadingMinutes,
  }) async {
    await _requireEditor();
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
          'sections': sections.isEmpty ? null : sections,
          ..._metadataPayload(overview, estimatedReadingMinutes),
          'lesson_order': lessonOrder,
          'is_published': false,
        })
        .select(
          _hasMetadata
              ? '$lessonBaseColumns,$lessonMetadataColumns'
              : lessonBaseColumns,
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
    Map<String, String> sections = const <String, String>{},
    String overview = '',
    int? estimatedReadingMinutes,
  }) async {
    await _requireEditor();
    final rows = await _client
        .from('lessons')
        .update({
          'title': title.trim(),
          'objectives': _emptyToNull(objectives),
          'content': content.trim(),
          'sections': sections.isEmpty ? null : sections,
          ..._metadataPayload(overview, estimatedReadingMinutes),
        })
        .eq('lesson_id', lessonId)
        .select('lesson_id');
    if (rows.isEmpty) throw StateError('The lesson was not updated.');
  }

  @override
  Future<void> setLessonPublished({
    required String lessonId,
    required bool isPublished,
  }) async {
    await _requireEditor();
    if (isPublished) {
      final lesson = await _client
          .from('lessons')
          .select('content')
          .eq('lesson_id', lessonId)
          .maybeSingle();
      if (lesson == null) throw StateError('The lesson was not found.');
      if (isSeedPlaceholderLesson(lesson['content'] as String?)) {
        throw StateError(
          'This is still seeded demo content. Replace it with source-reviewed lesson text or leave it unpublished before publishing.',
        );
      }
    }
    final rows = await _client
        .from('lessons')
        .update({'is_published': isPublished})
        .eq('lesson_id', lessonId)
        .select('lesson_id');
    if (rows.isEmpty) {
      throw StateError('The lesson publication state was not updated.');
    }
  }

  @override
  Future<void> reorderLessons({
    required String moduleId,
    required List<String> lessonIds,
  }) async {
    await _requireEditor();
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
    sections: _sectionsFromRow(row['sections']),
    overview: row['overview'] as String? ?? '',
    estimatedReadingMinutes: (row['estimated_reading_minutes'] as num?)
        ?.toInt(),
    lessonOrder: (row['lesson_order'] as num?)?.toInt() ?? 0,
    isPublished: row['is_published'] as bool? ?? false,
  );

  String? _emptyToNull(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  Map<String, dynamic> _metadataPayload(String overview, int? minutes) {
    if (!_hasMetadata) {
      if (overview.trim().isNotEmpty) {
        throw StateError(
          'Lesson overviews are not available yet. Your edits have not been saved.',
        );
      }
      return const {};
    }
    return {
      'overview': _emptyToNull(overview),
      'estimated_reading_minutes': minutes,
    };
  }

  Map<String, String> _sectionsFromRow(Object? raw) {
    if (raw is! Map) return const <String, String>{};
    return Map.unmodifiable(
      raw.map((key, value) => MapEntry('$key', '$value')),
    );
  }
}
