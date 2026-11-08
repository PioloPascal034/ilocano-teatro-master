import 'dart:typed_data';

import 'package:ilocano_teatro_master/core/storage/private_media_repository.dart';
import 'package:ilocano_teatro_master/features/story_vault/data/story_image_validator.dart';
import 'package:ilocano_teatro_master/features/story_vault/data/story_vault_repository.dart';
import 'package:ilocano_teatro_master/features/story_vault/models/story_models.dart';

class FakeStoryVaultRepository implements StoryVaultRepository {
  FakeStoryVaultRepository({
    List<CulturalStory> stories = const [],
    this.editor = false,
    this.failUploads = false,
    this.failDownloads = false,
    this.failChapterCleanup = false,
  }) : stories = [...stories];

  final List<CulturalStory> stories;
  final Map<String, Uint8List> images = {};
  final Set<String> readChapterIds = {};
  final List<List<String>> reorderRequests = [];
  bool editor;
  bool failUploads;
  bool failDownloads;
  bool failChapterCleanup;
  int downloadCalls = 0;
  int _nextStory = 0;
  int _nextChapter = 0;

  @override
  Future<bool> isCurriculumEditor() async => editor;

  @override
  Future<List<CulturalStory>> loadStories() async => [...stories];

  @override
  Future<CulturalStory?> loadStory(String storyId) async {
    for (final story in stories) {
      if (story.id == storyId) return story;
    }
    return null;
  }

  @override
  Future<CulturalStory> saveStory(StoryMetadataInput input) async {
    _requireEditor();
    final index = stories.indexWhere((story) => story.id == input.id);
    if (input.isPublished &&
        (index < 0 || stories[index].publishedChapters.isEmpty)) {
      throw StateError(
        'Publish at least one chapter before publishing a story',
      );
    }
    final previous = index < 0 ? null : stories[index];
    final saved = CulturalStory(
      id: input.id ?? 'story-${++_nextStory}',
      title: input.title,
      summary: input.summary,
      region: input.region,
      genre: input.genre,
      storyType: input.storyType,
      culturalBackground: input.culturalBackground,
      sourceTitle: input.sourceTitle,
      sourceUrl: input.sourceUrl,
      coverStoragePath: input.coverStoragePath,
      coverAltText: input.coverAltText,
      coverCaption: input.coverCaption,
      coverSourceTitle: input.coverSourceTitle,
      coverSourceUrl: input.coverSourceUrl,
      isPublished: input.id == null ? false : input.isPublished,
      chapters: previous?.chapters ?? const [],
      completedChapterIds: previous?.completedChapterIds ?? const {},
    );
    if (index < 0) {
      stories.add(saved);
    } else {
      stories[index] = saved;
    }
    return saved;
  }

  @override
  Future<void> deleteStory(String storyId) async {
    _requireEditor();
    final index = stories.indexWhere((story) => story.id == storyId);
    if (index < 0) throw StateError('Story not found');
    final story = stories.removeAt(index);
    images.removeWhere(
      (path, _) =>
          path == story.coverStoragePath ||
          story.chapters.any(
            (chapter) => chapter.illustrationStoragePath == path,
          ),
    );
  }

  @override
  Future<StoryChapter> saveChapter(StoryChapterInput input) async {
    _requireEditor();
    final storyIndex = stories.indexWhere((story) => story.id == input.storyId);
    if (storyIndex < 0) throw StateError('Story not found');
    final story = stories[storyIndex];
    final chapterId = input.id ?? 'chapter-${++_nextChapter}';
    final chapter = StoryChapter(
      id: chapterId,
      storyId: input.storyId,
      title: input.title,
      content: input.content,
      order: input.order,
      sourceTitle: input.sourceTitle,
      sourceUrl: input.sourceUrl,
      isPublished: input.id == null ? false : input.isPublished,
      illustrationStoragePath: input.illustrationStoragePath,
      illustrationAltText: input.illustrationAltText,
      illustrationCaption: input.illustrationCaption,
      illustrationSourceTitle: input.illustrationSourceTitle,
      illustrationSourceUrl: input.illustrationSourceUrl,
    );
    final chapters = [...story.chapters];
    final chapterIndex = chapters.indexWhere((item) => item.id == chapterId);
    if (chapterIndex < 0) {
      chapters.add(chapter);
    } else {
      chapters[chapterIndex] = chapter;
    }
    stories[storyIndex] = story.withProgress(
      chapters,
      completed: story.completedChapterIds,
    );
    return chapter;
  }

  @override
  Future<void> deleteChapter(String chapterId) async {
    _requireEditor();
    for (var storyIndex = 0; storyIndex < stories.length; storyIndex++) {
      final story = stories[storyIndex];
      final chapterIndex = story.chapters.indexWhere(
        (chapter) => chapter.id == chapterId,
      );
      if (chapterIndex < 0) continue;
      final chapter = story.chapters[chapterIndex];
      if (chapter.isPublished) {
        throw StateError('Unpublish the chapter before deleting it');
      }
      if (story.completedChapterIds.contains(chapterId)) {
        throw StateError('Chapter has student reading progress');
      }
      if (failChapterCleanup) {
        throw StateError('Chapter illustration cleanup failed');
      }
      final chapters = [...story.chapters]..removeAt(chapterIndex);
      final normalized = [
        for (var i = 0; i < chapters.length; i++)
          _copyChapter(chapters[i], order: i + 1),
      ];
      stories[storyIndex] = story.withProgress(
        normalized,
        completed: {...story.completedChapterIds}..remove(chapterId),
      );
      return;
    }
    throw StateError('Chapter not found');
  }

