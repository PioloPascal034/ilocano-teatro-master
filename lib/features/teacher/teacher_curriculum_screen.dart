import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/app_theme.dart';
import '../../core/widgets/teatro_widgets.dart';
import '../prototype/prototype_widgets.dart';
import 'data/curriculum_repository.dart';
import 'models/curriculum_models.dart';

class TeacherCurriculumScreen extends StatefulWidget {
  const TeacherCurriculumScreen({required this.repository, super.key});

  final CurriculumRepository repository;

  @override
  State<TeacherCurriculumScreen> createState() =>
      _TeacherCurriculumScreenState();
}

class _TeacherCurriculumScreenState extends State<TeacherCurriculumScreen> {
  late Future<_CurriculumPageData> _page;
  String? _selectedModuleId;
  String? _previewLessonId;
  bool _actionBusy = false;

  @override
  void initState() {
    super.initState();
    _page = _load();
  }

  @override
  void didUpdateWidget(covariant TeacherCurriculumScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) _refresh();
  }

  Future<_CurriculumPageData> _load() async {
    final canEdit = await widget.repository.isCurriculumEditor();
    final modules = await widget.repository.loadModules();
    return _CurriculumPageData(canEdit: canEdit, modules: modules);
  }

  void _refresh() => setState(() {
    _page = _load();
  });

  @override
  Widget build(BuildContext context) => FutureBuilder<_CurriculumPageData>(
    future: _page,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _PageState(
          title: 'Learning content could not be loaded',
          message: _errorText(snapshot.error!),
          action: TextButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        );
      }
      if (!snapshot.hasData) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(40),
            child: CircularProgressIndicator(),
          ),
        );
      }

      final data = snapshot.data!;
      final module = data.moduleById(_selectedModuleId);
      if (module != null) return _modulePage(context, data, module);
      return _moduleListPage(context, data);
    },
  );

  Widget _moduleListPage(BuildContext context, _CurriculumPageData data) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DemoPageIntro(
            eyebrow: 'APPROVED CURRICULUM',
            title: 'Learning content',
            description: data.canEdit
                ? 'Manage modules and lessons for your students.'
                : 'Browse the published curriculum available to students.',
          ),
          if (data.canEdit)
            Align(
              alignment: Alignment.centerRight,
              child: DemoPrimaryButton(
                label: 'Create module',
                icon: Icons.add,
                onPressed: _actionBusy ? null : () => _editModule(),
              ),
            ),
          const SizedBox(height: 12),
          if (data.modules.isEmpty)
            DemoEmptyState(
              title: 'No published modules yet',
              description: data.canEdit
                  ? 'Create a module to begin building the curriculum.'
                  : 'Published learning modules will appear here.',
              icon: Icons.menu_book_outlined,
            )
          else
            Column(
              children: [
                if (!data.canEdit) ...[
                  const _ReadOnlyNotice(),
                  const SizedBox(height: 12),
                ],
                for (final module in data.modules)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ModuleCard(
                      module: module,
                      canEdit: data.canEdit && !_actionBusy,
                      busy: _actionBusy,
                      onManage: () => setState(() {
                        _selectedModuleId = module.id;
                        _previewLessonId = null;
                      }),
                      onEdit: () => _editModule(module),
                      onPublish: () => _confirmModulePublication(module),
                    ),
                  ),
              ],
            ),
        ],
      );

  Widget _modulePage(
    BuildContext context,
    _CurriculumPageData data,
    CurriculumModule module,
  ) {
    final preview = _lessonById(module.lessons, _previewLessonId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DemoBackButton(
          label: 'All learning content',
          onPressed: () => setState(() {
            _selectedModuleId = null;
            _previewLessonId = null;
          }),
        ),
        DemoPageIntro(
          eyebrow:
              'MODULE ${module.displayOrder.toString().padLeft(2, '0')} \\u00B7 ${module.isPublished ? 'PUBLISHED' : 'UNPUBLISHED'}',
          title: module.title,
          description: module.description.isEmpty
              ? 'No module description provided.'
              : module.description,
        ),
        if (data.canEdit)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              DemoActionButton(
                label: 'Edit module',
                icon: Icons.edit_outlined,
                onPressed: _actionBusy ? null : () => _editModule(module),
              ),
              DemoPrimaryButton(
                label: 'Add lesson',
                icon: Icons.add,
                onPressed: _actionBusy ? null : () => _editLesson(module),
              ),
              DemoActionButton(
                label: module.isPublished ? 'Unpublish' : 'Publish',
                icon: module.isPublished
                    ? Icons.visibility_off_outlined
                    : Icons.publish_outlined,
                onPressed: _actionBusy
                    ? null
                    : () => _confirmModulePublication(module),
              ),
            ],
          )
        else
          Align(
            alignment: Alignment.centerLeft,
            child: DemoStatus(
              status: module.isPublished ? 'Published' : 'Unpublished',
            ),
          ),
        const SizedBox(height: 12),
        if (_actionBusy) const LinearProgressIndicator(),
        if (!data.canEdit) ...[
          const _ReadOnlyNotice(),
          const SizedBox(height: 12),
        ],
        TeatroCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: TeatroEyebrow('LESSONS IN THIS MODULE'),
                    ),
                    Text(
                      '${module.lessons.length} lessons',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: TeatroColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              if (module.lessons.isEmpty)
                DemoEmptyState(
                  title: 'No lessons in this module yet',
                  description: data.canEdit
                      ? 'Add a lesson to start building this module.'
                      : 'Lessons will appear after they are added and published.',
                  icon: Icons.menu_book_outlined,
                )
              else
                for (var index = 0; index < module.lessons.length; index++)
                  _LessonRow(
                    lesson: module.lessons[index],
                    index: index,
                    count: module.lessons.length,
                    canEdit: data.canEdit && !_actionBusy,
                    onPreview: () => setState(
                      () => _previewLessonId = module.lessons[index].id,
                    ),
                    onEdit: () => _editLesson(module, module.lessons[index]),
                    onPublish: () =>
                        _confirmLessonPublication(module.lessons[index]),
                    onMove: (direction) =>
                        _moveLesson(module, index, direction),
                  ),
            ],
          ),
        ),
        if (preview != null) ...[
          const SizedBox(height: 18),
          _LessonPreview(module: module, lesson: preview),
        ],
      ],
    );
  }

  Future<void> _editModule([CurriculumModule? module]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _ModuleFormDialog(
        module: module,
        onSave: (title, description) async {
          if (module == null) {
            final created = await widget.repository.createModule(
              title: title,
              description: description,
            );
            _selectedModuleId = created.id;
          } else {
            await widget.repository.updateModule(
              moduleId: module.id,
              title: title,
              description: description,
            );
          }
        },
      ),
    );
    if (saved == true && mounted) {
      _refresh();
      _showMessage(
        module == null ? 'Module saved as unpublished.' : 'Module updated.',
      );
    }
  }

  Future<void> _editLesson(
    CurriculumModule module, [
    CurriculumLesson? lesson,
  ]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _LessonFormDialog(
        module: module,
        lesson: lesson,
        onSave: (title, objectives, content) async {
          if (lesson == null) {
            await widget.repository.createLesson(
              moduleId: module.id,
              title: title,
              objectives: objectives,
              content: content,
            );
          } else {
            await widget.repository.updateLesson(
              lessonId: lesson.id,
              title: title,
              objectives: objectives,
              content: content,
            );
          }
        },
      ),
    );
    if (saved == true && mounted) {
      _refresh();
      _showMessage(
        lesson == null ? 'Lesson saved as unpublished.' : 'Lesson updated.',
      );
    }
  }

  Future<void> _confirmModulePublication(CurriculumModule module) async {
    final publish = !module.isPublished;
    final confirmed = await _confirm(
      title: publish ? 'Publish module?' : 'Unpublish module?',
      message: publish
          ? 'Students will be able to see this module and its published lessons.'
          : 'Students will no longer see this module. Existing progress records will be kept.',
      confirmLabel: publish ? 'Publish module' : 'Unpublish module',
    );
    if (!confirmed) return;
    await _perform(
      () => widget.repository.setModulePublished(
        moduleId: module.id,
        isPublished: publish,
      ),
    );
  }

  Future<void> _confirmLessonPublication(CurriculumLesson lesson) async {
    final publish = !lesson.isPublished;
    final confirmed = await _confirm(
      title: publish ? 'Publish lesson?' : 'Unpublish lesson?',
      message: publish
          ? 'Students can read this lesson when its parent module is published.'
          : 'Students will no longer see this lesson. Existing progress records will be kept.',
      confirmLabel: publish ? 'Publish lesson' : 'Unpublish lesson',
    );
    if (!confirmed) return;
    await _perform(
      () => widget.repository.setLessonPublished(
        lessonId: lesson.id,
        isPublished: publish,
      ),
    );
  }

  Future<void> _moveLesson(
    CurriculumModule module,
    int index,
    int direction,
  ) async {
    final target = index + direction;
    if (target < 0 || target >= module.lessons.length) return;
    final ids = module.lessons.map((lesson) => lesson.id).toList();
    final moved = ids.removeAt(index);
    ids.insert(target, moved);
    await _perform(
      () =>
          widget.repository.reorderLessons(moduleId: module.id, lessonIds: ids),
    );
  }

  Future<void> _perform(Future<void> Function() action) async {
    setState(() => _actionBusy = true);
    try {
      await action();
      if (!mounted) return;
      _refresh();
      _showMessage('Curriculum changes saved.');
    } catch (error) {
      if (mounted) _showMessage(_errorText(error), isError: true);
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(confirmLabel),
            ),
          ],
        ),
      ) ??
      false;

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? TeatroColors.error : null,
      ),
    );
  }
}

