import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilocano_teatro_master/app/app_theme.dart';
import 'package:ilocano_teatro_master/features/teacher/teacher_curriculum_screen.dart';
import 'support/fake_curriculum_repository.dart';

Future<void> _pump(
  WidgetTester tester,
  FakeCurriculumRepository repository, {
  Size size = const Size(1100, 1000),
  bool settle = true,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: TeacherCurriculumScreen(repository: repository),
          ),
        ),
      ),
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String label) async {
  final target = find.text(label).first;
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('editor sees unpublished content and management controls', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pump(tester, FakeCurriculumRepository());

    expect(find.text('Create module'), findsOneWidget);
    expect(find.text('Unpublished Module'), findsOneWidget);
    await _tap(tester, 'Manage lessons');
    expect(find.text('Stage and Audience'), findsOneWidget);
    expect(find.text('Add lesson'), findsOneWidget);
    expect(find.byTooltip('Move lesson up'), findsNWidgets(2));
  });

  testWidgets('ordinary teacher sees only published read-only curriculum', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pump(tester, FakeCurriculumRepository(editor: false));

    expect(find.text('Create module'), findsNothing);
    expect(find.text('Unpublished Module'), findsNothing);
    expect(find.textContaining('Read-only access.'), findsOneWidget);
    await _tap(tester, 'Manage lessons');
    expect(find.text('What Is Theater?'), findsOneWidget);
    expect(find.text('Stage and Audience'), findsNothing);
    expect(find.text('Add lesson'), findsNothing);
    expect(find.byTooltip('Move lesson up'), findsNothing);
  });

  testWidgets('module creation saves as unpublished', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = FakeCurriculumRepository();
    await _pump(tester, repository);

    await _tap(tester, 'Create module');
    await tester.enterText(find.byType(TextFormField).at(0), 'New Curriculum');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'Module description',
    );
    await _tap(tester, 'Save module');

    expect(find.text('New Curriculum'), findsOneWidget);
    expect(find.textContaining('UNPUBLISHED'), findsOneWidget);
    expect(
      repository.modules
          .singleWhere((module) => module.id == 'module-3')
          .isPublished,
      isFalse,
    );

    await _tap(tester, 'Edit module');
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'Renamed Curriculum',
    );
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'Updated description',
    );
    await _tap(tester, 'Save module');
    expect(find.text('Renamed Curriculum'), findsOneWidget);
    expect(
      repository.modules
          .singleWhere((module) => module.id == 'module-3')
          .description,
      'Updated description',
    );
  });

  testWidgets('new lesson is saved unpublished', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = FakeCurriculumRepository();
    await _pump(tester, repository);
    await _tap(tester, 'Manage lessons');
    await _tap(tester, 'Add lesson');
    await tester.enterText(find.byType(TextFormField).at(0), 'New lesson');
    await tester.enterText(find.byType(TextFormField).at(1), 'New objective');
    await tester.enterText(
      find.byType(TextFormField).at(2),
      'New lesson body.',
    );
    await _tap(tester, 'Save lesson');

    final lesson = repository.modules.first.lessons.last;
    expect(lesson.title, 'New lesson');
    expect(lesson.content, 'New lesson body.');
    expect(lesson.isPublished, isFalse);
  });

  testWidgets('lesson edit and preview use saved lesson fields', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = FakeCurriculumRepository();
    await _pump(tester, repository);
    await _tap(tester, 'Manage lessons');
    await _tap(tester, 'Edit');
    await tester.enterText(find.byType(TextFormField).at(0), 'Edited lesson');
    await tester.enterText(find.byType(TextFormField).at(1), 'New objective');
    await tester.enterText(
      find.byType(TextFormField).at(2),
      'Persisted lesson body.',
    );
    await _tap(tester, 'Save lesson');

    expect(find.text('Edited lesson'), findsOneWidget);
    await _tap(tester, 'Preview');
    expect(find.textContaining('New objective'), findsOneWidget);
    expect(find.text('Persisted lesson body.'), findsOneWidget);
  });

  testWidgets('publication controls confirm and refresh saved state', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = FakeCurriculumRepository();
    await _pump(tester, repository);
    await _tap(tester, 'Manage lessons');

    await _tap(tester, 'Publish');
    expect(find.text('Publish lesson?'), findsOneWidget);
    await _tap(tester, 'Publish lesson');
    expect(
      repository.modules.first.lessons.every((lesson) => lesson.isPublished),
      isTrue,
    );
    expect(find.text('Curriculum changes saved.'), findsOneWidget);

    await _tap(tester, 'Unpublish');
    await _tap(tester, 'Unpublish module');
    expect(repository.modules.first.isPublished, isFalse);
    expect(repository.modules.first.lessons, hasLength(2));
  });

  testWidgets('reorder sends the complete lesson UUID sequence', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = FakeCurriculumRepository();
    await _pump(tester, repository);
    await _tap(tester, 'Manage lessons');
    await tester.tap(find.byTooltip('Move lesson up').last);
    await tester.pumpAndSettle();

    expect(repository.reorderRequests, ['lesson-2', 'lesson-1']);
    expect(
      repository.modules.first.lessons.map((lesson) => lesson.lessonOrder),
      [1, 2],
    );
  });

  testWidgets('permission and content errors show retry state', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pump(
      tester,
      FakeCurriculumRepository(
        permissionError: StateError('permission check failed'),
      ),
    );
    expect(find.text('Learning content could not be loaded'), findsOneWidget);
    expect(find.text('permission check failed'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await _pump(
      tester,
      FakeCurriculumRepository(
        loadError: StateError('curriculum query failed'),
      ),
    );
    expect(find.text('curriculum query failed'), findsOneWidget);
  });

  testWidgets('empty state and loading state render', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final empty = FakeCurriculumRepository(modules: []);
    await _pump(tester, empty);
    expect(find.text('No published modules yet'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    final gate = Completer<void>();
    await _pump(
      tester,
      FakeCurriculumRepository(loadWait: gate.future),
      settle: false,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Learning content'), findsOneWidget);
  });

  testWidgets('editor content actions fit a mobile-width screen', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pump(tester, FakeCurriculumRepository(), size: const Size(390, 844));
    expect(tester.takeException(), isNull);
    await _tap(tester, 'Manage lessons');
    expect(find.text('Add lesson'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
