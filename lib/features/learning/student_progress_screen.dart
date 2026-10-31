import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../../app/app_theme.dart';
import '../../core/widgets/teatro_widgets.dart';
import '../prototype/prototype_widgets.dart';
import 'data/student_learning_repository.dart';
import 'models/learning_models.dart';

class StudentProgressScreen extends StatefulWidget {
  const StudentProgressScreen({
    required this.repository,
    required this.onNavigate,
    required this.onNavigateWithPayload,
    super.key,
  });

  final StudentLearningRepository repository;
  final ValueChanged<AppDestination> onNavigate;
  final void Function(AppDestination, Object?) onNavigateWithPayload;

  @override
  State<StudentProgressScreen> createState() => _StudentProgressScreenState();
}

class _StudentProgressScreenState extends State<StudentProgressScreen> {
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
        return _ProgressError(onRetry: _retry);
      }
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const _ProgressLoading();
      }
      final catalog = snapshot.data!;
      final continueRoute = catalog.continueRoute;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ProgressHero(catalog: catalog),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 680;
              final half = (constraints.maxWidth - 12) / 2;
              final metrics = [
                _ProgressMetric(
                  width: compact ? half : 205,
                  value: catalog.totalLessons == 0
                      ? '—'
                      : '${catalog.completedLessons}',
                  label: 'Lessons completed',
                  icon: Icons.check_rounded,
                  color: TeatroColors.rust,
                ),
                _ProgressMetric(
                  width: compact ? half : 205,
                  value: catalog.modules.isEmpty
                      ? '—'
                      : '${catalog.modules.where((module) => module.lessons.isNotEmpty && module.completedLessonCount == module.lessons.length).length}',
                  label: 'Modules completed',
                  icon: Icons.theater_comedy_outlined,
                  color: TeatroColors.moss,
                ),
                _ProgressMetric(
                  width: compact ? constraints.maxWidth : 205,
                  value: catalog.modules
                      .expand((module) => module.lessons)
                      .where(
                        (lesson) => lesson.isInProgress && !lesson.isCompleted,
                      )
                      .length
                      .toString(),
                  label: 'Lessons in progress',
                  icon: Icons.pending_actions_outlined,
                  color: TeatroColors.blue,
                ),
              ];
              return Wrap(spacing: 12, runSpacing: 12, children: metrics);
            },
          ),
          const SizedBox(height: 30),
          DemoSectionTitle(
            eyebrow: 'MODULE PROGRESS',
            title: 'Keep your path in view',
            actionLabel: 'My Learning',
            onAction: () => widget.onNavigate(AppDestination.learning),
          ),
          const SizedBox(height: 11),
          if (catalog.modules.isEmpty)
            const _ProgressEmpty(
              title: 'No published modules yet',
              message:
                  'Progress will appear when your teacher publishes lessons.',
            )
          else
            for (final module in catalog.modules)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: _ModuleProgressRow(
                  module: module,
                  onOpen: () => widget.onNavigateWithPayload(
                    AppDestination.moduleOverview,
                    module.id,
                  ),
                ),
              ),
          const SizedBox(height: 18),
          TeatroCard(
            padding: const EdgeInsets.all(17),
            child: Row(
              children: [
                const Icon(Icons.quiz_outlined, color: TeatroColors.muted),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Quiz results will appear here after quiz tracking is implemented.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: TeatroColors.muted),
                  ),
                ),
                if (continueRoute != null)
                  DemoPrimaryButton(
                    label: 'Continue',
                    icon: Icons.arrow_forward,
                    onPressed: () => widget.onNavigateWithPayload(
                      AppDestination.lesson,
                      continueRoute,
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    },
  );
}

class _ProgressHero extends StatelessWidget {
  const _ProgressHero({required this.catalog});
  final StudentLearningCatalog catalog;