class _CurriculumPageData {
  const _CurriculumPageData({required this.canEdit, required this.modules});

  final bool canEdit;
  final List<CurriculumModule> modules;

  CurriculumModule? moduleById(String? id) {
    if (id == null) return null;
    for (final module in modules) {
      if (module.id == id) return module;
    }
    return null;
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.module,
    required this.canEdit,
    required this.busy,
    required this.onManage,
    required this.onEdit,
    required this.onPublish,
  });

  final CurriculumModule module;
  final bool canEdit;
  final bool busy;
  final VoidCallback onManage;
  final VoidCallback onEdit;
  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) => TeatroCard(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 590;
        final summary = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    module.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                DemoStatus(
                  status: module.isPublished ? 'Published' : 'Unpublished',
                ),
              ],
            ),
            if (module.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                module.description,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: TeatroColors.muted),
              ),
            ],
            const SizedBox(height: 5),
            Text(
              '${module.lessons.length} lessons',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: TeatroColors.muted),
            ),
          ],
        );
        final actions = Wrap(
          spacing: 7,
          runSpacing: 6,
          children: [
            DemoActionButton(
              label: 'Manage lessons',
              icon: Icons.chevron_right,
              onPressed: onManage,
            ),
            if (canEdit) ...[
              DemoActionButton(
                label: 'Edit module',
                icon: Icons.edit_outlined,
                onPressed: busy ? null : onEdit,
              ),
              DemoActionButton(
                label: module.isPublished ? 'Unpublish' : 'Publish',
                icon: module.isPublished
                    ? Icons.visibility_off_outlined
                    : Icons.publish_outlined,
                onPressed: busy ? null : onPublish,
              ),
            ],
          ],
        );
        return compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [summary, const SizedBox(height: 12), actions],
              )
            : Row(
                children: [
                  Expanded(child: summary),
                  const SizedBox(width: 12),
                  actions,
                ],
              );
      },
    ),
  );
}

