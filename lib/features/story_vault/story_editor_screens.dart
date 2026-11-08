import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../core/storage/private_media_repository.dart';
import '../../core/widgets/teatro_widgets.dart';
import '../../core/widgets/teatro_design_widgets.dart';
import 'data/story_vault_repository.dart';
import 'data/story_image_validator.dart';
import 'models/story_models.dart';
import 'story_vault_screens.dart';

class StoryEditorScreen extends StatefulWidget {
  const StoryEditorScreen({
    required this.storyId,
    required this.repository,
    required this.onBack,
    required this.onPreview,
    required this.onEditChapter,
    super.key,
  });

  final String? storyId;
  final StoryVaultRepository repository;
  final VoidCallback onBack;
  final ValueChanged<String> onPreview;
  final void Function(String storyId, String? chapterId) onEditChapter;

  @override
  State<StoryEditorScreen> createState() => _StoryEditorScreenState();
}

class _StoryEditorScreenState extends State<StoryEditorScreen> {
  final _title = TextEditingController();
  final _summary = TextEditingController();
  final _region = TextEditingController();
  final _genre = TextEditingController();
  final _storyType = TextEditingController();
  final _background = TextEditingController();
  final _sourceTitle = TextEditingController();
  final _sourceUrl = TextEditingController();
  final _coverAlt = TextEditingController();
  final _coverCaption = TextEditingController();
  final _coverSourceTitle = TextEditingController();
  final _coverSourceUrl = TextEditingController();

