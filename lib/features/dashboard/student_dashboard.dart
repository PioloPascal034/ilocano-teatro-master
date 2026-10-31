import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../../app/app_theme.dart';
import '../../core/widgets/teatro_widgets.dart';
import '../profile/user_profile.dart';
import 'data/student_dashboard_data_source.dart';
import 'models/student_dashboard_data.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({
    required this.onNavigate,
    this.dataSource,
    this.profile,
    super.key,
  });

  final ValueChanged<AppDestination> onNavigate;
  final StudentDashboardDataSource? dataSource;
  final UserProfile? profile;

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  late StudentDashboardDataSource _dataSource;
  late Future<StudentDashboardProfile> _profileFuture;
  late Future<StudentLearningOverview> _learningFuture;
  late Future<List<StudentRecentDraft>> _draftsFuture;

  @override
  void initState() {
    super.initState();
    _dataSource = widget.dataSource ?? SupabaseStudentDashboardDataSource();
    _loadData();
  }

  @override
  void didUpdateWidget(covariant StudentDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dataSource != widget.dataSource) {
      _dataSource = widget.dataSource ?? SupabaseStudentDashboardDataSource();
      _loadData();
    }
  }

  void _loadData() {
    _profileFuture = _dataSource.loadProfile();
    _learningFuture = _dataSource.loadLearningOverview();
    _draftsFuture = _dataSource.loadRecentDrafts();
  }

  void _reloadProfile() => setState(() {
    _profileFuture = _dataSource.loadProfile();
  });

  void _reloadLearning() => setState(() {
    _learningFuture = _dataSource.loadLearningOverview();
  });

  void _reloadDrafts() => setState(() {
    _draftsFuture = _dataSource.loadRecentDrafts();
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth <= 700;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ProfileWelcome(
            profile: widget.profile,
            fallback: _profileFuture,
            onRetry: _reloadProfile,
          ),
          SizedBox(height: compact ? 17 : 22),
          _ContinueLearningHero(
            future: _learningFuture,
            compact: compact,
            onRetry: _reloadLearning,
            onContinue: () => widget.onNavigate(AppDestination.learning),
          ),
          SizedBox(height: compact ? 17 : 22),
          _LearningMetrics(future: _learningFuture, onRetry: _reloadLearning),
          SizedBox(height: compact ? 32 : 47),
          _SectionHeading(
            eyebrow: 'LEARNING PATH',
            title: 'Explore your modules',
            actionLabel: 'View all modules',
            onAction: () => widget.onNavigate(AppDestination.learning),
          ),
          const SizedBox(height: 15),
          _ModuleGrid(
            future: _learningFuture,
            availableWidth: constraints.maxWidth,
            onRetry: _reloadLearning,
            onOpenLearning: () => widget.onNavigate(AppDestination.learning),
          ),
          SizedBox(height: compact ? 25 : 37),
          _ApplyBanner(
            compact: compact,
            onBuildTheme: () => widget.onNavigate(AppDestination.themeBuilder),
          ),
          SizedBox(height: compact ? 28 : 38),
          _SectionHeading(
            eyebrow: 'YOUR CONCEPTS',
            title: 'Recent drafts',
            actionLabel: 'View all drafts',
            onAction: () => widget.onNavigate(AppDestination.drafts),
          ),
          const SizedBox(height: 14),
          _RecentDrafts(
            future: _draftsFuture,
            onRetry: _reloadDrafts,
            onOpenDrafts: () => widget.onNavigate(AppDestination.drafts),
          ),
        ],
      );
    },
  );
}

class _ProfileWelcome extends StatelessWidget {
  const _ProfileWelcome({
    required this.profile,
    required this.fallback,
    required this.onRetry,
  });

