import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/story_models.dart';
import 'story_image_validator.dart';

abstract interface class StoryVaultRepository {
  Future<bool> isCurriculumEditor();
  Future<List<CulturalStory>> loadStories();
  Future<CulturalStory?> loadStory(String storyId);
  Future<CulturalStory> saveStory(StoryMetadataInput input);
  Future<StoryChapter> saveChapter(StoryChapterInput input);
  Future<void> reorderChapters(String storyId, List<String> chapterIds);
  Future<void> markChapterRead(String chapterId);
  Future<Uint8List> downloadImage(String storagePath);
  Future<String> uploadImage({
    required String storyId,
    String? chapterId,
    required Uint8List bytes,
  });
  Future<void> deleteImageIfUnused(String storagePath);
}

class SupabaseStoryVaultRepository implements StoryVaultRepository {
  SupabaseStoryVaultRepository({SupabaseClient? client})
    : _providedClient = client;

  static const bucketName = 'ilocano-story-media';
  static const _storyColumns =
      'story_id,title,summary,region,genre,story_type,cultural_background,source_title,source_url,is_published,cover_storage_path,cover_alt_text,cover_caption,cover_source_title,cover_source_url';
  static const _chapterColumns =
      'chapter_id,story_id,title,content,chapter_order,source_title,source_url,is_published,illustration_storage_path,illustration_alt_text,illustration_caption,illustration_source_title,illustration_source_url';

