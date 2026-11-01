class CulturalStory {
  const CulturalStory({
    required this.id,
    required this.title,
    required this.summary,
    required this.region,
    required this.genre,
    required this.storyType,
    required this.culturalBackground,
    required this.sourceTitle,
    required this.sourceUrl,
    required this.coverStoragePath,
    required this.coverAltText,
    required this.coverCaption,
    required this.coverSourceTitle,
    required this.coverSourceUrl,
    required this.isPublished,
    required this.chapters,
    required this.completedChapterIds,
  });

  final String id;
  final String title;
  final String summary;
  final String? region;
  final String? genre;
  final String? storyType;
  final String? culturalBackground;
  final String? sourceTitle;
  final String? sourceUrl;
  final String? coverStoragePath;
  final String? coverAltText;
  final String? coverCaption;
  final String? coverSourceTitle;
  final String? coverSourceUrl;
  final bool isPublished;
  final List<StoryChapter> chapters;
  final Set<String> completedChapterIds;

  String get category => _nonEmpty(genre) ?? _nonEmpty(storyType) ?? 'Other';
  int get completedCount => publishedChapters
      .where((chapter) => completedChapterIds.contains(chapter.id))
      .length;
  List<StoryChapter> get publishedChapters =>
      chapters.where((chapter) => chapter.isPublished).toList();
  bool get hasPublishedChapters => publishedChapters.isNotEmpty;
  bool get isComplete =>
      hasPublishedChapters && completedCount == publishedChapters.length;
  double get completion =>
      !hasPublishedChapters ? 0 : completedCount / publishedChapters.length;
  StoryChapter? get firstUnfinishedChapter {
    for (final chapter in publishedChapters) {
      if (!completedChapterIds.contains(chapter.id)) return chapter;
    }
    return null;
  }

  StoryChapter? get continueChapter =>
      firstUnfinishedChapter ??
      (publishedChapters.isEmpty ? null : publishedChapters.last);

  CulturalStory withProgress(
    List<StoryChapter> value, {
    Set<String> completed = const {},
  }) => CulturalStory(
    id: id,
    title: title,
    summary: summary,
    region: region,
    genre: genre,
    storyType: storyType,
    culturalBackground: culturalBackground,
    sourceTitle: sourceTitle,
    sourceUrl: sourceUrl,
    coverStoragePath: coverStoragePath,
    coverAltText: coverAltText,
    coverCaption: coverCaption,
    coverSourceTitle: coverSourceTitle,
    coverSourceUrl: coverSourceUrl,
    isPublished: isPublished,
    chapters: value,
    completedChapterIds: completed,
  );

  factory CulturalStory.fromMap(
    Map<String, dynamic> row, {
    List<StoryChapter> chapters = const [],
    Set<String> completedChapterIds = const {},
  }) => CulturalStory(
    id: row['story_id'] as String,
    title: row['title'] as String? ?? '',
    summary: row['summary'] as String? ?? '',
    region: row['region'] as String?,
    genre: row['genre'] as String?,
    storyType: row['story_type'] as String?,
    culturalBackground: row['cultural_background'] as String?,
    sourceTitle: row['source_title'] as String?,
    sourceUrl: row['source_url'] as String?,
    coverStoragePath: row['cover_storage_path'] as String?,
    coverAltText: row['cover_alt_text'] as String?,
    coverCaption: row['cover_caption'] as String?,
    coverSourceTitle: row['cover_source_title'] as String?,
    coverSourceUrl: row['cover_source_url'] as String?,
    isPublished: row['is_published'] as bool? ?? false,
    chapters: chapters,
    completedChapterIds: completedChapterIds,
  );
}

class StoryChapter {
  const StoryChapter({
    required this.id,
    required this.storyId,
    required this.title,
    required this.content,
    required this.order,
    required this.sourceTitle,
    required this.sourceUrl,
    required this.isPublished,
    required this.illustrationStoragePath,
    required this.illustrationAltText,
    required this.illustrationCaption,
    required this.illustrationSourceTitle,
    required this.illustrationSourceUrl,
  });

  final String id;
  final String storyId;
  final String title;
  final String content;
  final int order;
  final String? sourceTitle;
  final String? sourceUrl;
  final bool isPublished;
  final String? illustrationStoragePath;
  final String? illustrationAltText;
  final String? illustrationCaption;
  final String? illustrationSourceTitle;
  final String? illustrationSourceUrl;

  factory StoryChapter.fromMap(Map<String, dynamic> row) => StoryChapter(
    id: row['chapter_id'] as String,
    storyId: row['story_id'] as String,
    title: row['title'] as String? ?? '',
    content: row['content'] as String? ?? '',
    order: (row['chapter_order'] as num).toInt(),
    sourceTitle: row['source_title'] as String?,
    sourceUrl: row['source_url'] as String?,
    isPublished: row['is_published'] as bool? ?? false,
    illustrationStoragePath: row['illustration_storage_path'] as String?,
    illustrationAltText: row['illustration_alt_text'] as String?,
    illustrationCaption: row['illustration_caption'] as String?,
    illustrationSourceTitle: row['illustration_source_title'] as String?,
    illustrationSourceUrl: row['illustration_source_url'] as String?,
  );
}

class StoryMetadataInput {
  const StoryMetadataInput({
    this.id,
    required this.title,
    required this.summary,
    this.region,
    this.genre,
    this.storyType,
    this.culturalBackground,
    this.sourceTitle,
    this.sourceUrl,
    this.coverStoragePath,
    this.coverAltText,
    this.coverCaption,
    this.coverSourceTitle,
    this.coverSourceUrl,
    this.isPublished = false,
  });

  final String? id;
  final String title;
  final String summary;
  final String? region;
  final String? genre;
  final String? storyType;
  final String? culturalBackground;
  final String? sourceTitle;
  final String? sourceUrl;
  final String? coverStoragePath;
  final String? coverAltText;
  final String? coverCaption;
  final String? coverSourceTitle;
  final String? coverSourceUrl;
  final bool isPublished;
}

class StoryChapterInput {
  const StoryChapterInput({
    this.id,
    required this.storyId,
    required this.title,
    required this.content,
    required this.order,
    this.sourceTitle,
    this.sourceUrl,
    this.isPublished = false,
    this.illustrationStoragePath,
    this.illustrationAltText,
    this.illustrationCaption,
    this.illustrationSourceTitle,
    this.illustrationSourceUrl,
  });

  final String? id;
  final String storyId;
  final String title;
  final String content;
  final int order;
  final String? sourceTitle;
  final String? sourceUrl;
  final bool isPublished;
  final String? illustrationStoragePath;
  final String? illustrationAltText;
  final String? illustrationCaption;
  final String? illustrationSourceTitle;
  final String? illustrationSourceUrl;
}

class StoryInspirationSelection {
  const StoryInspirationSelection({required this.storyId, required this.title});
  final String storyId;
  final String title;
}

class StoryChapterRouteArgs {
  const StoryChapterRouteArgs({
    required this.storyId,
    required this.chapterId,
    this.preview = false,
  });

  final String storyId;
  final String chapterId;
  final bool preview;
}

class StoryChapterEditorRouteArgs {
  const StoryChapterEditorRouteArgs({required this.storyId, this.chapterId});
  final String storyId;
  final String? chapterId;
}

String? _nonEmpty(String? value) =>
    value == null || value.trim().isEmpty ? null : value.trim();
