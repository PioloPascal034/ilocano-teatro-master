import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../../app/app_theme.dart';
import '../../core/widgets/teatro_widgets.dart';
import '../../core/widgets/teatro_design_widgets.dart';
import '../../core/storage/private_media_repository.dart';
import 'data/story_vault_repository.dart';
import 'models/story_models.dart';

class StoryVaultScreen extends StatefulWidget {
  const StoryVaultScreen({
    required this.role,
    required this.repository,
    required this.onOpenStory,
    required this.onReadChapter,
    required this.onUseStory,
    required this.onEditStory,
    super.key,
  });

  final AppRole role;
  final StoryVaultRepository repository;
  final ValueChanged<String> onOpenStory;
  final void Function(String storyId, String chapterId, {bool preview})
  onReadChapter;
  final ValueChanged<StoryInspirationSelection> onUseStory;
  final ValueChanged<String?> onEditStory;

  @override
  State<StoryVaultScreen> createState() => _StoryVaultScreenState();
}

class _StoryVaultScreenState extends State<StoryVaultScreen> {
  final _search = TextEditingController();
  late Future<_LibraryData> _future;
  String _category = 'All';
  String _completion = 'All';
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<_LibraryData> _load() async {
    final editor = await widget.repository.isCurriculumEditor();
    final stories = await widget.repository.loadStories();
    return _LibraryData(editor: editor, stories: stories);
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_LibraryData>(
    future: _future,
    builder: (context, snapshot) {
      final loadedStories = snapshot.data?.stories ?? const <CulturalStory>[];
      final stories = snapshot.data?.editor == true
          ? loadedStories
          : loadedStories
                .where(
                  (story) => story.isPublished && !story.needsContentReview,
                )
                .toList();
      final categories = <String>{
        'All',
        ...stories
            .map((story) => story.category)
            .where((value) => value != 'Other'),
      }.toList();
      final visible = stories.where((story) {
        final matchesSearch = story.title.toLowerCase().contains(
          _query.trim().toLowerCase(),
        );
        final matchesCategory =
            _category == 'All' || story.category == _category;
        final matchesCompletion = switch (_completion) {
          'Completed' => story.isComplete,
          'In progress' => story.completedCount > 0 && !story.isComplete,
          'Not started' =>
            story.completedCount == 0 && story.hasPublishedChapters,
          _ => true,
        };
        return matchesSearch && matchesCategory && matchesCompletion;
      }).toList();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TeatroPageIntro(
            eyebrow: widget.role == AppRole.student
                ? 'CULTURAL STORYTELLING'
                : 'CURRICULUM LIBRARY',
            title: 'Ilocano Story Vault',
            description:
                'Explore published cultural stories and continue at your own pace.',
            trailing: Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Refresh stories',
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh),
                ),
                if (snapshot.data?.editor == true)
                  FilledButton.icon(
                    onPressed: () => widget.onEditStory(null),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('New story'),
                  ),
              ],
            ),
          ),
          if (snapshot.hasError)
            _LoadError(onRetry: _reload)
          else if (!snapshot.hasData)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(35),
                child: CircularProgressIndicator(),
              ),
            )
          else ...[
            _LibraryFilters(
              search: _search,
              category: _category,
              categories: categories,
              completion: _completion,
              onSearch: (value) => setState(() => _query = value),
              onCategory: (value) => setState(() => _category = value),
              onCompletion: (value) => setState(() => _completion = value),
              showCompletion: widget.role == AppRole.student,
            ),
            const SizedBox(height: 17),
            if (stories.isEmpty) ...[
              _EmptyVault(
                editor: snapshot.data!.editor,
                onCreate: () => widget.onEditStory(null),
              ),
            ] else if (visible.isEmpty)
              const TeatroEmptyState(
                title: 'No stories match these filters',
                description:
                    'Try a different title, category, or reading status.',
                icon: Icons.search_off_outlined,
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth <= 700
                      ? 1
                      : constraints.maxWidth <= 1050
                      ? 2
                      : 3;
                  final width =
                      (constraints.maxWidth - (columns - 1) * 14) / columns;
                  return Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: [
                      for (final story in visible)
                        SizedBox(
                          width: width,
                          child: _StoryCard(
                            story: story,
                            repository: widget.repository,
                            showProgress: widget.role == AppRole.student,
                            showInspiration: widget.role == AppRole.student,
                            canEdit: snapshot.data!.editor,
                            onOpen: () => widget.onOpenStory(story.id),
                            onContinue:
                                widget.role != AppRole.student ||
                                    story.continueChapter == null
                                ? null
                                : () => widget.onReadChapter(
                                    story.id,
                                    story.continueChapter!.id,
                                    preview: false,
                                  ),
                            onUse: () => widget.onUseStory(
                              StoryInspirationSelection(
                                storyId: story.id,
                                title: story.title,
                              ),
                            ),
                            onEdit: () => widget.onEditStory(story.id),
                          ),
                        ),
                    ],
                  );
                },
              ),
          ],
        ],
      );
    },
  );
}