  final UserProfile? profile;
  final Future<StudentDashboardProfile> fallback;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => FutureBuilder<StudentDashboardProfile>(
    future: fallback,
    builder: (context, snapshot) {
      if (profile == null && snapshot.hasError) {
        return _DashboardError(
          message: 'We could not load your student profile.',
          onRetry: onRetry,
        );
      }
      final firstName = profile?.firstName ?? snapshot.data?.firstName ?? '';
      final yearLevel = profile?.yearLevel ?? snapshot.data?.yearLevel;
      final section = profile?.section ?? snapshot.data?.section;
      final greeting = firstName.isEmpty
          ? 'Welcome back.'
          : 'Welcome back, $firstName.';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TeatroEyebrow('STUDENT SPACE'),
          const SizedBox(height: 4),
          Text(greeting, style: Theme.of(context).textTheme.headlineLarge),
          if (yearLevel != null || section != null) ...[
            const SizedBox(height: 3),
            Text(
              [yearLevel, section]
                  .whereType<String>()
                  .where((value) => value.isNotEmpty)
                  .join(' · '),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: TeatroColors.muted),
            ),
          ],
        ],
      );
    },
  );
}

class _ContinueLearningHero extends StatelessWidget {
  const _ContinueLearningHero({
    required this.future,
    required this.compact,
    required this.onRetry,
    required this.onContinue,
  });

  final Future<StudentLearningOverview> future;
  final bool compact;
  final VoidCallback onRetry;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) => FutureBuilder<StudentLearningOverview>(
    future: future,
    builder: (context, snapshot) {
      final overview = snapshot.data;
      final lesson = overview?.resumeLesson;
      final hasError = snapshot.hasError;
      return ConstrainedBox(
        constraints: BoxConstraints(minHeight: compact ? 420 : 335),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Stack(
            children: [
              Positioned.fill(child: ColoredBox(color: TeatroColors.dark)),
              Positioned(
                right: compact ? -60 : 38,
                bottom: -42,
                child: Container(
                  width: compact ? 205 : 170,
                  height: compact ? 205 : 170,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: TeatroColors.gold.withValues(alpha: .14),
                      width: 25,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 25 : 44,
                  vertical: compact ? 31 : 42,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: compact ? double.infinity : 600,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const TeatroEyebrow(
                        'CONTINUE LEARNING',
                        color: Color(0xFFD4D9D1),
                      ),
                      const SizedBox(height: 12),
                      Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(text: 'The world is a stage.\n'),
                            TextSpan(
                              text: 'Find your story.',
                              style: TextStyle(
                                color: const Color(0xFFE5BD57),
                                fontStyle: FontStyle.italic,
                                fontFamily: TeatroTypography.displayFamily,
                              ),
                            ),
                          ],
                        ),
                        style: Theme.of(context).textTheme.displayLarge
                            ?.copyWith(
                              color: Colors.white,
                              fontSize: compact ? 34 : 42,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Continue exploring the foundations of theater and the stories that shape us.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFFD4DCD4),
                        ),
                      ),
                      const SizedBox(height: 19),
                      _HeroButton(
                        label: lesson == null
                            ? 'Explore modules'
                            : 'Continue lesson',
                        onPressed: hasError ? null : onContinue,
                        busy:
                            snapshot.connectionState == ConnectionState.waiting,
                        icon: Icons.play_arrow_rounded,
                      ),
                      if (hasError) ...[
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: onRetry,
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Try again'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ] else if (lesson != null) ...[
                        const SizedBox(height: 19),
                        _ResumeLessonMeta(lesson: lesson),
                      ] else if (snapshot.connectionState ==
                          ConnectionState.done) ...[
                        const SizedBox(height: 15),
                        Text(
                          overview?.publishedLessonCount == 0
                              ? 'No lessons are published yet.'
                              : 'Your next lesson will appear here when you begin learning.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: const Color(0xFFD4DCD4)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _ResumeLessonMeta extends StatelessWidget {
  const _ResumeLessonMeta({required this.lesson});

  final StudentResumeLesson lesson;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 39,
        height: 39,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          lesson.moduleOrder.toString().padLeft(2, '0'),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: const Color(0xFFE5BD57),
            fontFamily: TeatroTypography.labelFamily,
          ),
        ),
      ),
      const SizedBox(width: 11),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lesson.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 2),
            Text(
              'Lesson ${lesson.lessonOrder} of ${lesson.moduleLessonCount} · ${lesson.moduleTitle}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFFD4DCD4)),
            ),
          ],
        ),
      ),
    ],
  );
}

