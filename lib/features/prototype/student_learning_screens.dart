import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../../app/app_theme.dart';
import '../../core/widgets/teatro_widgets.dart';
import 'demo_content.dart';
import 'prototype_widgets.dart';

class StudentLearningScreen extends StatelessWidget {
  const StudentLearningScreen({
    required this.onNavigate,
    required this.onNavigateWithPayload,
    super.key,
  });

  final ValueChanged<AppDestination> onNavigate;
  final void Function(AppDestination, Object?) onNavigateWithPayload;

  @override
  Widget build(BuildContext context) => DemoPageBody(
    eyebrow: 'CURRICULUM',
    title: 'Your learning path',
    description:
        'Five guided modules take you from your first curtain call to a thoughtful theater concept.',
    child: Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth <= 700
                ? 1
                : constraints.maxWidth <= 1050
                ? 2
                : 4;
            return GridView.builder(
              itemCount: demoModules.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: 15,
                crossAxisSpacing: 15,
                mainAxisExtent: columns == 1 ? 280 : 270,
              ),
              itemBuilder: (context, index) => _LearningModuleCard(
                module: demoModules[index],
                sampleProgress: const [75, 25, 0, 0, 0][index],
                onOpen: () => onNavigateWithPayload(
                  AppDestination.moduleOverview,
                  demoModules[index],
                ),
              ),
            );
          },
        ),
      ],
    ),
  );
}

class ModuleOverviewScreen extends StatelessWidget {
  const ModuleOverviewScreen({
    required this.onNavigate,
    this.module,
    super.key,
  });

  final ValueChanged<AppDestination> onNavigate;
  final DemoModule? module;

