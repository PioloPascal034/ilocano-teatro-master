import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilocano_teatro_master/app/app_theme.dart';
import 'package:ilocano_teatro_master/features/learning/lesson_article_body.dart';
import 'package:ilocano_teatro_master/features/teacher/lesson_editor_dialog.dart';
import 'package:ilocano_teatro_master/features/teacher/models/curriculum_models.dart';
import 'package:ilocano_teatro_master/features/learning/models/lesson_reading_time.dart';

const module = CurriculumModule(
  id: 'm',
  title: 'Ilocano theater',
  description: '',
  displayOrder: 1,
  isPublished: false,
  lessons: [],
);

Future<void> openEditor(
  WidgetTester tester, {
  required Future<void> Function(
    String,
    String?,
    String,
    Map<String, String>,
    String,
    int,
  )
  onSave,
  Size size = const Size(390, 844),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              barrierDismissible: false,
              builder: (_) => LessonEditorDialog(
                module: module,
                supportsMetadata: true,
                onSave: onSave,
              ),
            ),
            child: const Text('Open editor'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open editor'));
  await tester.pumpAndSettle();
}

Future<void> edit(WidgetTester tester, String key, String text) async {
  final field = find.byKey(ValueKey('lesson-$key'));
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.enterText(field, text);
  await tester.pump();
}

Future<void> fill(WidgetTester tester) async {
  await edit(tester, 'title', 'Ilocano dialogue');
  await edit(tester, 'introduction', 'Panangrugi.');
  await edit(tester, 'discussion', '**ANA:** Kablaaw.\n    [Agsubli]');
}

void main() {
  test('Reading estimate counts visible text once and includes objectives', () {
    expect(lessonReadingMinutes(content: 'legacy', sections: {}), 1);
    expect(
      lessonReadingMinutes(
        content: List.filled(2000, 'duplicate').join(' '),
        sections: {'discussion': List.filled(180, 'sao').join(' ')},
        objectives: 'One more',
      ),
      2,
    );
  });

  for (final size in [const Size(390, 844), const Size(1200, 900)]) {
    testWidgets('Save status and current-edit preview work at ${size.width}', (
      tester,
    ) async {
      final gate = Completer<void>();
      String? savedOverview;
      await openEditor(
        tester,
        size: size,
        onSave:
            (title, objectives, content, sections, overview, minutes) async {
              savedOverview = overview;
              expect(sections['discussion'], contains('    [Agsubli]'));
              await gate.future;
            },
      );
      await fill(tester);
      await edit(tester, 'overview', 'A short lesson overview');
      expect(find.textContaining('Unsaved ·'), findsOneWidget);
      await tester.tap(find.text('Preview as Student'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(LessonArticleBody),
          matching: find.text('A short lesson overview'),
        ),
        findsOneWidget,
      );
      expect(savedOverview, isNull);
      await tester.tap(find.byTooltip('Close preview'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save lesson'));
      await tester.pump();
      expect(find.textContaining('Saving ·'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(LessonEditorDialog), findsOneWidget);
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.textContaining('Saved ·'), findsOneWidget);
      expect(savedOverview, 'A short lesson overview');
      // Selecting a field/cursor must not mark the saved lesson as dirty.
      final titleField = find.byKey(const ValueKey('lesson-title'));
      await tester.ensureVisible(titleField);
      await tester.tap(titleField);
      await tester.pump();
      expect(find.textContaining('Saved ·'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Cancel and system back both protect dirty edits', (
    tester,
  ) async {
    await openEditor(tester, onSave: (_, _, _, _, _, _) async {});
    await edit(tester, 'title', 'Keep my work');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Discard unsaved changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Keep my work'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.byType(LessonEditorDialog), findsNothing);
  });

  testWidgets('Save failure keeps text and allows retry', (tester) async {
    var calls = 0;
    await openEditor(
      tester,
      onSave: (_, _, _, _, _, _) async {
        if (++calls == 1) throw StateError('Offline');
      },
    );
    await fill(tester);
    await tester.tap(find.text('Save lesson'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Save Failed ·'), findsOneWidget);
    expect(find.text('Offline'), findsOneWidget);
    expect(find.textContaining('[Agsubli]'), findsOneWidget);
    await tester.tap(find.text('Save lesson'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Saved ·'), findsOneWidget);
    expect(calls, 2);
  });

  testWidgets(
    'Templates preserve authored text and update reading time continuously',
    (tester) async {
      await openEditor(tester, onSave: (_, _, _, _, _, _) async {});
      await edit(tester, 'discussion', 'Preserve this original discussion.');
      final template = find.text('Use a lesson template ▾');
      await tester.ensureVisible(template);
      await tester.tap(template);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Playwriting example'));
      await tester.pumpAndSettle();
      expect(find.text('Preserve this original discussion.'), findsOneWidget);
      expect(find.textContaining('**CHARACTER:**'), findsOneWidget);
      await edit(tester, 'discussion', List.filled(400, 'sao').join(' '));
      expect(find.textContaining('3 min read'), findsOneWidget);
      await edit(tester, 'discussion', List.filled(700, 'sao').join(' '));
      expect(find.textContaining('5 min read'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