class _LessonRow extends StatelessWidget {
  const _LessonRow({
    required this.lesson,
    required this.index,
    required this.count,
    required this.canEdit,
    required this.onPreview,
    required this.onEdit,
    required this.onPublish,
    required this.onMove,
  });

  final CurriculumLesson lesson;
  final int index;
  final int count;
  final bool canEdit;
  final VoidCallback onPreview;
  final VoidCallback onEdit;
  final VoidCallback onPublish;
  final ValueChanged<int> onMove;

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: TeatroColors.line)),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 570;
        final title = Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF2EEE5),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                '${lesson.lessonOrder}'.padLeft(2, '0'),
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                lesson.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            DemoStatus(
              status: lesson.isPublished ? 'Published' : 'Unpublished',
            ),
          ],
        );
        final actions = Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            TextButton.icon(
              onPressed: onPreview,
              icon: const Icon(Icons.visibility_outlined, size: 16),
              label: const Text('Preview'),
            ),
            if (canEdit) ...[
              IconButton(
                tooltip: 'Move lesson up',
                onPressed: index == 0 ? null : () => onMove(-1),
                icon: const Icon(Icons.arrow_upward, size: 18),
              ),
              IconButton(
                tooltip: 'Move lesson down',
                onPressed: index == count - 1 ? null : () => onMove(1),
                icon: const Icon(Icons.arrow_downward, size: 18),
              ),
              TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit'),
              ),
              TextButton.icon(
                onPressed: onPublish,
                icon: Icon(
                  lesson.isPublished
                      ? Icons.visibility_off_outlined
                      : Icons.publish_outlined,
                  size: 16,
                ),
                label: Text(lesson.isPublished ? 'Unpublish' : 'Publish'),
              ),
            ],
          ],
        );
        return compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [title, const SizedBox(height: 5), actions],
              )
            : Row(
                children: [
                  Expanded(child: title),
                  const SizedBox(width: 8),
                  actions,
                ],
              );
      },
    ),
  );
}

class _LessonPreview extends StatelessWidget {
  const _LessonPreview({required this.module, required this.lesson});

  final CurriculumModule module;
  final CurriculumLesson lesson;

