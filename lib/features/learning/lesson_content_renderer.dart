import 'package:flutter/material.dart';

import '../../app/app_theme.dart';

const lessonSectionLabels = <String, String>{
  'introduction': 'Introduction',
  'discussion': 'Main discussion',
  'examples': 'Examples',
  'activities': 'Activities',
  'summary': 'Summary',
};

class LessonContentRenderer extends StatelessWidget {
  const LessonContentRenderer({
    required this.content,
    this.sections = const <String, String>{},
    this.showSectionHeadings = true,
    super.key,
  });

  final String content;
  final Map<String, String> sections;
  final bool showSectionHeadings;

  @override
  Widget build(BuildContext context) {
    final blocks = <Widget>[];
    if (sections.isEmpty) {
      if (content.trim().isNotEmpty) {
        blocks.add(
          SelectableText(
            content,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(height: 1.7),
          ),
        );
      }
    } else {
      for (final entry in lessonSectionLabels.entries) {
        final text = sections[entry.key] ?? '';
        if (text.trim().isEmpty) continue;
        if (showSectionHeadings) {
          blocks.add(
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: Text(
                entry.value,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          );
        }
        blocks.addAll(_markdownBlocks(context, text));
      }
    }
    if (blocks.isEmpty) {
      return Text(
        'Content not available yet.',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: TeatroColors.muted),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks,
    );
  }

  List<Widget> _markdownBlocks(BuildContext context, String raw) {
    final lines = raw.replaceAll('\r\n', '\n').split('\n');
    final widgets = <Widget>[];
    for (final line in lines) {
      final trimmed = line.trimRight();
      if (trimmed.trim().isEmpty) {
        widgets.add(const SizedBox(height: 8));
        continue;
      }
      final value = trimmed.trimLeft();
      final heading = RegExp(r'^(#{1,3})\s+(.+)$').firstMatch(value);
      if (heading != null) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 4),
            child: Text(
              heading.group(2)!,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        );
        continue;
      }
      final quote = value.startsWith('> ');
      final list = RegExp(r'^([-*]|\d+\.)\s+(.+)$').firstMatch(value);
      final text = quote
          ? value.substring(2)
          : list == null
          ? trimmed
          : list.group(2)!;
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (quote)
                Container(
                  width: 3,
                  height: 24,
                  margin: const EdgeInsets.only(right: 9),
                  color: TeatroColors.rust,
                )
              else if (list != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8, top: 1),
                  child: Text(
                    list.group(1)!.endsWith('.') &&
                            int.tryParse(list.group(1)!.replaceAll('.', '')) !=
                                null
                        ? list.group(1)!
                        : '•',
                  ),
                ),
              Expanded(
                child: SelectableText.rich(
                  TextSpan(
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(height: 1.7),
                    children: _inlineSpans(text),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return widgets;
  }

  List<InlineSpan> _inlineSpans(String text) {
    final pattern = RegExp(r'(\*\*[^*]+\*\*|\*[^*]+\*|_[^_]+_)');
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final match in pattern.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      final token = match.group(0)!;
      final bold = token.startsWith('**');
      final value = token.substring(
        bold ? 2 : 1,
        token.length - (bold ? 2 : 1),
      );
      spans.add(
        TextSpan(
          text: value,
          style: TextStyle(
            fontWeight: bold ? FontWeight.bold : null,
            fontStyle: bold ? null : FontStyle.italic,
          ),
        ),
      );
      cursor = match.end;
    }
    if (cursor < text.length) spans.add(TextSpan(text: text.substring(cursor)));
    return spans;
  }
}