class _LearningMetrics extends StatelessWidget {
  const _LearningMetrics({required this.future, required this.onRetry});

  final Future<StudentLearningOverview> future;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => FutureBuilder<StudentLearningOverview>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _DashboardError(
          message: 'We could not load your learning progress.',
          onRetry: onRetry,
        );
      }
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const _DashboardLoading(height: 112);
      }
      final overview = snapshot.data!;
      return LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          if (width <= 700) {
            final half = (width - 9) / 2;
            return Column(
              children: [
                _ProgressMetric(
                  width: width,
                  overview: overview,
                  primary: true,
                ),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 9,
                  runSpacing: 9,
                  children: [
                    _ProgressMetric(
                      width: half,
                      value: overview.publishedLessonCount == 0
                          ? '—'
                          : '${overview.completedLessonCount}',
                      label: 'Lessons completed',
                      icon: Icons.check_rounded,
                      tone: TeatroColors.rust,
                    ),
                    _ProgressMetric(
                      width: half,
                      value: overview.averageQuizScore == null
                          ? '—'
                          : '${overview.averageQuizScore!.round()}%',
                      label: overview.averageQuizScore == null
                          ? 'No quiz scores yet'
                          : 'Average quiz score',
                      icon: Icons.auto_awesome_outlined,
                      tone: TeatroColors.blue,
                    ),
                    _ProgressMetric(
                      width: width,
                      value: overview.publishedLessonCount == 0
                          ? '—'
                          : '${overview.completedModuleCount}',
                      label: 'Modules completed',
                      icon: Icons.theater_comedy_outlined,
                      tone: TeatroColors.moss,
                    ),
                  ],
                ),
              ],
            );
          }
          if (width <= 1050) {
            final half = (width - 14) / 2;
            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                _ProgressMetric(width: half, overview: overview, primary: true),
                _ProgressMetric(
                  width: half,
                  value: overview.publishedLessonCount == 0
                      ? '—'
                      : '${overview.completedLessonCount}',
                  label: 'Lessons completed',
                  icon: Icons.check_rounded,
                  tone: TeatroColors.rust,
                ),
                _ProgressMetric(
                  width: half,
                  value: overview.averageQuizScore == null
                      ? '—'
                      : '${overview.averageQuizScore!.round()}%',
                  label: overview.averageQuizScore == null
                      ? 'No quiz scores yet'
                      : 'Average quiz score',
                  icon: Icons.auto_awesome_outlined,
                  tone: TeatroColors.blue,
                ),
                _ProgressMetric(
                  width: half,
                  value: overview.publishedLessonCount == 0
                      ? '—'
                      : '${overview.completedModuleCount}',
                  label: 'Modules completed',
                  icon: Icons.theater_comedy_outlined,
                  tone: TeatroColors.moss,
                ),
              ],
            );
          }
          final unit = (width - 14 * 3) / 4.6;
          return Row(
            children: [
              _ProgressMetric(
                width: unit * 1.6,
                overview: overview,
                primary: true,
              ),
              const SizedBox(width: 14),
              _ProgressMetric(
                width: unit,
                value: overview.publishedLessonCount == 0
                    ? '—'
                    : '${overview.completedLessonCount}',
                label: 'Lessons completed',
                icon: Icons.check_rounded,
                tone: TeatroColors.rust,
              ),
              const SizedBox(width: 14),
              _ProgressMetric(
                width: unit,
                value: overview.averageQuizScore == null
                    ? '—'
                    : '${overview.averageQuizScore!.round()}%',
                label: overview.averageQuizScore == null
                    ? 'No quiz scores yet'
                    : 'Average quiz score',
                icon: Icons.auto_awesome_outlined,
                tone: TeatroColors.blue,
              ),
              const SizedBox(width: 14),
              _ProgressMetric(
                width: unit,
                value: overview.publishedLessonCount == 0
                    ? '—'
                    : '${overview.completedModuleCount}',
                label: 'Modules completed',
                icon: Icons.theater_comedy_outlined,
                tone: TeatroColors.moss,
              ),
            ],
          );
        },
      );
    },
  );
}

