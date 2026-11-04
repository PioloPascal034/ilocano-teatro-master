import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/app_theme.dart';
import '../learning/lesson_article_body.dart';
import '../learning/models/lesson_reading_time.dart';
import 'models/curriculum_models.dart';
import 'lesson_unload_guard.dart';

class LessonEditorDialog extends StatefulWidget {
  const LessonEditorDialog({
    super.key,
    required this.module,
    this.lesson,
    required this.supportsMetadata,
    required this.onSave,
  });

  final CurriculumModule module;
  final CurriculumLesson? lesson;
  final bool supportsMetadata;
  final Future<void> Function(
    String title,
    String? objectives,
    String content,
    Map<String, String> sections,
    String overview,
    int minutes,
  )
  onSave;

  @override
  State<LessonEditorDialog> createState() => _LessonEditorDialogState();
}

class _LessonEditorDialogState extends State<LessonEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _unloadGuard = LessonUnloadGuard();
  late final Map<String, TextEditingController> _fields;
  late String _baseline;
  late String _lastText;
  late bool _structured;
  bool _saving = false;
  bool _savedOnce = false;
  bool _confirmingExit = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final lesson = widget.lesson;
    _structured = lesson == null || lesson.sections.isNotEmpty;
    _fields = {
      'title': TextEditingController(text: lesson?.title ?? ''),
      'overview': TextEditingController(text: lesson?.overview ?? ''),
      'introduction': TextEditingController(
        text: lesson?.sections['introduction'] ?? '',
      ),
      'objectives': TextEditingController(text: lesson?.objectives ?? ''),
      'discussion': TextEditingController(
        text: lesson?.sections['discussion'] ?? lesson?.content ?? '',
      ),
      for (final key in ['examples', 'activities', 'summary'])
        key: TextEditingController(text: lesson?.sections[key] ?? ''),
    };
    _baseline = _snapshot;
    _lastText = _baseline;
    for (final field in _fields.values) {
      field.addListener(_changed);
    }
  }

  String _text(String key) => _fields[key]!.text;
  String get _snapshot =>
      jsonEncode([_structured, ..._fields.values.map((field) => field.text)]);
  bool get _dirty => _snapshot != _baseline;
  String get _status => _saving
      ? 'Saving'
      : _error != null
      ? 'Save Failed'
      : _dirty || (widget.lesson == null && !_savedOnce)
      ? 'Unsaved'
      : 'Saved';
  Map<String, String> get _sections => !_structured
      ? const {}
      : {
          for (final key in [
            'introduction',
            'discussion',
            'examples',
            'activities',
            'summary',
          ])
            key: _text(key),
        };
  int get _minutes => lessonReadingMinutes(
    content: _text('discussion'),
    sections: _sections,
    objectives: _text('objectives'),
    overview: _text('overview'),
  );

  void _changed() {
    final current = _snapshot;
    if (!mounted || current == _lastText) return;
    _lastText = current;
    _unloadGuard.update(_dirty || _saving);
    setState(() {
      _error = null;
    });
  }

  @override
  void dispose() {
    _unloadGuard.dispose();
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    _unloadGuard.update(true);
    try {
      await widget.onSave(
        _text('title'),
        _text('objectives'),
        _text('discussion'),
        _sections,
        _text('overview'),
        _minutes,
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _savedOnce = true;
        _baseline = _snapshot;
      });
      _unloadGuard.update(false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error is PostgrestException
            ? error.message
            : error is StateError
            ? error.message
            : 'The lesson could not be saved. Please try again.';
      });
    }
  }

  Future<void> _close() async {
    if (_saving || _confirmingExit) return;
    if (_dirty) {
      _confirmingExit = true;
      final discard = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Discard unsaved changes?'),
          content: const Text('Your latest lesson edits have not been saved.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Keep editing'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
      _confirmingExit = false;
      if (discard != true) return;
    }
    if (mounted) Navigator.pop(context);
  }

  void _applyTemplate(String template) {
    // Templates fill only empty fields so they never replace a teacher's text.
    final values = switch (template) {
      'discussion' => {
        'introduction': 'Introduce the topic and its Ilocano cultural context.',
        'objectives': 'Identify the key ideas.\nExplain their role in theater.',
        'discussion':
            '## Key ideas\nExplain the ideas using a source-reviewed text.',
        'examples': '> Add a short dialogue excerpt or cultural example.',
        'activities':
            '- Discuss the characters and their choices.\n- Explain the evidence.',
        'summary': 'Summarize the ideas learners should remember.',
      },
      'exercise' => {
        'introduction':
            'Describe the purpose and setting of the theater exercise.',
        'objectives': 'Practise voice, movement, and collaboration.',
        'discussion':
            '## Preparation\nDescribe the space, materials, and safety considerations.',
        'activities':
            '1. Warm up together.\n2. Rehearse a short scene.\n3. Reflect on the performance.',
        'summary':
            'Connect the performance choices to the learning objectives.',
      },
      _ => {
        'introduction':
            'Introduce the scene, characters, and dramatic conflict.',
        'objectives': 'Write dialogue and clear stage directions.',
        'discussion':
            '## Building a scene\nExplain character goals, conflict, and dramatic action.',
        'examples':
            '**CHARACTER:** Add Ilocano dialogue here.\n*[Stage direction]*',
        'activities':
            '- Draft a short scene.\n- Read it aloud.\n- Revise the dialogue and stage directions.',
        'summary': 'Review the writing choices that made the scene clearer.',
      },
    };
    _structured = true;
    for (final entry in values.entries) {
      if (_text(entry.key).trim().isEmpty) {
        _fields[entry.key]!.text = entry.value;
      }
    }
    _changed();
  }

  Future<void> _preview() async {
    FocusScope.of(context).unfocus();
    await showDialog<void>(
      context: context,
      builder: (previewContext) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text('Preview as Student — current edits'),
                    ),
                    IconButton(
                      tooltip: 'Close preview',
                      onPressed: () => Navigator.pop(previewContext),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: LessonArticleBody(
                    title: _text('title').trim().isEmpty
                        ? 'Untitled lesson'
                        : _text('title'),
                    objectives: _text('objectives'),
                    content: _text('discussion'),
                    sections: _sections,
                    overview: _text('overview'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    String key,
    String label, {
    int lines = 3,
    bool required = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      key: ValueKey('lesson-$key'),
      controller: _fields[key],
      enabled: !_saving,
      minLines: lines,
      maxLines: lines == 1 ? 1 : lines + 6,
      keyboardType: lines == 1 ? TextInputType.text : TextInputType.multiline,
      textInputAction: lines == 1
          ? TextInputAction.next
          : TextInputAction.newline,
      decoration: InputDecoration(labelText: label, alignLabelWithHint: true),
      validator: required
          ? (value) => value == null || value.trim().isEmpty
                ? 'Enter ${label.toLowerCase()}.'
                : null
          : null,
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_dirty && !_saving,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) _close();
    },
    child: LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 700;
        return Dialog(
          insetPadding: EdgeInsets.all(compact ? 8 : 28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.lesson == null && !_savedOnce
                                  ? 'Add lesson'
                                  : 'Edit lesson',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            Text(
                              'MODULE · ${widget.module.title}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                '$_status · $_minutes min read',
                                key: const ValueKey('lesson-save-status'),
                                style: TextStyle(
                                  color: _error == null
                                      ? TeatroColors.muted
                                      : TeatroColors.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close lesson editor',
                        onPressed: _saving ? null : _close,
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                if (_saving) const LinearProgressIndicator(),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: TeatroColors.error),
                    ),
                  ),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(compact ? 16 : 24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _field(
                            'title',
                            'Lesson title',
                            lines: 1,
                            required: true,
                          ),
                          if (widget.supportsMetadata)
                            _field(
                              'overview',
                              'Lesson overview (optional)',
                              lines: 2,
                            ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: PopupMenuButton<String>(
                              tooltip: 'Lesson templates',
                              enabled: !_saving,
                              onSelected: _applyTemplate,
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                  value: 'discussion',
                                  child: Text('Discussion lesson'),
                                ),
                                PopupMenuItem(
                                  value: 'exercise',
                                  child: Text('Theater exercise'),
                                ),
                                PopupMenuItem(
                                  value: 'playwriting',
                                  child: Text('Playwriting example'),
                                ),
                              ],
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Text('Use a lesson template ▾'),
                              ),
                            ),
                          ),
                          const Text(
                            'Templates fill empty fields only. Review the prompts before publishing.',
                          ),
                          const SizedBox(height: 12),
                          if (!_structured) ...[
                            const Text(
                              'This is a legacy plain-text lesson. Its formatting is preserved.',
                            ),
                            TextButton(
                              onPressed: _saving
                                  ? null
                                  : () {
                                      _structured = true;
                                      _changed();
                                    },
                              child: const Text('Use structured sections'),
                            ),
                          ],
                          if (_structured) ...[
                            const Text(
                              'Formatting: # Heading, **bold**, *italic*, - list, 1. numbered list, > quote. Keep dialogue and stage directions on their own lines.',
                            ),
                            const SizedBox(height: 16),
                            _field(
                              'introduction',
                              'Introduction',
                              required: widget.lesson == null,
                            ),
                          ],
                          _field('objectives', 'Learning objectives', lines: 2),
                          _field(
                            'discussion',
                            _structured ? 'Main discussion' : 'Lesson content',
                            lines: 6,
                            required: true,
                          ),
                          if (_structured) ...[
                            _field('examples', 'Examples (optional)'),
                            _field('activities', 'Activities (optional)'),
                            _field('summary', 'Summary (optional)'),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _saving ? null : _close,
                        child: Text(_savedOnce ? 'Done' : 'Cancel'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _saving ? null : _preview,
                        icon: const Icon(Icons.visibility_outlined),
                        label: const Text('Preview as Student'),
                      ),
                      FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: const Icon(Icons.save_outlined),
                        label: Text(_saving ? 'Saving…' : 'Save lesson'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