  @override
  Future<void> reorderChapters(String storyId, List<String> chapterIds) async {
    _requireEditor();
    reorderRequests.add([...chapterIds]);
    final storyIndex = stories.indexWhere((story) => story.id == storyId);
    if (storyIndex < 0) throw StateError('Story not found');
    final story = stories[storyIndex];
    final ordered = <StoryChapter>[];
    for (var i = 0; i < chapterIds.length; i++) {
      final chapter = story.chapters.firstWhere(
        (item) => item.id == chapterIds[i],
      );
      ordered.add(_copyChapter(chapter, order: i + 1));
    }
    stories[storyIndex] = story.withProgress(
      ordered,
      completed: story.completedChapterIds,
    );
  }

  @override
  Future<void> markChapterRead(String chapterId) async {
    readChapterIds.add(chapterId);
    for (var storyIndex = 0; storyIndex < stories.length; storyIndex++) {
      final story = stories[storyIndex];
      if (story.chapters.any((chapter) => chapter.id == chapterId)) {
        stories[storyIndex] = story.withProgress(
          story.chapters,
          completed: {...story.completedChapterIds, chapterId},
        );
        return;
      }
    }
    throw StateError('Chapter not found');
  }

  @override
  Future<Uint8List> downloadImage({
    required PrivateMediaType type,
    required String recordId,
    required String cacheVersion,
  }) async {
    downloadCalls++;
    if (failDownloads) throw StateError('Storage download failed');
    final bytes = images[cacheVersion];
    if (bytes == null) throw StateError('Image unavailable');
    return bytes;
  }

  @override
  Future<String> uploadImage({
    required String storyId,
    String? chapterId,
    required Uint8List bytes,
  }) async {
    _requireEditor();
    if (failUploads) throw StateError('Storage upload failed');
    final format = StoryImageValidator.validate(bytes);
    final path = chapterId == null
        ? '$storyId/cover/fake.${format.extension}'
        : '$storyId/chapters/$chapterId/fake.${format.extension}';
    images[path] = bytes;
    return path;
  }

  @override
  Future<void> deleteImageIfUnused(String storagePath) async {
    final used = stories.any(
      (story) =>
          story.coverStoragePath == storagePath ||
          story.chapters.any(
            (chapter) => chapter.illustrationStoragePath == storagePath,
          ),
    );
    if (!used) images.remove(storagePath);
  }

  void _requireEditor() {
    if (!editor) throw StateError('Curriculum Editor permission is required.');
  }
}

CulturalStory storyFixture({
  String id = 'story-1',
  String title = 'Test cultural story',
  String summary = 'A test summary.',
  String genre = 'Legend',
  bool isPublished = true,
  String? coverStoragePath,
  String? coverAltText,
  List<StoryChapter> chapters = const [],
  Set<String> completed = const {},
}) => CulturalStory(
  id: id,
  title: title,
  summary: summary,
  region: 'Ilocos',
  genre: genre,
  storyType: 'Folklore',
  culturalBackground: 'Verified cultural context.',
  sourceTitle: 'Test source',
  sourceUrl: null,
  coverStoragePath: coverStoragePath,
  coverAltText: coverAltText,
  coverCaption: null,
  coverSourceTitle: null,
  coverSourceUrl: null,
  isPublished: isPublished,
  chapters: chapters,
  completedChapterIds: completed,
);

StoryChapter chapterFixture({
  String id = 'chapter-1',
  String storyId = 'story-1',
  String title = 'Chapter one',
  String content = 'Test chapter content.',
  int order = 1,
  bool published = true,
}) => StoryChapter(
  id: id,
  storyId: storyId,
  title: title,
  content: content,
  order: order,
  sourceTitle: null,
  sourceUrl: null,
  isPublished: published,
  illustrationStoragePath: null,
  illustrationAltText: null,
  illustrationCaption: null,
  illustrationSourceTitle: null,
  illustrationSourceUrl: null,
);

StoryChapter _copyChapter(StoryChapter chapter, {required int order}) =>
    StoryChapter(
      id: chapter.id,
      storyId: chapter.storyId,
      title: chapter.title,
      content: chapter.content,
      order: order,
      sourceTitle: chapter.sourceTitle,
      sourceUrl: chapter.sourceUrl,
      isPublished: chapter.isPublished,
      illustrationStoragePath: chapter.illustrationStoragePath,
      illustrationAltText: chapter.illustrationAltText,
      illustrationCaption: chapter.illustrationCaption,
      illustrationSourceTitle: chapter.illustrationSourceTitle,
      illustrationSourceUrl: chapter.illustrationSourceUrl,
    );