class _LibraryData {
  const _LibraryData({required this.editor, required this.stories});
  final bool editor;
  final List<CulturalStory> stories;
}

class _LibraryFilters extends StatelessWidget {
  const _LibraryFilters({
    required this.search,
    required this.category,
    required this.categories,
    required this.completion,
    required this.onSearch,
    required this.onCategory,
    required this.onCompletion,
    required this.showCompletion,
  });

  final TextEditingController search;
  final String category;
  final List<String> categories;
  final String completion;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onCategory;
  final ValueChanged<String> onCompletion;
  final bool showCompletion;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const TeatroEyebrow('STORY GENRE'),
      TextField(
        controller: search,
        onChanged: onSearch,
        decoration: const InputDecoration(
          hintText: 'Search by story title',
          prefixIcon: Icon(Icons.search, size: 19),
          isDense: true,
        ),
      ),
      const SizedBox(height: 10),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final value in categories)
              Padding(
                padding: const EdgeInsets.only(right: 7),
                child: _FilterChip(
                  label: value,
                  selected: category == value,
                  onTap: () => onCategory(value),
                ),
              ),
          ],
        ),
      ),
      if (showCompletion) ...[
        const SizedBox(height: 8),
        const TeatroEyebrow('READING STATUS'),
        const SizedBox(height: 5),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final value in const [
                'All',
                'Not started',
                'In progress',
                'Completed',
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 7),
                  child: _FilterChip(
                    label: value,
                    selected: completion == value,
                    onTap: () => onCompletion(value),
                  ),
                ),
            ],
          ),
        ),
      ],
    ],
  );
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ChoiceChip(
    label: Text(label),
    selected: selected,
    showCheckmark: false,
    onSelected: (_) => onTap(),
    selectedColor: const Color(0xFFF2EEE5),
    backgroundColor: TeatroColors.paper,
    side: BorderSide(
      color: selected ? const Color(0xFFD9CFC0) : TeatroColors.line,
    ),
    labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
      color: selected ? TeatroColors.rust : TeatroColors.muted,
    ),
  );
}