  final SupabaseClient? _providedClient;
  SupabaseClient get _client => _providedClient ?? Supabase.instance.client;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('Sign in to access the Story Vault.');
    return id;
  }

  @override
  Future<bool> isCurriculumEditor() async {
    _userId;
    final result = await _client.rpc('is_curriculum_editor');
    return result == true;
  }

  @override
  Future<List<CulturalStory>> loadStories() async {
    final userId = _userId;
    final storyRows = await _client
        .from('cultural_stories')
        .select(_storyColumns)
        .order('title');
    final stories = storyRows
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
    if (stories.isEmpty) return const [];

    final storyIds = stories.map((row) => row['story_id'] as String).toList();
    final chapterRows = await _client
        .from('story_chapters')
        .select(_chapterColumns)
        .inFilter('story_id', storyIds)
        .order('chapter_order');
    final chaptersByStory = _groupChapters(chapterRows);
    final chapterIds = chapterRows
        .map((row) => row['chapter_id'] as String)
        .toList();
    final completed = await _loadCompletedChapterIds(userId, chapterIds);

    return stories.map((row) {
      final id = row['story_id'] as String;
      final chapters = chaptersByStory[id] ?? const <StoryChapter>[];
      return CulturalStory.fromMap(
        row,
        chapters: chapters,
        completedChapterIds: completed.intersection(
          chapters.map((chapter) => chapter.id).toSet(),
        ),
      );
    }).toList();
  }

  @override
  Future<CulturalStory?> loadStory(String storyId) async {
    final userId = _userId;
    final row = await _client
        .from('cultural_stories')
        .select(_storyColumns)
        .eq('story_id', storyId)
        .maybeSingle();
    if (row == null) return null;

    final chapterRows = await _client
        .from('story_chapters')
        .select(_chapterColumns)
        .eq('story_id', storyId)
        .order('chapter_order');
    final chapters = chapterRows
        .map((item) => StoryChapter.fromMap(Map<String, dynamic>.from(item)))
        .toList();
    final completed = await _loadCompletedChapterIds(
      userId,
      chapters.map((chapter) => chapter.id).toList(),
    );
    return CulturalStory.fromMap(
      Map<String, dynamic>.from(row),
      chapters: chapters,
      completedChapterIds: completed,
    );
  }

  Map<String, List<StoryChapter>> _groupChapters(List<dynamic> rows) {
    final grouped = <String, List<StoryChapter>>{};
    for (final raw in rows) {
      final chapter = StoryChapter.fromMap(Map<String, dynamic>.from(raw));
      grouped.putIfAbsent(chapter.storyId, () => []).add(chapter);
    }
    return grouped;
  }

  Future<Set<String>> _loadCompletedChapterIds(
    String userId,
    List<String> chapterIds,
  ) async {
    if (chapterIds.isEmpty) return {};
    final rows = await _client
        .from('story_reading_progress')
        .select('chapter_id')
        .eq('student_id', userId)
        .inFilter('chapter_id', chapterIds);
    return rows.map((row) => row['chapter_id'] as String).toSet();
  }

  @override
  Future<CulturalStory> saveStory(StoryMetadataInput input) async {
    await _requireEditor();
    final values = <String, dynamic>{
      'title': input.title.trim(),
      'summary': input.summary.trim(),
      'region': _nullable(input.region),
      'genre': _nullable(input.genre),
      'story_type': _nullable(input.storyType),
      'cultural_background': _nullable(input.culturalBackground),
      'source_title': _nullable(input.sourceTitle),
      'source_url': _nullable(input.sourceUrl),
      'is_published': input.id == null ? false : input.isPublished,
    };
    if (input.id != null) {
      values.addAll({
        'cover_storage_path': input.coverStoragePath,
        'cover_alt_text': _nullable(input.coverAltText),
        'cover_caption': _nullable(input.coverCaption),
        'cover_source_title': _nullable(input.coverSourceTitle),
        'cover_source_url': _nullable(input.coverSourceUrl),
      });
    }
    final dynamic row = input.id == null
        ? await _client
              .from('cultural_stories')
              .insert(values)
              .select(_storyColumns)
              .single()
        : await _client
              .from('cultural_stories')
              .update(values)
              .eq('story_id', input.id!)
              .select(_storyColumns)
              .single();
    return CulturalStory.fromMap(Map<String, dynamic>.from(row));
  }

  @override
  Future<StoryChapter> saveChapter(StoryChapterInput input) async {
    await _requireEditor();
    final values = <String, dynamic>{
      'title': input.title.trim(),
      'content': input.content,
      'chapter_order': input.order,
      'source_title': _nullable(input.sourceTitle),
      'source_url': _nullable(input.sourceUrl),
      'is_published': input.id == null ? false : input.isPublished,
      'illustration_storage_path': input.illustrationStoragePath,
      'illustration_alt_text': _nullable(input.illustrationAltText),
      'illustration_caption': _nullable(input.illustrationCaption),
      'illustration_source_title': _nullable(input.illustrationSourceTitle),
      'illustration_source_url': _nullable(input.illustrationSourceUrl),
    };
    final dynamic row = input.id == null
        ? await _client
              .from('story_chapters')
              .insert({'story_id': input.storyId, ...values})
              .select(_chapterColumns)
              .single()
        : await _client
              .from('story_chapters')
              .update(values)
              .eq('chapter_id', input.id!)
              .select(_chapterColumns)
              .single();
    return StoryChapter.fromMap(Map<String, dynamic>.from(row));
  }

  @override
  Future<void> reorderChapters(String storyId, List<String> chapterIds) async {
    await _requireEditor();
    await _client.rpc(
      'reorder_story_chapters',
      params: {'p_story_id': storyId, 'p_chapter_ids': chapterIds},
    );
  }

  @override
  Future<void> markChapterRead(String chapterId) async {
    _userId;
    try {
      await _client.from('story_reading_progress').insert({
        'chapter_id': chapterId,
      });
    } on PostgrestException catch (error) {
      // The progress key is (student_id, chapter_id), so a retry or a second
      // device marking the same chapter is an already-completed success.
      if (error.code != '23505') rethrow;
    }
  }

  @override
  Future<Uint8List> downloadImage(String storagePath) async {
    _userId;
    try {
      return await _client.storage.from(bucketName).download(storagePath);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'Story Vault image download failed for "$storagePath": $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
      rethrow;
    }
  }

  @override
  Future<String> uploadImage({
    required String storyId,
    String? chapterId,
    required Uint8List bytes,
  }) async {
    await _requireEditor();
    final format = StoryImageValidator.validate(bytes);
    final folders = chapterId == null
        ? '$storyId/cover'
        : '$storyId/chapters/$chapterId';
    final suffix =
        '${DateTime.now().microsecondsSinceEpoch}_'
        '${Random.secure().nextInt(0x7fffffff).toRadixString(16)}';
    final path = '$folders/$suffix.${format.extension}';
    await _client.storage
        .from(bucketName)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: format.mimeType, upsert: false),
        );
    return path;
  }

  @override
  Future<void> deleteImageIfUnused(String storagePath) async {
    if (!await isCurriculumEditor()) return;
    final coverReference = await _client
        .from('cultural_stories')
        .select('story_id')
        .eq('cover_storage_path', storagePath)
        .limit(1);
    if (coverReference.isNotEmpty) return;
    final illustrationReference = await _client
        .from('story_chapters')
        .select('chapter_id')
        .eq('illustration_storage_path', storagePath)
        .limit(1);
    if (illustrationReference.isNotEmpty) return;
    await _client.storage.from(bucketName).remove([storagePath]);
  }

  Future<void> _requireEditor() async {
    if (!await isCurriculumEditor()) {
      throw StateError('Curriculum Editor permission is required.');
    }
  }

  String? _nullable(String? value) =>
      value == null || value.trim().isEmpty ? null : value.trim();
}