  String? _storyId;
  String? _coverPath;
  Uint8List? _stagedCoverBytes;
  String? _savedCoverPath;
  String? _stagedCoverPath;
  bool _coverDecorative = false;
  List<StoryChapter> _chapters = const [];
  bool _isPublished = false;
  bool _busy = false;
  bool _loaded = false;
  bool _authorized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _storyId = widget.storyId;
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final editor = await widget.repository.isCurriculumEditor();
      if (!mounted) return;
      if (!editor) {
        setState(() {
          _authorized = false;
          _loaded = true;
        });
        return;
      }
      if (_storyId != null) {
        final story = await widget.repository.loadStory(_storyId!);
        if (story == null) throw StateError('This story is unavailable.');
        _putStory(story);
      }
      if (mounted) {
        setState(() {
          _authorized = true;
          _loaded = true;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = _friendlyError(error);
          _loaded = true;
        });
      }
    }
  }

  void _putStory(CulturalStory story) {
    _storyId = story.id;
    _title.text = story.title;
    _summary.text = story.summary;
    _region.text = story.region ?? '';
    _genre.text = story.genre ?? '';
    _storyType.text = story.storyType ?? '';
    _background.text = story.culturalBackground ?? '';
    _sourceTitle.text = story.sourceTitle ?? '';
    _sourceUrl.text = story.sourceUrl ?? '';
    _coverPath = story.coverStoragePath;
    _stagedCoverBytes = null;
    _savedCoverPath = story.coverStoragePath;
    _coverAlt.text = story.coverAltText ?? '';
    _coverDecorative =
        story.coverStoragePath != null && story.coverAltText == null;
    _coverCaption.text = story.coverCaption ?? '';
    _coverSourceTitle.text = story.coverSourceTitle ?? '';
    _coverSourceUrl.text = story.coverSourceUrl ?? '';
    _isPublished = story.isPublished;
    _chapters = story.chapters;
  }

  @override
  void dispose() {
    for (final controller in [
      _title,
      _summary,
      _region,
      _genre,
      _storyType,
      _background,
      _sourceTitle,
      _sourceUrl,
      _coverAlt,
      _coverCaption,
      _coverSourceTitle,
      _coverSourceUrl,
    ]) {
      controller.dispose();
    }
    final stagedPath = _stagedCoverPath;
    if (stagedPath != null) {
      unawaited(
        widget.repository.deleteImageIfUnused(stagedPath).catchError((_) {}),
      );
    }
    super.dispose();
  }

  Future<void> _save({bool? publish}) async {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Enter a story title before saving.');
      return;
    }
    if ((publish ?? _isPublished) &&
        isKnownSeedStoryPlaceholder(
          title: _title.text,
          summary: _summary.text,
          culturalBackground: _background.text,
          sourceTitle: _sourceTitle.text,
        )) {
      setState(
        () => _error =
            'This known seed entry is not approved cultural content. Replace its placeholder summary with source-reviewed information, or unpublish it before saving.',
      );
      return;
    }
    if (_coverPath != null &&
        !_coverDecorative &&
        _coverAlt.text.trim().isEmpty) {
      setState(() => _error = 'Add alt text for the cover image.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final saved = await widget.repository.saveStory(
        StoryMetadataInput(
          id: _storyId,
          title: _title.text,
          summary: _summary.text,
          region: _region.text,
          genre: _genre.text,
          storyType: _storyType.text,
          culturalBackground: _background.text,
          sourceTitle: _sourceTitle.text,
          sourceUrl: _sourceUrl.text,
          coverStoragePath: _coverPath,
          coverAltText: _coverDecorative ? null : _coverAlt.text,
          coverCaption: _coverCaption.text,
          coverSourceTitle: _coverSourceTitle.text,
          coverSourceUrl: _coverSourceUrl.text,
          isPublished: publish ?? _isPublished,
        ),
      );
      final previousPath = _savedCoverPath;
      final previousChapters = _chapters;
      setState(() {
        _putStory(saved);
        _chapters = previousChapters;
        _stagedCoverPath = null;
        _error = null;
      });
      if (previousPath != null && previousPath != saved.coverStoragePath) {
        await _cleanup(previousPath);
      }
      _toast(saved.isPublished ? 'Story published.' : 'Story details saved.');
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickCover() async {
    final storyId = _storyId;
    if (storyId == null) {
      setState(
        () => _error = 'Save the unpublished story first, then add its cover.',
      );
      return;
    }
    try {
      final file = await FilePicker.pickFile(type: FileType.image);
      if (file == null) return;
      final fileLength = await file.length();
      if (fileLength != null && fileLength > StoryImageValidator.maxBytes) {
        throw const FormatException('Images must be 5 MiB or smaller.');
      }
      final bytes = await file.readAsBytes();
      final path = await widget.repository.uploadImage(
        storyId: storyId,
        bytes: bytes,
      );
      final previousStaged = _stagedCoverPath;
      setState(() {
        _coverPath = path;
        _stagedCoverBytes = bytes;
        _stagedCoverPath = path;
        _coverDecorative = false;
        _error = null;
      });
      if (previousStaged != null) await _cleanup(previousStaged);
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    }
  }

  Future<void> _removeCover() async {
    setState(() {
      _coverPath = null;
      _stagedCoverBytes = null;
      _coverDecorative = false;
    });
    final staged = _stagedCoverPath;
    _stagedCoverPath = null;
    if (staged != null) await _cleanup(staged);
  }

  Future<void> _cleanup(String path) async {
    try {
      await widget.repository.deleteImageIfUnused(path);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'The image changed, but an unused upload could not be removed.',
        );
      }
    }
  }

  Future<void> _reorder(int index, int direction) async {
    final next = index + direction;
    if (next < 0 || next >= _chapters.length || _storyId == null) return;
    final reordered = [..._chapters];
    final chapter = reordered.removeAt(index);
    reordered.insert(next, chapter);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.reorderChapters(
        _storyId!,
        reordered.map((item) => item.id).toList(),
      );
      final refreshed = await widget.repository.loadStory(_storyId!);
      if (mounted && refreshed != null) {
        setState(() => _chapters = refreshed.chapters);
      }
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteChapter(StoryChapter chapter) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete chapter?'),
            content: Text(
              '“${chapter.title}” will be permanently deleted. The server will reject deletion while the chapter is published or has student reading progress. Its illustration will be removed only if it is not referenced elsewhere.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete chapter'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.deleteChapter(chapter.id);
      final refreshed = await widget.repository.loadStory(_storyId!);
      if (!mounted) return;
      if (refreshed == null) throw StateError('The story is unavailable.');
      setState(() => _chapters = refreshed.chapters);
      _toast('Chapter “${chapter.title}” was deleted.');
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Center(child: CircularProgressIndicator());
    if (!_authorized) {
      return _EditorUnavailable(onBack: widget.onBack);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EditorBackButton(onPressed: widget.onBack),
        Text(
          _storyId == null ? 'Create story' : 'Edit story',
          style: Theme.of(context).textTheme.displayMedium,
        ),
        const SizedBox(height: 5),
        Text(
          'Save the story draft before adding chapters or images. Use source-verified cultural information.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: TeatroColors.muted),
        ),
        const SizedBox(height: 16),
        if (_error != null) _EditorError(message: _error!),
        if (isKnownSeedStoryPlaceholder(
          title: _title.text,
          summary: _summary.text,
          culturalBackground: _background.text,
          sourceTitle: _sourceTitle.text,
        ))
          const _EditorHint(
            'Known setup seed placeholder. Biag ni Lam-ang must be source-reviewed; do not treat this entry or its chapter text as approved cultural content.',
          ),
        _textField(_title, 'Story title', requiredField: true),
        _textField(_summary, 'Summary', maxLines: 3),
        Row(
          children: [
            Expanded(child: _textField(_region, 'Region')),
            const SizedBox(width: 10),
            Expanded(child: _textField(_genre, 'Genre / category')),
          ],
        ),
        _textField(_storyType, 'Story type'),
        _textField(_background, 'Cultural background', maxLines: 4),
        _textField(_sourceTitle, 'Source title / attribution'),
        _textField(_sourceUrl, 'Source URL'),
        const SizedBox(height: 12),
        TeatroSectionTitle(title: 'Story cover', eyebrow: 'PRIVATE MEDIA'),
        if (_storyId == null)
          const _EditorHint(
            'Save the story draft before uploading a cover image.',
          )
        else ...[
          StoryPrivateImage(
            repository: widget.repository,
            storagePath: _coverPath,
            mediaType: PrivateMediaType.storyCover,
            recordId: _storyId!,
            altText: _coverAlt.text,
            localBytes: _stagedCoverBytes,
            height: 200,
            fit: BoxFit.contain,
          ),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _busy ? null : _pickCover,
                icon: const Icon(Icons.upload_outlined),
                label: Text(
                  _coverPath == null ? 'Upload cover' : 'Replace cover',
                ),
              ),
              if (_coverPath != null)
                TextButton(
                  onPressed: _busy ? null : _removeCover,
                  child: const Text('Remove'),
                ),
            ],
          ),
          if (_coverPath != null)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _coverDecorative,
              onChanged: _busy
                  ? null
                  : (value) => setState(() {
                      _coverDecorative = value ?? false;
                      if (_coverDecorative) _coverAlt.clear();
                    }),
              title: const Text('Decorative image (no alt text)'),
              subtitle: const Text(
                'Use this when the image adds no information beyond nearby text.',
              ),
            ),
          if (_coverPath != null && !_coverDecorative)
            _textField(
              _coverAlt,
              'Cover alt text (accessibility description)',
              requiredField: true,
            ),
          _textField(_coverCaption, 'Cover caption (optional)'),
          _textField(_coverSourceTitle, 'Cover attribution title (optional)'),
          _textField(
            _coverSourceUrl,
            'Cover attribution URL (optional; source link)',
          ),
        ],
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: _busy ? null : () => _save(),
                child: Text(_busy ? 'Saving…' : 'Save story'),
              ),
            ),
            const SizedBox(width: 9),
            if (_storyId != null)
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : () => _save(publish: !_isPublished),
                  child: Text(_isPublished ? 'Unpublish' : 'Publish story'),
                ),
              ),
          ],
        ),
        if (_storyId != null) ...[
          const SizedBox(height: 22),
          TeatroSectionTitle(
            title: 'Chapters',
            eyebrow: '${_chapters.length} TOTAL',
            actionLabel: 'Add chapter',
            onAction: _busy
                ? null
                : () => widget.onEditChapter(_storyId!, null),
          ),
          if (_chapters.isEmpty)
            const _EditorHint(
              'Add source-verified chapter text before publishing this story.',
            )
          else
            for (var index = 0; index < _chapters.length; index++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _EditableChapterTile(
                  chapter: _chapters[index],
                  index: index,
                  length: _chapters.length,
                  onEdit: () =>
                      widget.onEditChapter(_storyId!, _chapters[index].id),
                  onPreview: () => widget.onPreview(_storyId!),
                  onMove: (direction) => _reorder(index, direction),
                  onDelete: () => _deleteChapter(_chapters[index]),
                ),
              ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => widget.onPreview(_storyId!),
            icon: const Icon(Icons.visibility_outlined),
            label: const Text('Preview story'),
          ),
        ],
      ],
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    bool requiredField = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 11),
    child: TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: requiredField ? '$label *' : label,
        alignLabelWithHint: maxLines > 1,
      ),
    ),
  );
}