class _ProgressMetric extends StatelessWidget {
  const _ProgressMetric({
    required this.width,
    this.overview,
    this.primary = false,
    this.value,
    this.label,
    this.icon,
    this.tone,
  });

  final double width;
  final StudentLearningOverview? overview;
  final bool primary;
  final String? value;
  final String? label;
  final IconData? icon;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final data = overview;
    final progressAvailable = data != null && data.publishedLessonCount > 0;
    return SizedBox(
      width: width,
      child: TeatroCard(
        padding: EdgeInsets.all(primary ? 20 : 17),
        child: primary
            ? Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const TeatroEyebrow('OVERALL PROGRESS'),
                        const SizedBox(height: 4),
                        Text(
                          progressAvailable
                              ? '${(data.overallCompletion * 100).round()}%'
                              : '—',
                          style: Theme.of(context).textTheme.displayMedium,
                        ),
                        Text(
                          progressAvailable
                              ? '${data.completedLessonCount} lessons completed of ${data.publishedLessonCount}'
                              : 'No published lessons yet',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: TeatroColors.muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _ProgressRing(
                    value: progressAvailable ? data.overallCompletion : 0,
                    diameter: 66,
                    label: progressAvailable ? 'On your way' : 'Learning path',
                  ),
                ],
              )
            : Row(
                children: [
                  Container(
                    width: 37,
                    height: 37,
                    decoration: BoxDecoration(
                      color: tone?.withValues(alpha: .13),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 19, color: tone),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          value ?? '—',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        Text(
                          label ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: TeatroColors.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({
    required this.value,
    required this.diameter,
    required this.label,
  });

  final double value;
  final double diameter;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox.square(
        dimension: diameter,
        child: CustomPaint(
          painter: _RingPainter(value: value),
          child: Center(
            child: Text(
              '${(value * 100).round()}%',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontSize: 12),
            ),
          ),
        ),
      ),
      const SizedBox(height: 5),
      Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: TeatroColors.muted,
          fontSize: 8,
        ),
      ),
    ],
  );
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.value});

  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 4.0;
    final rect = Offset.zero & size;
    final trackPaint = Paint()
      ..color = TeatroColors.line
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final progressPaint = Paint()
      ..color = TeatroColors.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      rect.deflate(strokeWidth / 2),
      0,
      6.28319,
      false,
      trackPaint,
    );
    if (value > 0) {
      canvas.drawArc(
        rect.deflate(strokeWidth / 2),
        -1.5708,
        6.28319 * value.clamp(0, 1),
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.value != value;
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.eyebrow,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String eyebrow;
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TeatroEyebrow(eyebrow),
            const SizedBox(height: 4),
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
          ],
        ),
      ),
      if (actionLabel != null)
        TextButton.icon(
          onPressed: onAction,
          iconAlignment: IconAlignment.end,
          icon: const Icon(Icons.arrow_forward, size: 16),
          label: Text(actionLabel!),
          style: TextButton.styleFrom(
            foregroundColor: TeatroColors.ink,
            textStyle: Theme.of(context).textTheme.labelMedium,
          ),
        ),
    ],
  );
}

class _ModuleGrid extends StatelessWidget {
  const _ModuleGrid({
    required this.future,
    required this.availableWidth,
    required this.onRetry,
    required this.onOpenLearning,
  });

  final Future<StudentLearningOverview> future;
  final double availableWidth;
  final VoidCallback onRetry;
  final VoidCallback onOpenLearning;

