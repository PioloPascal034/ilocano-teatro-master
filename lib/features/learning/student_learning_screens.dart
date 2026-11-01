import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../../app/app_theme.dart';
import '../../core/widgets/teatro_widgets.dart';
import '../../core/widgets/teatro_design_widgets.dart';
import 'data/student_learning_repository.dart';
import 'models/learning_models.dart';

class StudentLearningScreen extends StatefulWidget {
  const StudentLearningScreen({
    required this.repository,
    required this.onNavigate,
    required this.onNavigateWithPayload,
    super.key,
  });

  final StudentLearningRepository repository;
  final ValueChanged<AppDestination> onNavigate;
  final void Function(AppDestination, Object?) onNavigateWithPayload;

  @override
  State<StudentLearningScreen> createState() => _StudentLearningScreenState();
}

class _StudentLearningScreenState extends State<StudentLearningScreen> {
  late Future<StudentLearningCatalog> _catalogFuture;

  @override
  void initState() {
    super.initState();
    _catalogFuture = widget.repository.loadCatalog();
  }

  void _retry() =>
      setState(() => _catalogFuture = widget.repository.loadCatalog());

  @override
  Widget build(BuildContext context) => FutureBuilder<StudentLearningCatalog>(
    future: _catalogFuture,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _LearningError(
          message: 'We could not load your learning path.',
          onRetry: _retry,
        );
      }
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const _LearningLoading();
      }
      final catalog = snapshot.data!;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TeatroPageIntro(
            eyebrow: 'CURRICULUM',
            title: 'Your learning path',
            description:
                '${catalog.modules.length} published learning modules are available to you.',
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TeatroActionButton(
              label: 'Knowledge checks',
              icon: Icons.quiz_outlined,
              onPressed: () => widget.onNavigate(AppDestination.quiz),
            ),
          ),
          const SizedBox(height: 11),
          if (catalog.modules.isEmpty)
            const TeatroEmptyState(
              title: 'No published modules yet',
              description:
                  'Your teacher’s published learning modules will appear here.',
              icon: Icons.school_outlined,
            )
          else ...[
            _ContinueLearningCard(
              catalog: catalog,
              onContinue: () => _continue(catalog),
            ),
            const SizedBox(height: 24),
            const TeatroSectionTitle(title: 'Explore your modules'),
            const SizedBox(height: 13),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth <= 700
                    ? 1
                    : constraints.maxWidth <= 1050
                    ? 2
                    : 4;
                return GridView.builder(
                  itemCount: catalog.modules.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 15,
                    crossAxisSpacing: 15,
                    mainAxisExtent: columns == 1 ? 270 : 264,
                  ),
                  itemBuilder: (context, index) => _LearningModuleCard(
                    module: catalog.modules[index],
                    onOpen: () => widget.onNavigateWithPayload(
                      AppDestination.moduleOverview,
                      catalog.modules[index].id,
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      );
    },
  );

  void _continue(StudentLearningCatalog catalog) {
    final route = catalog.continueRoute;
    if (route == null) {
      widget.onNavigate(AppDestination.learning);
      return;
    }
    widget.onNavigateWithPayload(AppDestination.lesson, route);
  }
}

class ModuleOverviewScreen extends StatefulWidget {
  const ModuleOverviewScreen({
    required this.repository,
    required this.moduleId,
    required this.onNavigate,
    required this.onNavigateWithPayload,
    super.key,
  });

  final StudentLearningRepository repository;
  final String? moduleId;
  final ValueChanged<AppDestination> onNavigate;
  final void Function(AppDestination, Object?) onNavigateWithPayload;

  @override
  State<ModuleOverviewScreen> createState() => _ModuleOverviewScreenState();
}