class StoryChapterEditorScreen extends StatefulWidget {
  const StoryChapterEditorScreen({
    required this.storyId,
    required this.chapterId,
    required this.repository,
    required this.onBack,
    super.key,
  });
  final String storyId;
  final String? chapterId;
  final StoryVaultRepository repository;
  final VoidCallback onBack;

  @override
  State<StoryChapterEditorScreen> createState() =>
      _StoryChapterEditorScreenState();
}

class _StoryChapterEditorScreenState extends State<StoryChapterEditorScreen> {
  final _title = TextEditingController();
  final _content = TextEditingController();
  final _sourceTitle = TextEditingController();
  final _sourceUrl = TextEditingController();
  final _illustrationAlt = TextEditingController();
  final _illustrationCaption = TextEditingController();
  final _illustrationSourceTitle = TextEditingController();
  final _illustrationSourceUrl = TextEditingController();
  StoryChapter? _chapter;
  CulturalStory? _story;
  bool _authorized = false;
  bool _loaded = false;
  bool _busy = false;
  bool _preview = false;
  String? _illustrationPath;
  String? _savedIllustrationPath;
  String? _stagedIllustrationPath;
  bool _illustrationDecorative = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final editor = await widget.repository.isCurriculumEditor();
      if (!editor) {
        if (mounted) {
          setState(() {
            _loaded = true;
            _authorized = false;
          });
        }
        return;
      }
      final story = await widget.repository.loadStory(widget.storyId);
      if (story == null) throw StateError('This story is unavailable.');
      _story = story;
      if (widget.chapterId != null) {
        _chapter = story.chapters
            .where((item) => item.id == widget.chapterId)
            .firstOrNull;
        if (_chapter == null) throw StateError('This chapter is unavailable.');
        final chapter = _chapter!;
        _title.text = chapter.title;
        _content.text = chapter.content;
        _sourceTitle.text = chapter.sourceTitle ?? '';
        _sourceUrl.text = chapter.sourceUrl ?? '';
        _illustrationPath = chapter.illustrationStoragePath;
        _savedIllustrationPath = chapter.illustrationStoragePath;
        _illustrationAlt.text = chapter.illustrationAltText ?? '';
        _illustrationDecorative =
            chapter.illustrationStoragePath != null &&
            chapter.illustrationAltText == null;
        _illustrationCaption.text = chapter.illustrationCaption ?? '';
        _illustrationSourceTitle.text = chapter.illustrationSourceTitle ?? '';
        _illustrationSourceUrl.text = chapter.illustrationSourceUrl ?? '';
      }
      if (mounted) {
        setState(() {
          _loaded = true;
          _authorized = true;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = _friendlyError(error);
          _loaded = true;
        });
      }
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _title,
      _content,
      _sourceTitle,
      _sourceUrl,
      _illustrationAlt,
      _illustrationCaption,
      _illustrationSourceTitle,
      _illustrationSourceUrl,
    ]) {
      controller.dispose();
    }
    final staged = _stagedIllustrationPath;
    if (staged != null) {
      unawaited(
        widget.repository.deleteImageIfUnused(staged).catchError((_) {}),
      );
    }
    super.dispose();
  }

  Future<void> _pickIllustration() async {
    try {
      final file = await FilePicker.pickFile(type: FileType.image);
      if (file == null) return;
      final fileLength = await file.length();
      if (fileLength != null && fileLength > StoryImageValidator.maxBytes) {
        throw const FormatException('Images must be 5 MiB or smaller.');
      }
      final bytes = await file.readAsBytes();
      final path = await widget.repository.uploadImage(
        storyId: widget.storyId,
        chapterId: _chapter?.id,
        bytes: bytes,
      );
      final previous = _stagedIllustrationPath;
      setState(() {
        _illustrationPath = path;
        _stagedIllustrationPath = path;
        _illustrationDecorative = false;
        _error = null;
      });
      if (previous != null) await _cleanup(previous);
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    }
  }

  Future<void> _save({bool? publish}) async {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Enter a chapter title before saving.');
      return;
    }
    if (publish == true && _content.text.trim().isEmpty) {
      setState(
        () => _error = 'Add source-verified chapter text before publishing.',
      );
      return;
    }
    if (_illustrationPath != null &&
        !_illustrationDecorative &&
        _illustrationAlt.text.trim().isEmpty) {
      setState(() => _error = 'Add alt text for the chapter illustration.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final saved = await widget.repository.saveChapter(
        StoryChapterInput(
          id: _chapter?.id,
          storyId: widget.storyId,
          title: _title.text,
          content: _content.text,
          order: _chapter?.order ?? (_story!.chapters.length + 1),
          sourceTitle: _sourceTitle.text,
          sourceUrl: _sourceUrl.text,
          isPublished: publish ?? (_chapter?.isPublished ?? false),
          illustrationStoragePath: _illustrationPath,
          illustrationAltText: _illustrationDecorative
              ? null
              : _illustrationAlt.text,
          illustrationCaption: _illustrationCaption.text,
          illustrationSourceTitle: _illustrationSourceTitle.text,
          illustrationSourceUrl: _illustrationSourceUrl.text,
        ),
      );
      final previous = _savedIllustrationPath;
      setState(() {
        _chapter = saved;
        _savedIllustrationPath = saved.illustrationStoragePath;
        _stagedIllustrationPath = null;
      });
      if (previous != null && previous != saved.illustrationStoragePath) {
        await _cleanup(previous);
      }
      _toast(
        saved.isPublished ? 'Chapter published.' : 'Chapter saved as a draft.',
      );
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeIllustration() async {
    setState(() {
      _illustrationPath = null;
      _illustrationDecorative = false;
    });
    final staged = _stagedIllustrationPath;
    _stagedIllustrationPath = null;
    if (staged != null) await _cleanup(staged);
  }

  Future<void> _cleanup(String path) async {
    try {
      await widget.repository.deleteImageIfUnused(path);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'An unused image upload could not be removed.');
      }
    }
  }

  void _toast(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Center(child: CircularProgressIndicator());
    if (!_authorized) return _EditorUnavailable(onBack: widget.onBack);
    if (_story == null) {
      return _EditorError(message: _error ?? 'Story unavailable.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EditorBackButton(onPressed: widget.onBack),
        Text(
          _chapter == null ? 'Add chapter' : 'Edit chapter',
          style: Theme.of(context).textTheme.displayMedium,
        ),
        const SizedBox(height: 5),
        Text(
          '${_story!.title} · Chapter order ${_chapter?.order ?? _story!.chapters.length + 1}',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: TeatroColors.muted),
        ),
        const SizedBox(height: 15),
        if (_error != null) _EditorError(message: _error!),
        _textField(_title, 'Chapter title *'),
        _textField(_content, 'Chapter text', minLines: 10),
        _textField(_sourceTitle, 'Chapter source title (optional)'),
        _textField(_sourceUrl, 'Chapter source URL (optional)'),
        const SizedBox(height: 12),
        TeatroSectionTitle(
          title: 'Chapter illustration',
          eyebrow: 'OPTIONAL PRIVATE MEDIA',
        ),
        if (_chapter == null)
          const _EditorHint(
            'Save the chapter draft before uploading an illustration.',
          )
        else ...[
          StoryPrivateImage(
            repository: widget.repository,
            storagePath: _illustrationPath,
            mediaType: PrivateMediaType.chapterIllustration,
            recordId: _chapter!.id,
            altText: _illustrationAlt.text,
            height: 220,
            fit: BoxFit.contain,
          ),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _busy ? null : _pickIllustration,
                icon: const Icon(Icons.upload_outlined),
                label: Text(
                  _illustrationPath == null
                      ? 'Upload illustration'
                      : 'Replace illustration',
                ),
              ),
              if (_illustrationPath != null)
                TextButton(
                  onPressed: _busy ? null : _removeIllustration,
                  child: const Text('Remove'),
                ),
            ],
          ),
          if (_illustrationPath != null)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _illustrationDecorative,
              onChanged: _busy
                  ? null
                  : (value) => setState(() {
                      _illustrationDecorative = value ?? false;
                      if (_illustrationDecorative) _illustrationAlt.clear();
                    }),
              title: const Text('Decorative image (no alt text)'),
              subtitle: const Text(
                'Use this when the illustration adds no information beyond nearby text.',
              ),
            ),
          if (_illustrationPath != null && !_illustrationDecorative)
            _textField(
              _illustrationAlt,
              'Illustration alt text (accessibility description)',
              minLines: 1,
            ),
          _textField(_illustrationCaption, 'Illustration caption (optional)'),
          _textField(
            _illustrationSourceTitle,
            'Illustration attribution title (optional)',
          ),
          _textField(
            _illustrationSourceUrl,
            'Illustration attribution URL (optional; source link)',
          ),
        ],
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: _busy ? null : () => _save(),
                child: Text(_busy ? 'Saving…' : 'Save draft'),
              ),
            ),
            const SizedBox(width: 9),
            if (_chapter != null)
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => _save(publish: !_chapter!.isPublished),
                  child: Text(
                    _chapter!.isPublished
                        ? 'Unpublish chapter'
                        : 'Publish chapter',
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 13),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _preview = !_preview),
            icon: Icon(
              _preview
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
            label: Text(_preview ? 'Hide preview' : 'Preview chapter'),
          ),
        ),
        if (_preview) ...[
          const SizedBox(height: 7),
          TeatroCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title.text.isEmpty ? 'Chapter preview' : _title.text,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 10),
                SelectableText(
                  _content.text,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(height: 1.7),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label, {
    int minLines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 11),
    child: TextField(
      controller: controller,
      minLines: minLines,
      maxLines: minLines == 1 ? 1 : null,
      decoration: InputDecoration(
        labelText: label,
        alignLabelWithHint: minLines > 1,
      ),
    ),
  );
}

