import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilocano_teatro_master/app/app_theme.dart';
import 'package:ilocano_teatro_master/features/teacher/teacher_curriculum_screen.dart';
import 'package:ilocano_teatro_master/features/teacher/models/curriculum_models.dart';
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
  if (label == 'Save lesson' && find.text('Done').evaluate().isNotEmpty) {
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
  }
}

Future<void> _tapLast(WidgetTester tester, String label) async {
  final target = find.text(label).last;
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
    expect(find.text('Delete module'), findsNothing);
    expect(find.text('Delete lesson'), findsNothing);
  });

  testWidgets('editor can cancel then delete an unpublished module', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = FakeCurriculumRepository(
      modules: const [
        CurriculumModule(
          id: 'testing-module',
          title: 'Testing Module',
          description: 'Temporary content.',
          displayOrder: 1,
          isPublished: false,
          lessons: [
            CurriculumLesson(
              id: 'testing-lesson',
              moduleId: 'testing-module',
              title: 'Testing Lesson',
              objectives: null,
              content: 'Temporary lesson.',
              lessonOrder: 1,
              isPublished: false,
            ),
          ],
        ),
      ],
    );
    await _pump(tester, repository);

    await _tap(tester, 'Delete module');
    expect(find.text('Delete module?'), findsOneWidget);
    expect(find.textContaining('Testing Module'), findsWidgets);
    await _tap(tester, 'Cancel');
    expect(repository.modules, hasLength(1));

    await _tap(tester, 'Delete module');
    await _tapLast(tester, 'Delete module');
    expect(repository.modules, isEmpty);
  });

  testWidgets('editor can cancel then delete an unpublished lesson', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = FakeCurriculumRepository(
      modules: const [
        CurriculumModule(
          id: 'testing-module',
          title: 'Testing Module',
          description: 'Temporary content.',
          displayOrder: 1,
          isPublished: false,
          lessons: [
            CurriculumLesson(
              id: 'testing-lesson',
              moduleId: 'testing-module',
              title: 'Testing Lesson',
              objectives: null,
              content: 'Temporary lesson.',
              lessonOrder: 1,
              isPublished: false,
            ),
          ],
        ),
      ],
    );
    await _pump(tester, repository);
    await _tap(tester, 'Manage lessons');

    await _tap(tester, 'Delete lesson');
    expect(find.text('Delete lesson?'), findsOneWidget);
    expect(find.textContaining('Testing Lesson'), findsWidgets);
    await _tap(tester, 'Cancel');
    expect(repository.modules.single.lessons, hasLength(1));

    await _tap(tester, 'Delete lesson');
    await _tapLast(tester, 'Delete lesson');
    expect(repository.modules.single.lessons, isEmpty);
  });

  testWidgets('delete errors are shown without changing curriculum', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = FakeCurriculumRepository(
      mutationError: StateError('Database delete failed.'),
      modules: const [
        CurriculumModule(
          id: 'testing-module',
          title: 'Testing Module',
          description: 'Temporary content.',
          displayOrder: 1,
          isPublished: false,
          lessons: [],
        ),
      ],
    );
    await _pump(tester, repository);

    await _tap(tester, 'Delete module');
    await _tapLast(tester, 'Delete module');
    expect(find.text('Database delete failed.'), findsOneWidget);
    expect(repository.modules, hasLength(1));
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
    await tester.enterText(
      find.byKey(const ValueKey('lesson-introduction')),
      'Lesson introduction.',
    );
    await tester.enterText(
      find.byKey(const ValueKey('lesson-title')),
      'New lesson',
    );
    await tester.enterText(
      find.byKey(const ValueKey('lesson-objectives')),
      'New objective',
    );
    await tester.enterText(
      find.byKey(const ValueKey('lesson-discussion')),
      'New lesson body.',
    );
    await _tap(tester, 'Save lesson');

    final lesson = repository.modules.first.lessons.last;
    expect(lesson.title, 'New lesson');
    expect(lesson.content, 'New lesson body.');
    expect(lesson.isPublished, isFalse);
  });

  testWidgets('saving twice updates the same newly created draft', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = FakeCurriculumRepository();
    await _pump(tester, repository);
    await _tap(tester, 'Manage lessons');
    final originalCount = repository.modules.first.lessons.length;
    await _tap(tester, 'Add lesson');
    await tester.enterText(find.byKey(const ValueKey('lesson-title')), 'Draft');
    await tester.enterText(
      find.byKey(const ValueKey('lesson-introduction')),
      'Introduction',
    );
    await tester.enterText(
      find.byKey(const ValueKey('lesson-discussion')),
      'Discussion',
    );
    await tester.tap(find.text('Save lesson'));
    await tester.pumpAndSettle();
    final id = repository.modules.first.lessons.last.id;
    await tester.enterText(
      find.byKey(const ValueKey('lesson-title')),
      'Revised draft',
    );
    await tester.tap(find.text('Save lesson'));
    await tester.pumpAndSettle();
    expect(repository.modules.first.lessons.length, originalCount + 1);
    expect(repository.modules.first.lessons.last.id, id);
    expect(repository.modules.first.lessons.last.title, 'Revised draft');
    expect(repository.modules.first.lessons.last.isPublished, isFalse);
  });

  testWidgets('structured lesson sections are saved for preview rendering', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = FakeCurriculumRepository();
    await _pump(tester, repository);
    await _tap(tester, 'Manage lessons');
    await _tap(tester, 'Add lesson');
    await tester.enterText(
      find.byKey(const ValueKey('lesson-introduction')),
      'Lesson introduction.',
    );
    await tester.enterText(
      find.byKey(const ValueKey('lesson-title')),
      'Structured lesson',
    );
    await tester.enterText(
      find.byKey(const ValueKey('lesson-discussion')),
      'Dialogue:\n[Aside]',
    );
    await tester.enterText(
      find.byKey(const ValueKey('lesson-introduction')),
      '## Introduction\n*Context*',
    );
    await tester.enterText(
      find.byKey(const ValueKey('lesson-examples')),
      '- Example line',
    );
    await tester.enterText(
      find.byKey(const ValueKey('lesson-summary')),
      '> Remember the rhythm.',
    );
    await _tap(tester, 'Save lesson');

    final lesson = repository.modules.first.lessons.last;
    expect(lesson.sections['introduction'], contains('Context'));
    expect(lesson.sections['examples'], contains('Example line'));
    expect(lesson.sections['summary'], contains('rhythm'));
    final previews = find.text('Preview');
    await tester.ensureVisible(previews.last);
    await tester.tap(previews.last);
    await tester.pumpAndSettle();
    expect(find.text('Introduction'), findsWidgets);
    expect(find.textContaining('Context'), findsOneWidget);
  });

  testWidgets(
    'lesson save reports repository errors without closing the form',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = FakeCurriculumRepository(
        mutationError: StateError('permission denied by repository fixture'),
      );
      await _pump(tester, repository);
      await _tap(tester, 'Manage lessons');
      await _tap(tester, 'Add lesson');
      await tester.enterText(
        find.byKey(const ValueKey('lesson-introduction')),
        'Lesson introduction.',
      );
      await tester.enterText(
        find.byKey(const ValueKey('lesson-title')),
        'A new lesson',
      );
      await tester.enterText(
        find.byKey(const ValueKey('lesson-discussion')),
        'Source-backed text',
      );
      await _tap(tester, 'Save lesson');
      expect(
        find.textContaining('permission denied by repository fixture'),
        findsOneWidget,
      );
      expect(find.text('Add lesson'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'ordinary teacher cannot mutate curriculum through repository',
    () async {
      final repository = FakeCurriculumRepository(editor: false);
      await expectLater(
        repository.createLesson(
          moduleId: 'module-1',
          title: 'Unauthorized lesson',
          objectives: null,
          content: 'This should be denied.',
        ),
        throwsA(isA<StateError>()),
      );
    },
  );

  testWidgets('seed placeholder cannot be published from lesson controls', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = FakeCurriculumRepository(
      modules: [
        CurriculumModule(
          id: 'module-seed',
          title: 'Seed module',
          description: '',
          displayOrder: 1,
          isPublished: true,
          lessons: const [
            CurriculumLesson(
              id: 'lesson-seed',
              moduleId: 'module-seed',
              title: 'Demo lesson',
              objectives: null,
              content: 'DEMO LESSON ONLY: Replace with verified lesson.',
              lessonOrder: 1,
              isPublished: false,
              needsContentReview: true,
            ),
          ],
        ),
      ],
    );
    await _pump(tester, repository);
    await _tap(tester, 'Manage lessons');
    expect(find.textContaining('Placeholder · unpublished'), findsOneWidget);
    await _tap(tester, 'Publish');
    expect(find.textContaining('known demo placeholder'), findsOneWidget);
    expect(repository.modules.single.lessons.single.isPublished, isFalse);
    expect(tester.takeException(), isNull);
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
    await tester.enterText(
      find.byKey(const ValueKey('lesson-title')),
      'Edited lesson',
    );
    await tester.enterText(
      find.byKey(const ValueKey('lesson-objectives')),
      'New objective',
    );
    await tester.enterText(
      find.byKey(const ValueKey('lesson-discussion')),
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

  testWidgets('lesson header wraps on narrow mobile screens', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = FakeCurriculumRepository(
      modules: const [
        CurriculumModule(
          id: 'narrow-module',
          title: 'Ilocano Culture and Storytelling',
          description: 'Cultural lessons',
          displayOrder: 1,
          isPublished: true,
          lessons: [],
          placeholderLessonCount: 5,
          publishedPlaceholderLessonCount: 3,
          unpublishedPlaceholderLessonCount: 2,
        ),
      ],
    );
    await _pump(tester, repository, size: const Size(360, 800));
    await _tap(tester, 'Manage lessons');

    expect(find.text('LESSONS IN THIS MODULE'), findsOneWidget);
    expect(
      find.text(
        '3 published seed placeholders withheld pending editorial review',
      ),
      findsOneWidget,
    );
    expect(
      find.text('2 unpublished seed placeholders remain drafts'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