class _ModuleOverviewScreenState extends State<ModuleOverviewScreen> {
  late Future<LearningModule?> _moduleFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ModuleOverviewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.moduleId != widget.moduleId) _load();
  }

  void _load() {
    final moduleId = widget.moduleId;
    _moduleFuture = moduleId == null
        ? Future<LearningModule?>.value(null)
        : widget.repository.loadModule(moduleId);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<LearningModule?>(
    future: _moduleFuture,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _LearningError(
          message: 'We could not load this module.',
          onRetry: () => setState(_load),
        );
      }
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const _LearningLoading();
      }
      final module = snapshot.data;
      if (module == null) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TeatroBackButton(
              label: 'All learning modules',
              onPressed: () => widget.onNavigate(AppDestination.learning),
            ),
            const TeatroEmptyState(
              title: 'Module unavailable',
              description:
                  'This module is not published or is no longer available.',
              icon: Icons.menu_book_outlined,
            ),
          ],
        );
      }
      return _moduleContent(context, module);
    },
  );

  Widget _moduleContent(BuildContext context, LearningModule module) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TeatroBackButton(
        label: 'All learning modules',
        onPressed: () => widget.onNavigate(AppDestination.learning),
      ),
      TeatroPageIntro(
        eyebrow:
            'MODULE ${module.displayOrder.toString().padLeft(2, '0')} · ${module.lessons.length} LESSONS',
        title: module.title,
        description: module.description,
      ),
      TeatroCard(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 560;
            final progress = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TeatroEyebrow('YOUR PROGRESS'),
                const SizedBox(height: 4),
                Text(
                  module.lessons.isEmpty
                      ? '—'
                      : '${(module.completion * 100).round()}%',
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                if (module.lessons.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: module.completion,
                    color: _moduleColor(module.displayOrder),
                    backgroundColor: TeatroColors.line,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${module.completedLessonCount} of ${module.lessons.length} lessons completed',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: TeatroColors.muted),
                  ),
                ] else ...[
                  Text(
                    'No published lessons yet',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: TeatroColors.muted),
                  ),
                ],
              ],
            );
            final route = _nextLesson(module);
            final button = route == null
                ? null
                : DesignPrimaryButton(
                    label: 'Continue lesson',
                    icon: Icons.play_arrow_rounded,
                    onPressed: () => widget.onNavigateWithPayload(
                      AppDestination.lesson,
                      LearningLessonRoute(
                        moduleId: module.id,
                        lessonId: route.id,
                      ),
                    ),
                  );
            return compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      progress,
                      if (button != null) ...[
                        const SizedBox(height: 13),
                        button,
                      ],
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: progress),
                      if (button != null) ...[
                        const SizedBox(width: 20),
                        button,
                      ],
                    ],
                  );
          },
        ),
      ),
      const SizedBox(height: 24),
      const TeatroSectionTitle(title: 'Lessons in this module'),
      if (module.lessons.isEmpty)
        const TeatroEmptyState(
          title: 'No published lessons yet',
          description:
              'Your teacher has not published lessons for this module yet.',
          icon: Icons.menu_book_outlined,
        )
      else
        for (var i = 0; i < module.lessons.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _LessonRow(
              lesson: module.lessons[i],
              number: i + 1,
              onTap: () => widget.onNavigateWithPayload(
                AppDestination.lesson,
                LearningLessonRoute(
                  moduleId: module.id,
                  lessonId: module.lessons[i].id,
                ),
              ),
            ),
          ),
    ],
  );
}

class LessonReaderScreen extends StatefulWidget {
  const LessonReaderScreen({
    required this.repository,
    required this.route,
    required this.onNavigate,
    required this.onNavigateWithPayload,
    super.key,
  });

  final StudentLearningRepository repository;
  final LearningLessonRoute? route;
  final ValueChanged<AppDestination> onNavigate;
  final void Function(AppDestination, Object?) onNavigateWithPayload;

  @override
  State<LessonReaderScreen> createState() => _LessonReaderScreenState();
}