class _StoryCard extends StatelessWidget {
  const _StoryCard({
    required this.story,
    required this.repository,
    required this.showProgress,
    required this.showInspiration,
    required this.canEdit,
    required this.onOpen,
    required this.onContinue,
    required this.onUse,
    required this.onEdit,
  });
  final CulturalStory story;
  final StoryVaultRepository repository;
  final bool showProgress;
  final bool showInspiration;
  final bool canEdit;
  final VoidCallback onOpen;
  final VoidCallback? onContinue;
  final VoidCallback onUse;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => TeatroCard(
    padding: EdgeInsets.zero,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StoryPrivateImage(
          repository: repository,
          storagePath: story.coverStoragePath,
          mediaType: PrivateMediaType.storyCover,
          recordId: story.id,
          altText: story.coverAltText,
          height: 150,
          fit: BoxFit.cover,
        ),
        Padding(
          padding: const EdgeInsets.all(17),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 7,
                runSpacing: 5,
                children: [
                  _Tag(story.category),
                  if (!story.isPublished)
                    const _Tag('Draft', color: TeatroColors.rust),
                  if (canEdit && story.needsContentReview)
                    const _Tag(
                      'Seed placeholder · review required',
                      color: TeatroColors.error,
                    ),
                  if (showProgress && story.isComplete)
                    const _Tag('Completed', color: TeatroColors.success),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                story.title,
                style: Theme.of(context).textTheme.headlineMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                story.summary,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: TeatroColors.muted),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              if (showProgress && story.hasPublishedChapters) ...[
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: story.completion,
                  minHeight: 5,
                  color: TeatroColors.rust,
                  backgroundColor: const Color(0xFFE8E0D5),
                ),
                const SizedBox(height: 5),
                Text(
                  '${(story.completion * 100).round()}% complete · ${story.publishedChapters.length} chapters',
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: TeatroColors.muted),
                ),
              ] else if (story.isPublished && story.chapters.isEmpty) ...[
                const SizedBox(height: 9),
                Text(
                  'No chapters are published yet.',
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: TeatroColors.muted),
                ),
              ],
              const SizedBox(height: 13),
              Wrap(
                spacing: 7,
                runSpacing: 6,
                children: [
                  OutlinedButton(
                    onPressed: onOpen,
                    child: const Text('Overview'),
                  ),
                  if (onContinue != null)
                    FilledButton.tonal(
                      onPressed: onContinue,
                      child: Text(
                        showProgress && story.isComplete
                            ? 'Read again'
                            : 'Continue reading',
                      ),
                    ),
                  if (showInspiration)
                    TextButton.icon(
                      onPressed: onUse,
                      icon: const Icon(Icons.auto_awesome_outlined, size: 16),
                      label: const Text('Use as inspiration'),
                    ),
                  if (canEdit)
                    TextButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Edit'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class StoryOverviewScreen extends StatefulWidget {
  const StoryOverviewScreen({
    required this.storyId,
    required this.role,
    required this.repository,
    required this.onBack,
    required this.onReadChapter,
    required this.onUseStory,
    required this.onEditStory,
    super.key,
  });

  final String storyId;
  final AppRole role;
  final StoryVaultRepository repository;
  final VoidCallback onBack;
  final void Function(String storyId, String chapterId, {bool preview})
  onReadChapter;
  final ValueChanged<StoryInspirationSelection> onUseStory;
  final ValueChanged<String> onEditStory;

  @override
  State<StoryOverviewScreen> createState() => _StoryOverviewScreenState();
}

class _StoryOverviewScreenState extends State<StoryOverviewScreen> {
  late Future<_OverviewData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_OverviewData> _load() async {
    final story = await widget.repository.loadStory(widget.storyId);
    final editor = await widget.repository.isCurriculumEditor();
    return _OverviewData(story: story, editor: editor);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_OverviewData>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _LoadError(
          onRetry: () => setState(() {
            _future = _load();
          }),
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final story = snapshot.data!.story;
      if (story == null) {
        return _UnavailableStory(onBack: widget.onBack);
      }
      final canContinue = story.continueChapter;
      final canEdit = snapshot.data!.editor;
      if (!canEdit && !story.isPublished) {
        return _UnavailableStory(onBack: widget.onBack);
      }
      if (!canEdit && story.needsContentReview) {
        return _UnavailableStory(onBack: widget.onBack);
      }
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _BackButton(onBack: widget.onBack),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 650;
                final cover = StoryPrivateImage(
                  repository: widget.repository,
                  storagePath: story.coverStoragePath,
                  mediaType: PrivateMediaType.storyCover,
                  recordId: story.id,
                  altText: story.coverAltText,
                  width: compact ? double.infinity : 260,
                  height: compact ? 210 : 260,
                  fit: BoxFit.cover,
                );
                final metadata = _StoryMetadata(story: story);
                return compact
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [cover, const SizedBox(height: 18), metadata],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 260, child: cover),
                          const SizedBox(width: 24),
                          Expanded(child: metadata),
                        ],
                      );
              },
            ),
            if (widget.role == AppRole.student &&
                story.hasPublishedChapters) ...[
              const SizedBox(height: 19),
              _ProgressPanel(story: story),
            ],
            if (canEdit && story.needsContentReview) ...[
              const SizedBox(height: 14),
              const _InlineNotice(
                text:
                    'Known setup seed placeholder. Verify and replace its cultural summary, sources, and chapter content before publication.',
              ),
            ],
            const SizedBox(height: 24),
            TeatroSectionTitle(
              title: 'Chapters',
              eyebrow: '${story.publishedChapters.length} PUBLISHED',
              actionLabel: widget.role == AppRole.student && canContinue != null
                  ? (story.isComplete ? 'Read again' : 'Continue reading')
                  : null,
              onAction: canContinue == null
                  ? null
                  : () => widget.onReadChapter(
                      story.id,
                      canContinue.id,
                      preview: false,
                    ),
            ),
            if (story.chapters.isEmpty)
              const TeatroEmptyState(
                title: 'No chapters published yet',
                description:
                    'This story overview is available, but its chapter text is not published yet.',
                icon: Icons.menu_book_outlined,
              )
            else
              for (final chapter in story.chapters)
                if (canEdit || chapter.isPublished)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: _ChapterTile(
                      chapter: chapter,
                      completed: story.completedChapterIds.contains(chapter.id),
                      showCompletion: widget.role == AppRole.student,
                      onRead: () => widget.onReadChapter(
                        story.id,
                        chapter.id,
                        preview: !chapter.isPublished,
                      ),
                    ),
                  ),
            if (widget.role == AppRole.student) ...[
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: () => widget.onUseStory(
                    StoryInspirationSelection(
                      storyId: story.id,
                      title: story.title,
                    ),
                  ),
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: const Text('Use as theme inspiration'),
                ),
              ),
            ] else if (canEdit) ...[
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => widget.onEditStory(story.id),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit story and chapters'),
                ),
              ),
            ],
          ],
        ),
      );
    },
  );
}