class _EditableChapterTile extends StatelessWidget {
  const _EditableChapterTile({
    required this.chapter,
    required this.index,
    required this.length,
    required this.onEdit,
    required this.onPreview,
    required this.onMove,
    required this.onDelete,
  });
  final StoryChapter chapter;
  final int index;
  final int length;
  final VoidCallback onEdit;
  final VoidCallback onPreview;
  final ValueChanged<int> onMove;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => TeatroCard(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    child: Row(
      children: [
        Text(
          '${chapter.order}',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: TeatroColors.rust),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                chapter.title,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(
                chapter.isPublished ? 'Published' : 'Draft',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: chapter.isPublished
                      ? TeatroColors.success
                      : TeatroColors.muted,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Move chapter up',
          onPressed: index == 0 ? null : () => onMove(-1),
          icon: const Icon(Icons.keyboard_arrow_up),
        ),
        IconButton(
          tooltip: 'Move chapter down',
          onPressed: index >= length - 1 ? null : () => onMove(1),
          icon: const Icon(Icons.keyboard_arrow_down),
        ),
        IconButton(
          tooltip: 'Preview story',
          onPressed: onPreview,
          icon: const Icon(Icons.visibility_outlined),
        ),
        IconButton(
          tooltip: 'Edit chapter',
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined),
        ),
        IconButton(
          tooltip: 'Delete chapter',
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    ),
  );
}

class _EditorBackButton extends StatelessWidget {
  const _EditorBackButton({required this.onPressed});
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.arrow_back, size: 16),
      label: const Text('Story Vault'),
      style: TextButton.styleFrom(foregroundColor: TeatroColors.muted),
    ),
  );
}