  @override
  Widget build(BuildContext context) => FutureBuilder<StudentLearningOverview>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _DashboardError(
          message: 'We could not load your learning modules.',
          onRetry: onRetry,
        );
      }
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const _DashboardLoading(height: 245);
      }
      final modules = snapshot.data!.modules;
      if (modules.isEmpty) {
        return const _DashboardEmpty(
          title: 'No published modules yet',
          detail:
              'Your learning modules will appear here when they are published.',
        );
      }
      final columns = availableWidth <= 700
          ? 1
          : availableWidth <= 1050
          ? 2
          : 4;
      final itemHeight = availableWidth <= 700 ? 244.0 : 263.0;
      return GridView.builder(
        itemCount: modules.length,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: 15,
          crossAxisSpacing: 15,
          mainAxisExtent: itemHeight,
        ),
        itemBuilder: (context, index) =>
            _ModuleCard(module: modules[index], onOpen: onOpenLearning),
      );
    },
  );
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({required this.module, required this.onOpen});

  final StudentModuleProgress module;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final tone = _moduleTone(module.displayOrder);
    final moduleNumber = module.displayOrder.toString().padLeft(2, '0');
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: DecoratedBox(
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
              padding: const EdgeInsets.symmetric(horizontal: 19),
              color: tone,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TeatroEyebrow('MODULE $moduleNumber', color: Colors.white),
                  Icon(_moduleIcon(module.displayOrder), color: Colors.white),
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
                    if (module.hasLessons) ...[
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        runSpacing: 2,
                        children: [
                          Text(
                            '${module.lessonCount} lessons',
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
                      const SizedBox(height: 7),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: module.completion.clamp(0, 1),
                          minHeight: 5,
                          backgroundColor: const Color(0xFFE8E6DF),
                          color: tone,
                        ),
                      ),
                    ] else ...[
                      Text(
                        'No published lessons yet',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: TeatroColors.muted,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: onOpen,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              module.hasLessons &&
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

class _ApplyBanner extends StatelessWidget {
  const _ApplyBanner({required this.compact, required this.onBuildTheme});

  final bool compact;
  final VoidCallback onBuildTheme;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(compact ? 20 : 24),
    decoration: BoxDecoration(
      color: const Color(0xFFEADFAF),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 18,
      runSpacing: 16,
      children: [
        Container(
          width: 53,
          height: 53,
          decoration: const BoxDecoration(
            color: TeatroColors.gold,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.auto_awesome_outlined, color: Colors.white),
        ),
        SizedBox(
          width: compact ? 220 : 420,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TeatroEyebrow('READY TO CREATE?'),
              const SizedBox(height: 3),
              Text(
                'Apply what you’ve learned.',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: compact ? 21 : 22,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'You can start developing a theme anytime.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: const Color(0xFF68664F)),
              ),
            ],
          ),
        ),
        FilledButton.icon(
          onPressed: onBuildTheme,
          icon: const Icon(Icons.arrow_forward, size: 16),
          label: const Text('Build your theme'),
          style: FilledButton.styleFrom(
            backgroundColor: TeatroColors.dark,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      ],
    ),
  );
}

class _RecentDrafts extends StatelessWidget {
  const _RecentDrafts({
    required this.future,
    required this.onRetry,
    required this.onOpenDrafts,
  });

  final Future<List<StudentRecentDraft>> future;
  final VoidCallback onRetry;
  final VoidCallback onOpenDrafts;

  @override
  Widget build(BuildContext context) => FutureBuilder<List<StudentRecentDraft>>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _DashboardError(
          message: 'We could not load your drafts.',
          onRetry: onRetry,
        );
      }
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const _DashboardLoading(height: 92);
      }
      final drafts = snapshot.data!;
      if (drafts.isEmpty) {
        return _DashboardEmpty(
          title: 'No drafts yet',
          detail: 'Themes you save in the Theme Builder will appear here.',
          actionLabel: 'Start a theme',
          onAction: onOpenDrafts,
        );
      }
      return Column(
        children: drafts
            .map(
              (draft) => Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: _DraftRow(draft: draft, onTap: onOpenDrafts),
              ),
            )
            .toList(),
      );
    },
  );
}