class _OverviewData {
  const _OverviewData({required this.story, required this.editor});
  final CulturalStory? story;
  final bool editor;
}

class _StoryMetadata extends StatelessWidget {
  const _StoryMetadata({required this.story});
  final CulturalStory story;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: 7,
        children: [
          _Tag(story.category),
          if (story.region?.trim().isNotEmpty == true) _Tag(story.region!),
          if (!story.isPublished) const _Tag('Draft', color: TeatroColors.rust),
        ],
      ),
      const SizedBox(height: 8),
      Text(story.title, style: Theme.of(context).textTheme.displayMedium),
      const SizedBox(height: 10),
      Text(
        story.summary,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.55),
      ),
      if (story.coverCaption?.trim().isNotEmpty == true) ...[
        const SizedBox(height: 5),
        Text(
          story.coverCaption!,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: TeatroColors.muted),
        ),
      ],
      const SizedBox(height: 17),
      _InfoCard(
        title: 'Cultural background',
        content: story.culturalBackground,
      ),
      const SizedBox(height: 10),
      _InfoCard(
        title: 'Source & attribution',
        content: story.sourceTitle,
        secondary: story.sourceUrl,
      ),
      if (story.coverSourceTitle?.trim().isNotEmpty == true ||
          story.coverSourceUrl?.trim().isNotEmpty == true) ...[
        const SizedBox(height: 4),
        Text(
          'Cover image: ${story.coverSourceTitle?.trim().isNotEmpty == true ? story.coverSourceTitle : story.coverSourceUrl}',
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: TeatroColors.muted),
        ),
      ],
    ],
  );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.content, this.secondary});
  final String title;
  final String? content;
  final String? secondary;

  @override
  Widget build(BuildContext context) => TeatroCard(
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 5),
        Text(
          content?.trim().isNotEmpty == true
              ? content!
              : 'No information provided.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            height: 1.5,
            color: TeatroColors.muted,
          ),
        ),
        if (secondary?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 4),
          SelectableText(
            secondary!,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: TeatroColors.rust),
          ),
        ],
      ],
    ),
  );
}

class _ProgressPanel extends StatelessWidget {
  const _ProgressPanel({required this.story});
  final CulturalStory story;

  @override
  Widget build(BuildContext context) => TeatroCard(
    padding: const EdgeInsets.all(15),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                story.isComplete ? 'Story completed' : 'Your reading progress',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text(
              '${(story.completion * 100).round()}%',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: TeatroColors.rust),
            ),
          ],
        ),
        const SizedBox(height: 9),
        LinearProgressIndicator(
          value: story.completion,
          minHeight: 6,
          color: TeatroColors.rust,
          backgroundColor: const Color(0xFFE8E0D5),
        ),
        const SizedBox(height: 6),
        Text(
          '${story.completedCount} of ${story.publishedChapters.length} published chapters marked as read',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: TeatroColors.muted),
        ),
      ],
    ),
  );
}

