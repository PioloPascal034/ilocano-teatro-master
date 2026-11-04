import 'package:flutter/material.dart';
import '../../app/app_theme.dart';
import 'lesson_content_renderer.dart';
import 'models/lesson_reading_time.dart';

class LessonArticleBody extends StatelessWidget {
  const LessonArticleBody({
    super.key,
    required this.title,
    required this.content,
    this.objectives,
    this.sections = const {},
    this.overview = '',
  });

  final String title;
  final String content;
  final String? objectives;
  final Map<String, String> sections;
  final String overview;

  @override
  Widget build(BuildContext context) {
    final goals = (objectives ?? '')
        .split(RegExp(r'\r?\n|\s*;\s*'))
        .map((line) => line.replaceFirst(RegExp(r'^[\s•\-]+'), '').trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final introduction = sections['introduction'] ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.displayMedium),
        const SizedBox(height: 8),
        if (overview.trim().isNotEmpty) ...[
          Text(overview, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 8),
        ],
        Text(
          '${lessonReadingMinutes(content: content, sections: sections, objectives: objectives, overview: overview)} min read',
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: TeatroColors.muted),
        ),
        const SizedBox(height: 16),
        if (introduction.trim().isNotEmpty)
          LessonContentRenderer(
            content: '',
            sections: {'introduction': introduction},
          ),
        if (goals.isNotEmpty) ...[
          Text(
            'Learning objectives',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          for (final goal in goals)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  '),
                  Expanded(child: Text(goal)),
                ],
              ),
            ),
          const SizedBox(height: 12),
        ],
        LessonContentRenderer(
          content: content,
          sections: {...sections, if (sections.isNotEmpty) 'introduction': ''},
        ),
      ],
    );
  }
}
