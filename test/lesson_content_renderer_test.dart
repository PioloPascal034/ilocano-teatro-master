import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilocano_teatro_master/features/learning/lesson_content_renderer.dart';

void main() {
  testWidgets(
    'Legacy dialogue keeps literal formatting characters and spacing',
    (tester) async {
      const text = 'ANA: *Kablaaw*\n    [Agsubli]\nactor_name_here';
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: LessonContentRenderer(content: text)),
        ),
      );
      expect(
        tester.widget<SelectableText>(find.byType(SelectableText)).data,
        text,
      );
    },
  );

  testWidgets(
    'Structured content styles Markdown and never loads HTML or image URLs',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: LessonContentRenderer(
                content: 'fallback',
                sections: {
                  'introduction': '# Kablaaw\n**ANA:** *Naimbag nga aldaw.*',
                  'discussion':
                      '    [Agsubli]\n> Listen\n- Observe\n<script>alert(1)</script>\n![x](https://example.com/image.png)',
                },
              ),
            ),
          ),
        ),
      );
      final spans = tester
          .widgetList<SelectableText>(find.byType(SelectableText))
          .map((widget) => widget.textSpan)
          .whereType<TextSpan>()
          .toList();
      expect(
        spans.any((span) => span.toPlainText() == '    [Agsubli]'),
        isTrue,
      );
      expect(
        spans.any((span) => span.toPlainText().contains('<script>')),
        isTrue,
      );
      expect(
        spans
            .expand((span) => span.children ?? <InlineSpan>[])
            .whereType<TextSpan>()
            .any((span) => span.style?.fontWeight == FontWeight.bold),
        isTrue,
      );
      expect(find.byType(Image), findsNothing);
      expect(find.text('fallback'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
