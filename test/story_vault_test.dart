import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilocano_teatro_master/app/app_routes.dart';
import 'package:ilocano_teatro_master/app/app_theme.dart';
import 'package:ilocano_teatro_master/features/drafts/theme_draft_screens.dart';
import 'package:ilocano_teatro_master/features/story_vault/data/story_image_validator.dart';
import 'package:ilocano_teatro_master/features/story_vault/models/story_models.dart';
import 'package:ilocano_teatro_master/features/story_vault/story_editor_screens.dart';
import 'package:ilocano_teatro_master/features/story_vault/story_vault_screens.dart';
import 'support/fake_story_vault_repository.dart';
import 'support/fake_theme_draft_repository.dart';

void main() {
  test('recognizes only the known setup story placeholders', () {
    expect(
      isKnownSeedStoryPlaceholder(
        title: 'Biag ni Lam-ang',
        summary:
            'Placeholder entry for the Ilocano epic. Full text and source need review.',
      ),
      isTrue,
    );
    expect(
      isKnownSeedStoryPlaceholder(
        title: 'Biag ni Lam-ang',
        summary: 'A source-reviewed summary with verified citations.',
      ),
      isFalse,
    );
    expect(
      isKnownSeedStoryPlaceholder(
        title: 'Biag ni Lam-ang',
        summary: 'A rewritten summary.',
        sourceTitle: 'Source citation pending verification',
      ),
      isTrue,
    );
  });

  testWidgets('student Story Vault withholds a published seed placeholder', (
    tester,
  ) async {
    final repository = FakeStoryVaultRepository(
      stories: [
        storyFixture(
          title: 'Biag ni Lam-ang',
          summary:
              'Placeholder entry for the Ilocano epic. Full text and source need review.',
          chapters: [chapterFixture()],
        ),
        storyFixture(id: 'verified-story', title: 'Verified source story'),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: StoryVaultScreen(
              key: const ValueKey('student-library'),
              role: AppRole.student,
              repository: repository,
              onOpenStory: (_) {},
              onReadChapter: (_, _, {preview = false}) {},
              onUseStory: (_) {},
              onEditStory: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Verified source story'), findsOneWidget);
    expect(find.text('Biag ni Lam-ang'), findsNothing);
  });

  testWidgets('Story Vault renders authenticated repository image bytes', (
    tester,
  ) async {
    final logo = await rootBundle.load('assets/branding/applogo.png');
    final bytes = logo.buffer.asUint8List();
    const publishedPath = 'story-1/cover/published.png';
    const draftPath = 'story-draft/cover/draft.png';
    final studentRepository = FakeStoryVaultRepository(
      stories: [
        storyFixture(coverStoragePath: publishedPath, coverAltText: 'Cover'),
      ],
    )..images[publishedPath] = bytes;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: StoryVaultScreen(
              role: AppRole.student,
              repository: studentRepository,
              onOpenStory: (_) {},
              onReadChapter: (_, _, {preview = false}) {},
              onUseStory: (_) {},
              onEditStory: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);

    final editorRepository = FakeStoryVaultRepository(
      editor: true,
      stories: [
        storyFixture(
          id: 'story-draft',
          title: 'Unpublished editor preview',
          isPublished: false,
          coverStoragePath: draftPath,
          coverAltText: 'Draft cover',
        ),
      ],
    )..images[draftPath] = bytes;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: StoryVaultScreen(
              key: const ValueKey('editor-library'),
              role: AppRole.teacher,
              repository: editorRepository,
              onOpenStory: (_) {},
              onReadChapter: (_, _, {preview = false}) {},
              onUseStory: (_) {},
              onEditStory: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Unpublished editor preview'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test(
    'completion uses published chapters only and continue selects first unfinished',
    () {
      final chapters = [
        chapterFixture(id: 'c1', order: 1),
        chapterFixture(id: 'c2', order: 2, title: 'Chapter two'),
        chapterFixture(
          id: 'c3',
          order: 3,
          title: 'Private draft',
          published: false,
        ),
      ];
      final story = storyFixture(chapters: chapters, completed: {'c1', 'c3'});
      expect(story.publishedChapters.map((chapter) => chapter.id), [
        'c1',
        'c2',
      ]);
      expect(story.completedCount, 1);
      expect(story.completion, .5);
      expect(story.firstUnfinishedChapter?.id, 'c2');
      expect(story.isComplete, isFalse);
    },
  );

  test('all published chapters marked read gives exact 100 percent', () {
    final story = storyFixture(
      chapters: [
        chapterFixture(id: 'a'),
        chapterFixture(id: 'b', order: 2),
      ],
      completed: {'a', 'b'},
    );
    expect(story.completion, 1);
    expect(story.isComplete, isTrue);
  });

  test('image validator accepts allowed signatures and enforces 5 MiB', () {
    expect(
      StoryImageValidator.validate(Uint8List.fromList([0xff, 0xd8, 0xff])),
      StoryImageFormat.jpeg,
    );
    expect(
      StoryImageValidator.validate(
        Uint8List.fromList([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
      ),
      StoryImageFormat.png,
    );
    expect(
      StoryImageValidator.validate(
        Uint8List.fromList([
          0x52,
          0x49,
          0x46,
          0x46,
          0,
          0,
          0,
          0,
          0x57,
          0x45,
          0x42,
          0x50,
        ]),
      ),
      StoryImageFormat.webp,
    );
    expect(
      () => StoryImageValidator.validate(Uint8List(5 * 1024 * 1024 + 1)),
      throwsFormatException,
    );
    expect(
      () => StoryImageValidator.validate(Uint8List.fromList([1, 2, 3])),
      throwsFormatException,
    );
  });

  test(
    'fake repository persists read marks and reorders stable chapters',
    () async {
      final repository = FakeStoryVaultRepository(
        stories: [
          storyFixture(
            chapters: [
              chapterFixture(id: 'c1'),
              chapterFixture(id: 'c2', title: 'Chapter two', order: 2),
            ],
          ),
        ],
        editor: true,
      );
      await repository.markChapterRead('c1');
      await repository.markChapterRead('c1');
      await repository.reorderChapters('story-1', ['c2', 'c1']);
      final refreshed = await repository.loadStory('story-1');
      expect(refreshed!.completedChapterIds, {'c1'});
      expect(refreshed.chapters.map((chapter) => chapter.id), ['c2', 'c1']);
      expect(refreshed.chapters.map((chapter) => chapter.order), [1, 2]);
    },
  );

  testWidgets(
    'student library shows repository stories and empty state without demo rows',
    (tester) async {
      final repository = FakeStoryVaultRepository(
        stories: [
          storyFixture(chapters: [chapterFixture()]),
          storyFixture(
            id: 'unpublished-story',
            title: 'Unpublished story draft',
            isPublished: false,
            chapters: [
              chapterFixture(id: 'unpublished-chapter', published: false),
            ],
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              child: StoryVaultScreen(
                role: AppRole.student,
                repository: repository,
                onOpenStory: (_) {},
                onReadChapter: (_, _, {preview = false}) {},
                onUseStory: (_) {},
                onEditStory: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Test cultural story'), findsOneWidget);
      expect(find.text('Biag ni Lam-ang'), findsNothing);
      expect(find.text('Unpublished story draft'), findsNothing);
      expect(find.text('50% complete · 1 chapters'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty published library explains there are no stories yet', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: StoryVaultScreen(
              role: AppRole.student,
              repository: FakeStoryVaultRepository(),
              onOpenStory: (_) {},
              onReadChapter: (_, _, {preview = false}) {},
              onUseStory: (_) {},
              onEditStory: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No published stories yet'), findsOneWidget);
    expect(find.text('Biag ni Lam-ang'), findsNothing);
  });

  testWidgets(
    'category chips filter using categories returned by the repository',
    (tester) async {
      final repository = FakeStoryVaultRepository(
        stories: [
          storyFixture(
            id: 'legend',
            title: 'Legend title',
            chapters: [chapterFixture(id: 'l')],
          ),
          storyFixture(
            id: 'epic',
            title: 'Epic title',
            genre: 'Epic',
            chapters: [chapterFixture(id: 'e', storyId: 'epic')],
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              child: StoryVaultScreen(
                role: AppRole.student,
                repository: repository,
                onOpenStory: (_) {},
                onReadChapter: (_, _, {preview = false}) {},
                onUseStory: (_) {},
                onEditStory: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Epic').first);
      await tester.pumpAndSettle();
      expect(find.text('Epic title'), findsOneWidget);
      expect(find.text('Legend title'), findsNothing);
    },
  );

  testWidgets(
    'chapter reader does not complete a chapter merely by opening it',
    (tester) async {
      final repository = FakeStoryVaultRepository(
        stories: [
          storyFixture(
            chapters: [
              chapterFixture(),
              chapterFixture(id: 'chapter-2', title: 'Next chapter', order: 2),
            ],
          ),
        ],
      );
      var nextRoute = AppDestination.storyVault;
      Object? nextArguments;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: StoryChapterReaderScreen(
              storyId: 'story-1',
              chapterId: 'chapter-1',
              preview: false,
              role: AppRole.student,
              repository: repository,
              onNavigate: (destination, arguments) {
                nextRoute = destination;
                nextArguments = arguments;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(repository.readChapterIds, isEmpty);
      expect(find.text('Chapter one'), findsOneWidget);
      await tester.tap(find.text('Mark as Read'));
      await tester.pumpAndSettle();
      expect(repository.readChapterIds, {'chapter-1'});
      expect(find.text('50%'), findsOneWidget);
      await tester.tap(find.text('Next'));
      expect(nextRoute, AppDestination.storyChapter);
      expect((nextArguments as StoryChapterRouteArgs).chapterId, 'chapter-2');
    },
  );

  testWidgets('empty chapter content cannot be marked as read', (tester) async {
    final repository = FakeStoryVaultRepository(
      stories: [
        storyFixture(chapters: [chapterFixture(content: '   ')]),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: StoryChapterReaderScreen(
            storyId: 'story-1',
            chapterId: 'chapter-1',
            preview: false,
            role: AppRole.student,
            repository: repository,
            onNavigate: (_, _) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Chapter text is not available'), findsOneWidget);
    expect(find.text('Mark as Read'), findsNothing);
    expect(repository.readChapterIds, isEmpty);
  });

  testWidgets('Curriculum Editor cannot accidentally publish the seed epic', (
    tester,
  ) async {
    final repository = FakeStoryVaultRepository(
      editor: true,
      stories: [
        storyFixture(
          title: 'Biag ni Lam-ang',
          summary:
              'Placeholder entry for the Ilocano epic. Full text and source need review.',
          isPublished: false,
          chapters: [chapterFixture()],
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: StoryEditorScreen(
              storyId: 'story-1',
              repository: repository,
              onBack: () {},
              onPreview: (_) {},
              onEditChapter: (_, _) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Publish story'));
    await tester.tap(find.text('Publish story'));
    await tester.pumpAndSettle();
    expect(find.textContaining('known seed entry'), findsOneWidget);
    expect(repository.stories.single.isPublished, isFalse);
  });

  testWidgets('ordinary teacher cannot access story editor controls', (
    tester,
  ) async {
    final repository = FakeStoryVaultRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: StoryEditorScreen(
            storyId: null,
            repository: repository,
            onBack: () {},
            onPreview: (_) {},
            onEditChapter: (_, _) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Story management requires Curriculum Editor permission.'),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets(
    'authorized editor can create story draft and enter chapter workflow',
    (tester) async {
      final repository = FakeStoryVaultRepository(editor: true);
      String? editedStoryId;
      String? editedChapterId;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              child: StoryEditorScreen(
                storyId: null,
                repository: repository,
                onBack: () {},
                onPreview: (_) {},
                onEditChapter: (storyId, chapterId) {
                  editedStoryId = storyId;
                  editedChapterId = chapterId;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).first,
        'Source reviewed story',
      );
      await tester.ensureVisible(find.text('Save story'));
      await tester.tap(find.text('Save story'));
      await tester.pumpAndSettle();
      expect(repository.stories.single.isPublished, isFalse);
      await tester.ensureVisible(find.text('Publish story'));
      await tester.tap(find.text('Publish story'));
      await tester.pumpAndSettle();
      expect(
        find.text('Publish at least one chapter before publishing the story.'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Add chapter'));
      await tester.tap(find.text('Add chapter'));
      expect(editedStoryId, repository.stories.single.id);
      expect(editedChapterId, isNull);
    },
  );

  testWidgets(
    'authorized editor saves a draft chapter then publishes it explicitly',
    (tester) async {
      final repository = FakeStoryVaultRepository(
        editor: true,
        stories: [storyFixture(chapters: const [])],
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              child: StoryChapterEditorScreen(
                storyId: 'story-1',
                chapterId: null,
                repository: repository,
                onBack: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Verified opening');
      await tester.enterText(
        find.byType(TextField).at(1),
        'Text from the approved source.',
      );
      await tester.ensureVisible(find.text('Save draft'));
      await tester.tap(find.text('Save draft'));
      await tester.pumpAndSettle();
      expect(repository.stories.single.chapters.single.isPublished, isFalse);
      await tester.ensureVisible(find.text('Publish chapter'));
      await tester.tap(find.text('Publish chapter'));
      await tester.pumpAndSettle();
      expect(repository.stories.single.chapters.single.isPublished, isTrue);
    },
  );

  testWidgets('chapter library adapts to mobile and desktop widths', (
    tester,
  ) async {
    final repository = FakeStoryVaultRepository(
      stories: [
        storyFixture(chapters: [chapterFixture()]),
        storyFixture(
          id: 'story-2',
          title: 'Another story',
          chapters: [chapterFixture(id: 'c2', storyId: 'story-2')],
        ),
      ],
    );
    for (final size in [const Size(360, 800), const Size(1280, 900)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              child: StoryVaultScreen(
                role: AppRole.student,
                repository: repository,
                onOpenStory: (_) {},
                onReadChapter: (_, _, {preview = false}) {},
                onUseStory: (_) {},
                onEditStory: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

  testWidgets('Theme Builder selects and saves the actual story id', (
    tester,
  ) async {
    final drafts = FakeThemeDraftRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: ThemeBuilderScreen(
              repository: drafts,
              initialStoryId: 'story-angalo',
              initialInspiration: 'Angalo',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Angalo'), findsOneWidget);
    await tester.enterText(
      find.byType(TextField).first,
      'Theme based on selected story',
    );
    await tester.ensureVisible(find.text('Save draft'));
    await tester.tap(find.text('Save draft'));
    await tester.pumpAndSettle();
    expect(drafts.drafts.single.storyId, 'story-angalo');
  });

  testWidgets('private story image download failures can be retried', (
    tester,
  ) async {
    const path = 'story-1/cover/cover.png';
    final repository = FakeStoryVaultRepository(failDownloads: true);
    final image = await rootBundle.load('assets/branding/applogo.png');
    repository.images[path] = image.buffer.asUint8List();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StoryPrivateImage(
            repository: repository,
            storagePath: path,
            altText: 'Story cover',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Image unavailable'), findsOneWidget);
    expect(repository.downloadCalls, 1);

    repository.failDownloads = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(repository.downloadCalls, 2);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Image unavailable'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test(
    'fake upload repository surfaces failures and rejects invalid data',
    () async {
      final repository = FakeStoryVaultRepository(
        editor: true,
        failUploads: true,
      );
      await expectLater(
        repository.uploadImage(
          storyId: 'story-1',
          bytes: Uint8List.fromList([0xff, 0xd8, 0xff]),
        ),
        throwsStateError,
      );
      final invalidRepository = FakeStoryVaultRepository(editor: true);
      await expectLater(
        invalidRepository.uploadImage(
          storyId: 'story-1',
          bytes: Uint8List.fromList([1, 2, 3]),
        ),
        throwsFormatException,
      );
    },
  );
}