class _LessonReaderScreenState extends State<LessonReaderScreen> {
  late Future<_LessonReaderData?> _lessonFuture;
  bool _savingCompletion = false;
  String? _completionError;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant LessonReaderScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.route?.lessonId != widget.route?.lessonId ||
        oldWidget.route?.moduleId != widget.route?.moduleId) {
      _reload();
    }
  }

  void _reload() {
    _completionError = null;
    final route = widget.route;
    _lessonFuture = route == null
        ? Future<_LessonReaderData?>.value(null)
        : _loadLesson(route);
  }

  Future<_LessonReaderData?> _loadLesson(LearningLessonRoute route) async {
    final module = await widget.repository.loadModule(route.moduleId);
    if (module == null) return null;
    LearningLesson? lesson;
    for (final item in module.lessons) {
      if (item.id == route.lessonId) lesson = item;
    }
    if (lesson == null) return null;
    String? progressError;
    if (!lesson.isCompleted) {
      try {
        await widget.repository.markLessonInProgress(lesson.id);
      } catch (error) {
        progressError = _userMessage(error);
      }
    }
    return _LessonReaderData(
      module: module,
      lesson: lesson,
      progressError: progressError,
    );
  }

  Future<void> _completeLesson(LearningLesson lesson) async {
    setState(() {
      _savingCompletion = true;
      _completionError = null;
    });
    try {
      await widget.repository.markLessonCompleted(lesson.id);
      if (!mounted) return;
      setState(() {
        _savingCompletion = false;
        _reload();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Lesson completion saved.')));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _savingCompletion = false;
        _completionError = _userMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_LessonReaderData?>(
    future: _lessonFuture,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _LearningError(
          message: 'We could not load this lesson.',
          onRetry: () => setState(_reload),
        );
      }
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const _LearningLoading();
      }
      final data = snapshot.data;
      if (data == null) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TeatroBackButton(
              label: 'My Learning',
              onPressed: () => widget.onNavigate(AppDestination.learning),
            ),
            const TeatroEmptyState(
              title: 'Lesson unavailable',
              description:
                  'This lesson is not published or no longer belongs to this module.',
              icon: Icons.menu_book_outlined,
            ),
          ],
        );
      }
      return _lessonContent(context, data);
    },
  );

  Widget _lessonContent(
    BuildContext context,
    _LessonReaderData data,
  ) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth <= 760;
      final sidebar = _LessonSidebar(
        module: data.module,
        selectedLesson: data.lesson.id,
        onSelect: (lesson) => widget.onNavigateWithPayload(
          AppDestination.lesson,
          LearningLessonRoute(moduleId: data.module.id, lessonId: lesson.id),
        ),
      );
      final reader = _LessonArticle(
        data: data,
        savingCompletion: _savingCompletion,
        completionError: _completionError,
        onComplete: () => _completeLesson(data.lesson),
        onPrevious: _adjacentLesson(data, -1),
        onNext: _adjacentLesson(data, 1),
        onNavigate: widget.onNavigate,
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (data.progressError != null)
            _InlineWarning(
              message:
                  'Lesson opened, but progress could not be recorded: ${data.progressError}',
            ),
          if (compact) ...[
            sidebar,
            const SizedBox(height: 14),
            reader,
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 235, child: sidebar),
                const SizedBox(width: 35),
                Expanded(child: reader),
              ],
            ),
        ],
      );
    },
  );

  VoidCallback? _adjacentLesson(_LessonReaderData data, int delta) {
    final index = data.module.lessons.indexWhere(
      (lesson) => lesson.id == data.lesson.id,
    );
    final nextIndex = index + delta;
    if (index < 0 || nextIndex < 0 || nextIndex >= data.module.lessons.length) {
      return null;
    }
    final next = data.module.lessons[nextIndex];
    return () => widget.onNavigateWithPayload(
      AppDestination.lesson,
      LearningLessonRoute(moduleId: data.module.id, lessonId: next.id),
    );
  }
}

class _LessonReaderData {
  const _LessonReaderData({
    required this.module,
    required this.lesson,
    this.progressError,
  });
  final LearningModule module;
  final LearningLesson lesson;
  final String? progressError;
}

class _LessonSidebar extends StatelessWidget {
  const _LessonSidebar({
    required this.module,
    required this.selectedLesson,
    required this.onSelect,
  });

  final LearningModule module;
  final String selectedLesson;
  final ValueChanged<LearningLesson> onSelect;