class _ChapterTile extends StatelessWidget {
  const _ChapterTile({
    required this.chapter,
    required this.completed,
    required this.showCompletion,
    required this.onRead,
  });
  final StoryChapter chapter;
  final bool completed;
  final bool showCompletion;
  final VoidCallback onRead;

  @override
  Widget build(BuildContext context) => TeatroCard(
    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
    child: Row(
      children: [
        CircleAvatar(
          radius: 17,
          backgroundColor: const Color(0xFFF2EEE5),
          child: Text(
            '${chapter.order}',
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: TeatroColors.rust),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                chapter.title,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              if (!chapter.isPublished)
                Text(
                  'Unpublished preview',
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: TeatroColors.rust),
                ),
            ],
          ),
        ),
        if (showCompletion && completed)
          const Icon(Icons.check_circle, color: TeatroColors.success, size: 19),
        TextButton(
          onPressed: onRead,
          child: Text(
            showCompletion && completed ? 'Read again' : 'Read chapter',
          ),
        ),
      ],
    ),
  );
}

class StoryChapterReaderScreen extends StatefulWidget {
  const StoryChapterReaderScreen({
    required this.storyId,
    required this.chapterId,
    required this.preview,
    required this.role,
    required this.repository,
    required this.onNavigate,
    super.key,
  });
  final String storyId;
  final String chapterId;
  final bool preview;
  final AppRole role;
  final StoryVaultRepository repository;
  final void Function(AppDestination, Object?) onNavigate;

  @override
  State<StoryChapterReaderScreen> createState() =>
      _StoryChapterReaderScreenState();
}