class _EditorUnavailable extends StatelessWidget {
  const _EditorUnavailable({required this.onBack});
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      const _EditorError(
        message: 'Story management requires Curriculum Editor permission.',
      ),
      TextButton.icon(
        onPressed: onBack,
        icon: const Icon(Icons.arrow_back),
        label: const Text('Return to Story Vault'),
      ),
    ],
  );
}

class _EditorError extends StatelessWidget {
  const _EditorError({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF5E3D8),
      borderRadius: BorderRadius.circular(7),
    ),
    child: Text(
      message,
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: TeatroColors.rust),
    ),
  );
}

class _EditorHint extends StatelessWidget {
  const _EditorHint(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => TeatroCard(
    padding: const EdgeInsets.all(13),
    child: Text(
      message,
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: TeatroColors.muted),
    ),
  );
}

String _friendlyError(Object error) {
  final text = error.toString();
  if (text.contains('Curriculum Editor permission')) {
    return 'This action requires Curriculum Editor permission.';
  }
  if (text.contains('Publish at least one chapter')) {
    return 'Publish at least one chapter before publishing the story.';
  }
  if (text.contains('Unpublish the story before')) {
    return 'Unpublish the story before unpublishing its last chapter.';
  }
  if (text.contains('row-level security') || text.contains('42501')) {
    return 'Supabase did not authorize this action for the current account.';
  }
  return text.replaceFirst('Exception: ', '');
}