  @override
  Widget build(BuildContext context) {
    final paragraphs = lesson.content
        .split(RegExp(r'\r?\n\s*\r?\n'))
        .map((text) => text.trim())
        .where((text) => text.isNotEmpty)
        .toList();
    final objectives =
        lesson.objectives
            ?.split(RegExp(r'\r?\n|\s*;\s*'))
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty)
            .toList() ??
        const <String>[];
    return TeatroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TeatroEyebrow(
            'LESSON PREVIEW · ${module.title.toUpperCase()}',
            color: TeatroColors.rust,
          ),
          const SizedBox(height: 7),
          Text(lesson.title, style: Theme.of(context).textTheme.displayMedium),
          const SizedBox(height: 16),
          if (objectives.isNotEmpty) ...[
            Text(
              'Learning objectives',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 7),
            for (final objective in objectives)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  '•  $objective',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 13),
          ],
          Text('Lesson content', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (paragraphs.isEmpty)
            Text(
              'No lesson content provided.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: TeatroColors.muted),
            )
          else
            for (final paragraph in paragraphs)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SelectableText(
                  paragraph,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(height: 1.7),
                ),
              ),
        ],
      ),
    );
  }
}

class _ModuleFormDialog extends StatefulWidget {
  const _ModuleFormDialog({required this.module, required this.onSave});

  final CurriculumModule? module;
  final Future<void> Function(String title, String description) onSave;

  @override
  State<_ModuleFormDialog> createState() => _ModuleFormDialogState();
}

class _ModuleFormDialogState extends State<_ModuleFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.module?.title ?? '');
  late final _description = TextEditingController(
    text: widget.module?.description ?? '',
  );
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(_title.text, _description.text);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = _errorText(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.module == null ? 'Create module' : 'Edit module'),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _title,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Module title'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a module title.'
                    : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _description,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              if (_error != null) _FormError(_error!),
              if (_saving) const LinearProgressIndicator(),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context, false),
        child: const Text('Cancel'),
      ),
      DemoPrimaryButton(
        label: _saving ? 'Saving…' : 'Save module',
        icon: Icons.save_outlined,
        onPressed: _saving ? null : _save,
      ),
    ],
  );
}

class _LessonFormDialog extends StatefulWidget {
  const _LessonFormDialog({
    required this.module,
    required this.lesson,
    required this.onSave,
  });

  final CurriculumModule module;
  final CurriculumLesson? lesson;
  final Future<void> Function(String title, String? objectives, String content)
  onSave;

  @override
  State<_LessonFormDialog> createState() => _LessonFormDialogState();
}

class _LessonFormDialogState extends State<_LessonFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.lesson?.title ?? '');
  late final _objectives = TextEditingController(
    text: widget.lesson?.objectives ?? '',
  );
  late final _content = TextEditingController(
    text: widget.lesson?.content ?? '',
  );
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _objectives.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(_title.text, _objectives.text, _content.text);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = _errorText(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.lesson == null ? 'Add lesson' : 'Edit lesson'),
    content: SizedBox(
      width: 620,
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TeatroEyebrow('MODULE · ${widget.module.title}'),
              ),
              TextFormField(
                controller: _title,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Lesson title'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a lesson title.'
                    : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _objectives,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Learning objectives',
                  hintText: 'Separate objectives with new lines or semicolons.',
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _content,
                minLines: 8,
                maxLines: 16,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  alignLabelWithHint: true,
                  labelText: 'Lesson content',
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter lesson content.'
                    : null,
              ),
              if (_error != null) _FormError(_error!),
              if (_saving) const LinearProgressIndicator(),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context, false),
        child: const Text('Cancel'),
      ),
      DemoPrimaryButton(
        label: _saving ? 'Saving…' : 'Save lesson',
        icon: Icons.save_outlined,
        onPressed: _saving ? null : _save,
      ),
    ],
  );
}

class _ReadOnlyNotice extends StatelessWidget {
  const _ReadOnlyNotice();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: const Color(0xFFF4EEE0),
      borderRadius: BorderRadius.circular(7),
    ),
    child: const Row(
      children: [
        Icon(Icons.info_outline, size: 17, color: TeatroColors.rust),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'Read-only access. Curriculum editing is limited to assigned Curriculum Editors.',
          ),
        ),
      ],
    ),
  );
}

class _FormError extends StatelessWidget {
  const _FormError(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        message,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: TeatroColors.error),
      ),
    ),
  );
}

class _PageState extends StatelessWidget {
  const _PageState({required this.title, required this.message, this.action});
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => TeatroCard(
    child: Column(
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(message, textAlign: TextAlign.center),
        ?action,
      ],
    ),
  );
}

String _errorText(Object error) {
  if (error is StateError) return error.message;
  if (error is PostgrestException) return error.message;
  return 'Please check your connection and permissions, then try again.';
}

CurriculumLesson? _lessonById(
  Iterable<CurriculumLesson> lessons,
  String? lessonId,
) {
  if (lessonId == null) return null;
  for (final lesson in lessons) {
    if (lesson.id == lessonId) return lesson;
  }
  return null;
}