  @override
  Widget build(BuildContext context) {
    final selectedModule = module ?? demoModules.first;
    return DemoPageBody(
      eyebrow:
          'MODULE ${selectedModule.number.toString().padLeft(2, '0')} · ${selectedModule.lessons.length} LESSONS',
      title: selectedModule.title,
      description: selectedModule.description,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TeatroCard(
            padding: const EdgeInsets.all(22),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 520;
                final progress = Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const TeatroEyebrow('SAMPLE PROGRESS'),
                          const SizedBox(height: 4),
                          Text(
                            '75%',
                            style: Theme.of(context).textTheme.displayMedium,
                          ),
                          const SizedBox(height: 9),
                          const LinearProgressIndicator(
                            value: .75,
                            color: TeatroColors.gold,
                            backgroundColor: TeatroColors.line,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '3 of 4 lessons completed · demo data',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: TeatroColors.muted),
                          ),
                        ],
                      ),
                    ),
                    if (!compact) ...[
                      const SizedBox(width: 20),
                      DemoPrimaryButton(
                        label: 'Continue lesson',
                        icon: Icons.play_arrow_rounded,
                        onPressed: () => onNavigate(AppDestination.lesson),
                      ),
                    ],
                  ],
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    progress,
                    if (compact) ...[
                      const SizedBox(height: 14),
                      DemoPrimaryButton(
                        label: 'Continue lesson',
                        icon: Icons.play_arrow_rounded,
                        onPressed: () => onNavigate(AppDestination.lesson),
                        fullWidth: true,
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          const DemoSectionTitle(title: 'Lessons in this module'),
          ...selectedModule.lessons.asMap().entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _LessonListItem(
                number: entry.key + 1,
                title: entry.value,
                completed: entry.key == 0,
                current: entry.key == 1,
                onTap: () => onNavigate(AppDestination.lesson),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LessonReaderScreen extends StatefulWidget {
  const LessonReaderScreen({required this.onNavigate, super.key});

  final ValueChanged<AppDestination> onNavigate;

  @override
  State<LessonReaderScreen> createState() => _LessonReaderScreenState();
}

class _LessonReaderScreenState extends State<LessonReaderScreen> {
  bool _exampleExpanded = false;

  @override
  Widget build(BuildContext context) {
    final module = demoModules.first;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth <= 760;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DemoDataNotice(),
            if (!compact)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 235, child: _LessonSidebar(module: module)),
                  const SizedBox(width: 35),
                  Expanded(child: _lessonContent(context)),
                ],
              )
            else ...[
              _LessonSidebar(module: module, compact: true),
              const SizedBox(height: 16),
              _lessonContent(context),
            ],
          ],
        );
      },
    );
  }

  Widget _lessonContent(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          TextButton(
            onPressed: () => widget.onNavigate(AppDestination.learning),
            child: const Text('MY LEARNING'),
          ),
          const Icon(Icons.chevron_right, size: 15, color: TeatroColors.muted),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'INTRODUCTION TO THEATER',
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: TeatroColors.muted,
                fontFamily: TeatroTypography.labelFamily,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 13),
      const TeatroEyebrow(
        'LESSON 02 · SAMPLE LESSON',
        color: TeatroColors.rust,
      ),
      const SizedBox(height: 6),
      Text(
        'Elements of Theater',
        style: Theme.of(context).textTheme.displayMedium,
      ),
      const SizedBox(height: 11),
      Text(
        'Every memorable performance is built from a few essential ingredients. Let’s meet the elements that turn a story into a shared experience.',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: TeatroColors.muted,
          height: 1.5,
          fontWeight: FontWeight.w500,
        ),
      ),
      const SizedBox(height: 22),
      TeatroCard(
        padding: const EdgeInsets.all(19),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.auto_awesome_outlined,
              color: TeatroColors.success,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'By the end of this lesson, you can:',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const _Bullet(
                    'Identify key elements in a theatrical performance.',
                  ),
                  const _Bullet(
                    'Explain how those elements work together to tell a story.',
                  ),
                  const _Bullet(
                    'Recognize the elements in a live or recorded play.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 22),
      Text(
        'The building blocks of a performance',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 7),
      Text(
        'Theater is more than actors speaking on a stage. Performers, audience, story, and space join together to make meaning.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.7),
      ),
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
        decoration: const BoxDecoration(
          color: Color(0xFFF0EADC),
          border: Border(left: BorderSide(color: TeatroColors.gold, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '“',
              style: Theme.of(
                context,
              ).textTheme.displayLarge?.copyWith(color: TeatroColors.gold),
            ),
            Text(
              'Theater is a mirror that reflects the world back to us — and invites us to see it differently.',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 8),
            const TeatroEyebrow('A THOUGHT TO CARRY INTO EVERY PERFORMANCE'),
          ],
        ),
      ),
      const SizedBox(height: 20),
      Text(
        'Five essential elements',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 9,
        runSpacing: 9,
        children: const [
          _ElementCard(
            number: '01',
            title: 'Performers',
            description: 'People who embody characters and action.',
          ),
          _ElementCard(
            number: '02',
            title: 'Audience',
            description: 'The community receiving the story.',
          ),
          _ElementCard(
            number: '03',
            title: 'Space',
            description: 'The place where a story comes alive.',
          ),
        ],
      ),
      const SizedBox(height: 18),
      OutlinedButton.icon(
        onPressed: () => setState(() => _exampleExpanded = !_exampleExpanded),
        icon: const Icon(Icons.menu_book_outlined),
        label: const Text('See it in action: A barrio gathering'),
        iconAlignment: IconAlignment.start,
      ),
      if (_exampleExpanded)
        TeatroCard(
          child: Text(
            'Imagine a community story shared in the plaza: performers use voice and gesture, the audience circles close, and a familiar space becomes a world of its own.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(height: 1.7),
          ),
        ),
      const SizedBox(height: 22),
      const Divider(),
      const SizedBox(height: 14),
      Wrap(
        spacing: 9,
        runSpacing: 9,
        alignment: WrapAlignment.spaceBetween,
        children: [
          DemoActionButton(
            label: 'Previous lesson',
            icon: Icons.arrow_back,
            onPressed: () => showDemoMessage(
              context,
              'lesson navigation is a prototype preview',
            ),
          ),
          DemoPrimaryButton(
            label: 'Mark complete & quiz',
            icon: Icons.check,
            onPressed: () {
              showDemoMessage(context, 'lesson completion is not recorded');
              widget.onNavigate(AppDestination.quiz);
            },
          ),
        ],
      ),
    ],
  );
}