  @override
  Widget build(BuildContext context) => TeatroCard(
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TeatroEyebrow('MODULE ${module.displayOrder} OF PUBLISHED MODULES'),
        const SizedBox(height: 6),
        Text(module.title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 13),
        if (module.lessons.isNotEmpty)
          LinearProgressIndicator(
            value: module.completion,
            color: TeatroColors.gold,
            backgroundColor: TeatroColors.line,
          ),
        const SizedBox(height: 5),
        Text(
          module.lessons.isEmpty
              ? 'No published lessons'
              : '${module.completedLessonCount} of ${module.lessons.length} lessons completed',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: TeatroColors.muted),
        ),
        const SizedBox(height: 12),
        for (final lesson in module.lessons)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Material(
              color: selectedLesson == lesson.id
                  ? const Color(0xFFF4E9E1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              child: InkWell(
                onTap: () => onSelect(lesson),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        lesson.isCompleted
                            ? Icons.check_circle_outline
                            : Icons.circle_outlined,
                        size: 15,
                        color: lesson.isCompleted
                            ? TeatroColors.success
                            : TeatroColors.muted,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          lesson.title,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: selectedLesson == lesson.id
                                    ? TeatroColors.rust
                                    : TeatroColors.ink,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _LessonArticle extends StatelessWidget {
  const _LessonArticle({
    required this.data,
    required this.savingCompletion,
    required this.completionError,
    required this.onComplete,
    required this.onPrevious,
    required this.onNext,
    required this.onNavigate,
  });

  final _LessonReaderData data;
  final bool savingCompletion;
  final String? completionError;
  final VoidCallback onComplete;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final ValueChanged<AppDestination> onNavigate;

  @override
  Widget build(BuildContext context) {
    final lesson = data.lesson;
    final objectives = _objectives(lesson.objectives);
    final paragraphs = lesson.content
        .split(RegExp(r'\r?\n\s*\r?\n'))
        .map((text) => text.trim())
        .where((text) => text.isNotEmpty)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            TextButton(
              onPressed: () => onNavigate(AppDestination.learning),
              child: const Text('MY LEARNING'),
            ),
            const Icon(
              Icons.chevron_right,
              size: 14,
              color: TeatroColors.muted,
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                data.module.title.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: TeatroColors.muted,
                  fontFamily: TeatroTypography.labelFamily,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TeatroEyebrow(
          'LESSON ${lesson.lessonOrder.toString().padLeft(2, '0')} · PUBLISHED LESSON',
          color: TeatroColors.rust,
        ),
        const SizedBox(height: 6),
        Text(lesson.title, style: Theme.of(context).textTheme.displayMedium),
        const SizedBox(height: 10),
        if (objectives.isNotEmpty) ...[
          TeatroCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Learning objectives',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                for (final objective in objectives) _LessonObjective(objective),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        Text(
          'Lesson content',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        if (paragraphs.isEmpty)
          const TeatroEmptyState(
            title: 'Content not available yet',
            description: 'Your teacher has not added content for this lesson.',
            icon: Icons.menu_book_outlined,
          )
        else
          for (final paragraph in paragraphs)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SelectableText(
                paragraph,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(height: 1.75),
              ),
            ),
        if (completionError != null) ...[
          const SizedBox(height: 8),
          _InlineWarning(message: 'Completion was not saved: $completionError'),
        ],
        const SizedBox(height: 17),
        const Divider(),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 510;
            final previous = TeatroActionButton(
              label: 'Previous lesson',
              icon: Icons.arrow_back,
              onPressed: onPrevious,
            );
            final complete = lesson.isCompleted
                ? const TeatroStatus(status: 'Completed')
                : DesignPrimaryButton(
                    label: savingCompletion ? 'Saving…' : 'Mark as completed',
                    icon: Icons.check,
                    onPressed: savingCompletion ? null : onComplete,
                  );
            final next = onNext == null
                ? null
                : TeatroActionButton(
                    label: 'Next lesson',
                    icon: Icons.arrow_forward,
                    onPressed: onNext,
                  );
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  complete,
                  if (next != null) ...[const SizedBox(height: 8), next],
                  if (onPrevious != null) ...[
                    const SizedBox(height: 8),
                    previous,
                  ],
                ],
              );
            }
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              children: [if (onPrevious != null) previous, complete, ?next],
            );
          },
        ),
      ],
    );
  }

  List<String> _objectives(String? raw) {
    final text = raw?.trim() ?? '';
    if (text.isEmpty) return const [];
    return text
        .split(RegExp(r'\r?\n|\s*;\s*'))
        .map((line) => line.replaceFirst(RegExp(r'^[\s•\-]+'), '').trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }
}

class _LessonObjective extends StatelessWidget {
  const _LessonObjective(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('•  '),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    ),
  );
}