class _DraftRow extends StatelessWidget {
  const _DraftRow({required this.draft, required this.onTap});

  final StudentRecentDraft draft;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: TeatroColors.paper,
    borderRadius: BorderRadius.circular(9),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 15),
        decoration: BoxDecoration(
          border: Border.all(color: TeatroColors.line),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          children: [
            const Icon(Icons.description_outlined, color: TeatroColors.rust),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    draft.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    draft.centralMessage?.trim().isNotEmpty == true
                        ? draft.centralMessage!
                        : 'Updated ${_formatDraftDate(draft.updatedAt)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: TeatroColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            TeatroStatusIndicator(
              label: _formatStatus(draft.status),
              tone: _statusTone(draft.status),
            ),
            const SizedBox(width: 7),
            const Icon(Icons.chevron_right, color: TeatroColors.muted),
          ],
        ),
      ),
    ),
  );
}

class _DashboardLoading extends StatelessWidget {
  const _DashboardLoading({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) => TeatroCard(
    padding: const EdgeInsets.all(20),
    child: SizedBox(
      height: height - 40,
      child: const Center(
        child: SizedBox.square(
          dimension: 23,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    ),
  );
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => TeatroCard(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    child: Row(
      children: [
        const Icon(
          Icons.cloud_off_outlined,
          color: TeatroColors.muted,
          size: 19,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(message, style: Theme.of(context).textTheme.bodySmall),
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

class _DashboardEmpty extends StatelessWidget {
  const _DashboardEmpty({
    required this.title,
    required this.detail,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String detail;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => TeatroCard(
    padding: const EdgeInsets.all(21),
    child: Row(
      children: [
        const Icon(Icons.auto_stories_outlined, color: TeatroColors.muted),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 3),
              Text(
                detail,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: TeatroColors.muted),
              ),
            ],
          ),
        ),
        if (actionLabel != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    ),
  );
}

class _HeroButton extends StatelessWidget {
  const _HeroButton({
    required this.label,
    required this.onPressed,
    required this.busy,
    required this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData icon;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: busy ? null : onPressed,
    icon: busy
        ? const SizedBox.square(
            dimension: 15,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: TeatroColors.dark,
            ),
          )
        : Icon(icon, size: 16),
    label: Text(label),
    style: FilledButton.styleFrom(
      backgroundColor: const Color(0xFFEBBC4B),
      foregroundColor: TeatroColors.dark,
      disabledBackgroundColor: const Color(0xFFEBBC4B),
      minimumSize: const Size(0, 44),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      textStyle: Theme.of(context).textTheme.labelLarge,
    ),
  );
}

Color _moduleTone(int displayOrder) => switch ((displayOrder - 1) % 5) {
  0 => const Color(0xFFB58A22),
  1 => const Color(0xFFB6512D),
  2 => const Color(0xFF668B97),
  3 => const Color(0xFF74835D),
  _ => const Color(0xFF876076),
};

IconData _moduleIcon(int displayOrder) => switch (displayOrder) {
  2 => Icons.menu_book_outlined,
  3 => Icons.edit_note_outlined,
  _ => Icons.theater_comedy_outlined,
};

String _formatStatus(String rawStatus) => rawStatus
    .split('_')
    .map(
      (part) =>
          part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}',
    )
    .join(' ');

TeatroStatusTone _statusTone(String status) => switch (status) {
  'approved' => TeatroStatusTone.approved,
  'revision_requested' => TeatroStatusTone.revision,
  'under_review' || 'submitted' => TeatroStatusTone.pending,
  _ => TeatroStatusTone.neutral,
};

String _formatDraftDate(DateTime date) =>
    '${_monthName(date.month)} ${date.day}';

String _monthName(int month) => const [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
][month - 1];