  @override
  Widget build(BuildContext context) {
    final hasLessons = catalog.totalLessons > 0;
    return Container(
      padding: const EdgeInsets.all(27),
      decoration: BoxDecoration(
        color: TeatroColors.dark,
        borderRadius: BorderRadius.circular(13),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TeatroEyebrow(
                'YOUR LEARNING JOURNEY',
                color: Color(0xFFD4D9D1),
              ),
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'Small steps make\n'),
                    TextSpan(
                      text: 'great stories.',
                      style: const TextStyle(
                        color: Color(0xFFE5BD57),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
                style: Theme.of(
                  context,
                ).textTheme.displayMedium?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 7),
              Text(
                hasLessons
                    ? 'You have completed ${catalog.completedLessons} of ${catalog.totalLessons} published lessons.'
                    : 'Your progress will appear here when lessons are published.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: const Color(0xFFD4DCD4)),
              ),
            ],
          );
          final completion = Column(
            children: [
              SizedBox.square(
                dimension: 102,
                child: CustomPaint(
                  painter: _CompletionRing(
                    progress: hasLessons ? catalog.overallCompletion : 0,
                  ),
                  child: Center(
                    child: Text(
                      hasLessons
                          ? '${(catalog.overallCompletion * 100).round()}%'
                          : '—',
                      style: Theme.of(
                        context,
                      ).textTheme.headlineLarge?.copyWith(color: Colors.white),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                hasLessons ? 'overall completion' : 'no lessons available',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: const Color(0xFFD4DCD4),
                ),
              ),
            ],
          );
          return compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [copy, const SizedBox(height: 19), completion],
                )
              : Row(
                  children: [
                    Expanded(child: copy),
                    const SizedBox(width: 24),
                    completion,
                  ],
                );
        },
      ),
    );
  }
}

class _CompletionRing extends CustomPainter {
  const _CompletionRing({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const width = 5.0;
    final rect = Offset.zero & size;
    final track = Paint()
      ..color = Colors.white.withValues(alpha: .20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    final value = Paint()
      ..color = const Color(0xFFE5BD57)
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect.deflate(width / 2), 0, 6.28319, false, track);
    if (progress > 0) {
      canvas.drawArc(
        rect.deflate(width / 2),
        -1.5708,
        6.28319 * progress.clamp(0, 1),
        false,
        value,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CompletionRing oldDelegate) =>
      oldDelegate.progress != progress;
}

class _ProgressMetric extends StatelessWidget {
  const _ProgressMetric({
    required this.width,
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  final double width;
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: TeatroCard(
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: Theme.of(context).textTheme.headlineMedium),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: TeatroColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _ModuleProgressRow extends StatelessWidget {
  const _ModuleProgressRow({required this.module, required this.onOpen});
  final LearningModule module;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => TeatroCard(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 600;
        final identity = Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFF2EEE5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.theater_comedy_outlined,
                color: TeatroColors.rust,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TeatroEyebrow(
                    'MODULE ${module.displayOrder.toString().padLeft(2, '0')}',
                  ),
                  Text(
                    module.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ],
        );
        final progress = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (module.lessons.isEmpty)
              Text(
                'No published lessons',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: TeatroColors.muted),
              )
            else ...[
              LinearProgressIndicator(
                value: module.completion,
                color: TeatroColors.rust,
                backgroundColor: TeatroColors.line,
              ),
              const SizedBox(height: 5),
              Text(
                '${module.completedLessonCount} / ${module.lessons.length} lessons completed',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: TeatroColors.muted),
              ),
            ],
          ],
        );
        final action = IconButton(
          onPressed: onOpen,
          tooltip: 'Open module',
          icon: const Icon(Icons.chevron_right),
        );
        return compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  identity,
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: progress),
                      action,
                    ],
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(flex: 3, child: identity),
                  const SizedBox(width: 18),
                  Expanded(flex: 2, child: progress),
                  action,
                ],
              );
      },
    ),
  );
}

class _ProgressLoading extends StatelessWidget {
  const _ProgressLoading();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(40),
      child: CircularProgressIndicator(),
    ),
  );
}

class _ProgressError extends StatelessWidget {
  const _ProgressError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => TeatroCard(
    child: Column(
      children: [
        const Icon(Icons.cloud_off_outlined, color: TeatroColors.muted),
        const SizedBox(height: 8),
        const Text('We could not load your progress.'),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ],
    ),
  );
}

class _ProgressEmpty extends StatelessWidget {
  const _ProgressEmpty({required this.title, required this.message});
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => TeatroCard(
    child: Column(
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 5),
        Text(
          message,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: TeatroColors.muted),
        ),
      ],
    ),
  );
}