class _StoryChapterReaderScreenState extends State<StoryChapterReaderScreen> {
  late Future<CulturalStory?> _future;
  bool _marking = false;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.loadStory(widget.storyId);
  }

  Future<void> _markRead() async {
    setState(() => _marking = true);
    try {
      await widget.repository.markChapterRead(widget.chapterId);
      if (mounted) {
        setState(() {
          _future = widget.repository.loadStory(widget.storyId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chapter marked as read.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_friendlyError(error))));
      }
    } finally {
      if (mounted) setState(() => _marking = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<CulturalStory?>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _LoadError(
          onRetry: () => setState(() {
            _future = widget.repository.loadStory(widget.storyId);
          }),
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final story = snapshot.data;
      if (story == null) {
        return _UnavailableStory(
          onBack: () => widget.onNavigate(AppDestination.storyVault, null),
        );
      }
      final readingChapters = widget.role == AppRole.teacher && widget.preview
          ? story.chapters
          : story.publishedChapters;
      final index = readingChapters.indexWhere(
        (chapter) => chapter.id == widget.chapterId,
      );
      if (index < 0) {
        return _UnavailableStory(
          onBack: () => widget.onNavigate(AppDestination.storyDetail, story.id),
        );
      }
      final chapter = readingChapters[index];
      if ((!story.isPublished || !chapter.isPublished) &&
          !(widget.role == AppRole.teacher && widget.preview)) {
        return _UnavailableStory(
          onBack: () => widget.onNavigate(AppDestination.storyDetail, story.id),
        );
      }
      if (widget.role == AppRole.student && story.needsContentReview) {
        return _UnavailableStory(
          onBack: () => widget.onNavigate(AppDestination.storyVault, null),
        );
      }
      final done = story.completedChapterIds.contains(chapter.id);
      final hasReadableText = chapter.content.trim().isNotEmpty;
      final canMark =
          widget.role == AppRole.student &&
          chapter.isPublished &&
          !done &&
          hasReadableText;
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 850),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _BackButton(
              onBack: () =>
                  widget.onNavigate(AppDestination.storyDetail, story.id),
              label: story.title,
            ),
            if (widget.preview || !chapter.isPublished || !story.isPublished)
              const _InlineNotice(
                text:
                    'Preview mode · this story or chapter is not published to students.',
              ),
            if (story.isPublished &&
                story.hasPublishedChapters &&
                widget.role == AppRole.student)
              _ProgressPanel(story: story),
            const SizedBox(height: 14),
            TeatroEyebrow(
              'CHAPTER ${index + 1} OF ${readingChapters.length}',
              color: TeatroColors.rust,
            ),
            const SizedBox(height: 5),
            Text(
              chapter.title,
              style: Theme.of(context).textTheme.displayMedium,
            ),
            if (done) ...[
              const SizedBox(height: 8),
              const _Tag('Completed', color: TeatroColors.success),
            ],
            if (chapter.illustrationStoragePath != null) ...[
              const SizedBox(height: 18),
              StoryPrivateImage(
                repository: widget.repository,
                storagePath: chapter.illustrationStoragePath,
                mediaType: PrivateMediaType.chapterIllustration,
                recordId: chapter.id,
                altText: chapter.illustrationAltText,
                height: 250,
                fit: BoxFit.contain,
              ),
              if (chapter.illustrationCaption?.trim().isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    chapter.illustrationCaption!,
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: TeatroColors.muted),
                  ),
                ),
            ],
            const SizedBox(height: 18),
            if (hasReadableText)
              TeatroCard(
                padding: const EdgeInsets.all(22),
                child: SelectableText(
                  chapter.content,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(height: 1.8),
                ),
              )
            else
              const TeatroEmptyState(
                title: 'Chapter text is not available',
                description:
                    'This chapter has no saved text. Ask a Curriculum Editor to add source-verified content. It has not been marked as read.',
                icon: Icons.menu_book_outlined,
              ),
            if (chapter.illustrationSourceTitle?.trim().isNotEmpty == true ||
                chapter.illustrationSourceUrl?.trim().isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  'Illustration source: ${chapter.illustrationSourceTitle?.trim().isNotEmpty == true ? chapter.illustrationSourceTitle : chapter.illustrationSourceUrl}',
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: TeatroColors.muted),
                ),
              ),
            if (chapter.sourceTitle?.trim().isNotEmpty == true ||
                chapter.sourceUrl?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 12),
              _InfoCard(
                title: 'Chapter source',
                content: chapter.sourceTitle,
                secondary: chapter.sourceUrl,
              ),
            ],
            const SizedBox(height: 16),
            if (canMark)
              Align(
                alignment: Alignment.center,
                child: FilledButton.icon(
                  onPressed: _marking ? null : _markRead,
                  icon: _marking
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: const Text('Mark as Read'),
                ),
              )
            else if (done)
              const Center(
                child: _Tag(
                  'This chapter is marked as read',
                  color: TeatroColors.success,
                ),
              ),
            const SizedBox(height: 17),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: index == 0
                        ? null
                        : () => widget.onNavigate(
                            AppDestination.storyChapter,
                            StoryChapterRouteArgs(
                              storyId: story.id,
                              chapterId: readingChapters[index - 1].id,
                              preview: widget.preview,
                            ),
                          ),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Previous'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: index >= readingChapters.length - 1
                        ? null
                        : () => widget.onNavigate(
                            AppDestination.storyChapter,
                            StoryChapterRouteArgs(
                              storyId: story.id,
                              chapterId: readingChapters[index + 1].id,
                              preview: widget.preview,
                            ),
                          ),
                    iconAlignment: IconAlignment.end,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Next'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

class StoryPrivateImage extends StatefulWidget {
  const StoryPrivateImage({
    required this.repository,
    required this.storagePath,
    required this.mediaType,
    required this.recordId,
    required this.altText,
    this.localBytes,
    this.height = 170,
    this.width,
    this.fit = BoxFit.cover,
    super.key,
  });
  final StoryVaultRepository repository;
  final String? storagePath;
  final PrivateMediaType mediaType;
  final String recordId;
  final String? altText;
  final Uint8List? localBytes;
  final double height;
  final double? width;
  final BoxFit fit;

  @override
  State<StoryPrivateImage> createState() => _StoryPrivateImageState();
}