class _LearningModuleCard extends StatelessWidget {
  const _LearningModuleCard({required this.module, required this.onOpen});
  final LearningModule module;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final color = _moduleColor(module.displayOrder);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: TeatroColors.paper,
          border: Border.all(color: TeatroColors.line),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 62,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              color: color,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TeatroEyebrow(
                    'MODULE ${module.displayOrder.toString().padLeft(2, '0')}',
                    color: Colors.white,
                  ),
                  const Icon(
                    Icons.theater_comedy_outlined,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(17),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      module.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(fontSize: 17),
                    ),
                    const SizedBox(height: 7),
                    Expanded(
                      child: Text(
                        module.description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: TeatroColors.muted,
                        ),
                      ),
                    ),
                    if (module.lessons.isEmpty)
                      Text(
                        'No published lessons yet',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: TeatroColors.muted,
                        ),
                      )
                    else ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${module.lessons.length} lessons',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: TeatroColors.muted,
                                  fontSize: 9,
                                ),
                          ),
                          Text(
                            '${(module.completion * 100).round()}% complete',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: TeatroColors.muted,
                                  fontSize: 9,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: module.completion,
                          minHeight: 5,
                          color: color,
                          backgroundColor: TeatroColors.line,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: onOpen,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              module.completedLessonCount > 0
                                  ? 'Continue learning'
                                  : 'Start learning',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Icon(Icons.chevron_right, size: 17),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContinueLearningCard extends StatelessWidget {
  const _ContinueLearningCard({
    required this.catalog,
    required this.onContinue,
  });

  final StudentLearningCatalog catalog;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final route = catalog.continueRoute;
    final lesson = route == null ? null : catalog.lessonById(route.lessonId);
    final module = route == null ? null : catalog.moduleById(route.moduleId);
    return TeatroCard(
      padding: const EdgeInsets.all(19),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TeatroEyebrow('PICK UP WHERE YOU LEFT OFF'),
              const SizedBox(height: 5),
              Text(
                lesson?.title ?? 'Your next lesson',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 3),
              Text(
                module?.title ?? 'Choose a module to begin',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: TeatroColors.muted),
              ),
            ],
          );
          final button = DesignPrimaryButton(
            label: route == null ? 'Browse modules' : 'Continue learning',
            icon: Icons.arrow_forward,
            onPressed: onContinue,
          );
          return compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [content, const SizedBox(height: 14), button],
                )
              : Row(
                  children: [
                    Expanded(child: content),
                    const SizedBox(width: 16),
                    button,
                  ],
                );
        },
      ),
    );
  }
}

class _LessonRow extends StatelessWidget {
  const _LessonRow({
    required this.lesson,
    required this.number,
    required this.onTap,
  });

  final LearningLesson lesson;
  final int number;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TeatroCard(
    padding: EdgeInsets.zero,
    child: ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        radius: 17,
        backgroundColor: lesson.isCompleted
            ? TeatroColors.success.withValues(alpha: .12)
            : const Color(0xFFF2EEE5),
        child: lesson.isCompleted
            ? const Icon(Icons.check, size: 17, color: TeatroColors.success)
            : Text(
                number.toString(),
                style: Theme.of(context).textTheme.labelLarge,
              ),
      ),
      title: Text(lesson.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        lesson.isCompleted
            ? 'Completed'
            : lesson.isInProgress
            ? 'In progress'
            : 'Not started',
      ),
      trailing: const Icon(Icons.chevron_right),
    ),
  );
}

class _LearningLoading extends StatelessWidget {
  const _LearningLoading();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(40),
      child: CircularProgressIndicator(),
    ),
  );
}

class _LearningError extends StatelessWidget {
  const _LearningError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => TeatroCard(
    child: Row(
      children: [
        const Icon(Icons.cloud_off_outlined, color: TeatroColors.muted),
        const SizedBox(width: 10),
        Expanded(
          child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
        ),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Retry'),
        ),
      ],
    ),
  );
}

class _InlineWarning extends StatelessWidget {
  const _InlineWarning({required this.message});
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
      ).textTheme.bodySmall?.copyWith(color: TeatroColors.error),
    ),
  );
}

LearningLesson? _nextLesson(LearningModule module) {
  for (final lesson in module.lessons) {
    if (lesson.isInProgress && !lesson.isCompleted) return lesson;
  }
  for (final lesson in module.lessons) {
    if (!lesson.isCompleted) return lesson;
  }
  return null;
}

Color _moduleColor(int displayOrder) => switch ((displayOrder - 1) % 5) {
  0 => const Color(0xFFB58A22),
  1 => const Color(0xFFB6512D),
  2 => const Color(0xFF668B97),
  3 => const Color(0xFF74835D),
  _ => const Color(0xFF876076),
};

String _userMessage(Object error) {
  if (error is StateError) return error.message;
  return 'Please check your connection and try again.';
}