class _LessonSidebar extends StatelessWidget {
  const _LessonSidebar({required this.module, this.compact = false});

  final DemoModule module;
  final bool compact;

  @override
  Widget build(BuildContext context) => TeatroCard(
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TeatroEyebrow('MODULE 1 OF 5'),
        const SizedBox(height: 5),
        Text(module.title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 13),
        const LinearProgressIndicator(
          value: .75,
          color: TeatroColors.gold,
          backgroundColor: TeatroColors.line,
        ),
        const SizedBox(height: 5),
        Text(
          'Sample progress · 3 of 4 lessons',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: TeatroColors.muted),
        ),
        if (compact) ...[
          const SizedBox(height: 10),
          Text(
            'Current lesson · Elements of Theater',
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: TeatroColors.rust),
          ),
        ] else ...[
          const SizedBox(height: 15),
          for (var i = 0; i < module.lessons.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Icon(
                    i == 0 ? Icons.check_circle_outline : Icons.circle_outlined,
                    size: 16,
                    color: i == 0 ? TeatroColors.success : TeatroColors.muted,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      module.lessons[i],
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: i == 1 ? TeatroColors.rust : TeatroColors.muted,
                        fontWeight: i == 1 ? FontWeight.w800 : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    ),
  );
}

class _LessonListItem extends StatelessWidget {
  const _LessonListItem({
    required this.number,
    required this.title,
    required this.completed,
    required this.current,
    required this.onTap,
  });

  final int number;
  final String title;
  final bool completed;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: current ? const Color(0xFFFFF9F4) : TeatroColors.paper,
    borderRadius: BorderRadius.circular(8),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        decoration: BoxDecoration(
          border: Border.all(
            color: current ? const Color(0xFFE6CDBD) : TeatroColors.line,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: completed
                  ? const Color(0xFFE8EFE1)
                  : Colors.transparent,
              child: completed
                  ? const Icon(
                      Icons.check,
                      color: TeatroColors.success,
                      size: 16,
                    )
                  : Text(
                      number.toString().padLeft(2, '0'),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text(
              completed ? 'Completed' : 'Lesson preview',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: TeatroColors.muted),
            ),
            const SizedBox(width: 7),
            const Icon(Icons.chevron_right, size: 17),
          ],
        ),
      ),
    ),
  );
}

class _LearningModuleCard extends StatelessWidget {
  const _LearningModuleCard({
    required this.module,
    required this.sampleProgress,
    required this.onOpen,
  });

  final DemoModule module;
  final int sampleProgress;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final tone = _demoTone(module.tone);
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
              padding: const EdgeInsets.symmetric(horizontal: 19),
              color: tone,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TeatroEyebrow(
                    'MODULE ${module.number.toString().padLeft(2, '0')}',
                    color: Colors.white,
                  ),
                  Icon(
                    module.number == 2
                        ? Icons.menu_book_outlined
                        : Icons.theater_comedy_outlined,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(18),
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
                    const SizedBox(height: 6),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${module.lessons.length} lessons',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: TeatroColors.muted),
                        ),
                        Text(
                          '$sampleProgress% complete',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: TeatroColors.muted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    LinearProgressIndicator(
                      value: sampleProgress / 100,
                      minHeight: 5,
                      color: tone,
                      backgroundColor: TeatroColors.line,
                    ),
                    const SizedBox(height: 11),
                    InkWell(
                      onTap: onOpen,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            sampleProgress > 0
                                ? 'Continue learning'
                                : 'Start learning',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
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

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);
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

class _ElementCard extends StatelessWidget {
  const _ElementCard({
    required this.number,
    required this.title,
    required this.description,
  });

  final String number;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 190,
    child: TeatroCard(
      padding: const EdgeInsets.all(13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TeatroEyebrow(number, color: TeatroColors.rust),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 3),
                Text(
                  description,
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

Color _demoTone(String tone) => switch (tone) {
  'rust' => const Color(0xFFB6512D),
  'blue' => const Color(0xFF668B97),
  'moss' => const Color(0xFF74835D),
  'plum' => const Color(0xFF876076),
  _ => const Color(0xFFB58A22),
};