class _StoryPrivateImageState extends State<StoryPrivateImage> {
  Future<Uint8List>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant StoryPrivateImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.storagePath != widget.storagePath ||
        oldWidget.repository != widget.repository ||
        oldWidget.mediaType != widget.mediaType ||
        oldWidget.recordId != widget.recordId ||
        oldWidget.localBytes != widget.localBytes) {
      _load();
    }
  }

  void _load() {
    final path = widget.storagePath;
    final localBytes = widget.localBytes;
    _future = localBytes != null
        ? Future.value(localBytes)
        : path == null || path.isEmpty
        ? null
        : widget.repository.downloadImage(
            type: widget.mediaType,
            recordId: widget.recordId,
            cacheVersion: path,
          );
  }

  @override
  Widget build(BuildContext context) {
    final path = widget.storagePath;
    if (path == null || path.isEmpty) {
      return _ImagePlaceholder(height: widget.height, width: widget.width);
    }
    return FutureBuilder<Uint8List>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return snapshot.hasError
              ? _ImageFailure(
                  height: widget.height,
                  width: widget.width,
                  onRetry: () => setState(_load),
                )
              : SizedBox(
                  height: widget.height,
                  width: widget.width,
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
        }
        final image = Image.memory(
          snapshot.data!,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          errorBuilder: (_, error, stackTrace) {
            if (kDebugMode) {
              debugPrint(
                'Story Vault image decode failed for "${widget.storagePath}": $error',
              );
              debugPrintStack(stackTrace: stackTrace);
            }
            return _ImageFailure(
              height: widget.height,
              width: widget.width,
              onRetry: () => setState(_load),
            );
          },
        );
        if (widget.altText?.trim().isNotEmpty != true) {
          return ExcludeSemantics(child: image);
        }
        return Semantics(image: true, label: widget.altText, child: image);
      },
    );
  }
}

class _ImageFailure extends StatelessWidget {
  const _ImageFailure({
    required this.height,
    required this.onRetry,
    this.width,
  });

  final double height;
  final double? width;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    width: width,
    color: const Color(0xFFF2EEE5),
    alignment: Alignment.center,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.broken_image_outlined, color: TeatroColors.muted),
        const SizedBox(height: 4),
        const Text('Image unavailable'),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Retry'),
        ),
      ],
    ),
  );
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({this.height = 170, this.width});
  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    width: width,
    color: const Color(0xFFF2EEE5),
    alignment: Alignment.center,
    child: const Icon(
      Icons.auto_stories_outlined,
      color: TeatroColors.muted,
      size: 34,
    ),
  );
}

class _Tag extends StatelessWidget {
  const _Tag(this.label, {this.color = TeatroColors.muted});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: color,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onBack, this.label = 'Story Vault'});
  final VoidCallback onBack;
  final String label;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: TextButton.icon(
      onPressed: onBack,
      icon: const Icon(Icons.arrow_back, size: 16),
      label: Text(label),
      style: TextButton.styleFrom(foregroundColor: TeatroColors.muted),
    ),
  );
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF4EEE0),
      borderRadius: BorderRadius.circular(7),
    ),
    child: Text(text, style: Theme.of(context).textTheme.bodySmall),
  );
}

class _EmptyVault extends StatelessWidget {
  const _EmptyVault({required this.editor, required this.onCreate});
  final bool editor;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const TeatroEmptyState(
        title: 'No published stories yet',
        description:
            'Stories will appear here after their verified chapter content is published.',
        icon: Icons.menu_book_outlined,
      ),
      if (editor) ...[
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.add),
          label: const Text('Create a story draft'),
        ),
      ],
    ],
  );
}

class _UnavailableStory extends StatelessWidget {
  const _UnavailableStory({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const TeatroEmptyState(
        title: 'Story unavailable',
        description:
            'This story may have been unpublished or is not available to this account.',
        icon: Icons.lock_outline,
      ),
      TextButton.icon(
        onPressed: onBack,
        icon: const Icon(Icons.arrow_back),
        label: const Text('Return to Story Vault'),
      ),
    ],
  );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const TeatroEmptyState(
        title: 'Story Vault unavailable',
        description:
            'Stories could not be loaded. Check your connection and retry.',
        icon: Icons.cloud_off_outlined,
      ),
      TextButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: const Text('Retry'),
      ),
    ],
  );
}

String _friendlyError(Object error) {
  final text = error.toString();
  if (text.contains('Curriculum Editor permission')) {
    return 'This action requires Curriculum Editor permission.';
  }
  if (text.contains('Publish at least one chapter')) {
    return 'Publish at least one chapter before publishing this story.';
  }
  if (text.contains('Unpublish the story before')) {
    return 'Unpublish the story before unpublishing its last chapter.';
  }
  if (text.contains('row-level security') || text.contains('42501')) {
    return 'Supabase did not authorize this action for the current account.';
  }
  return text.replaceFirst('Exception: ', '');
}
