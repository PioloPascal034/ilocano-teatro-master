import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ilocano_teatro_master/features/dashboard/data/student_dashboard_data_source.dart';
import 'package:ilocano_teatro_master/features/drafts/data/theme_draft_repository.dart';
import 'package:ilocano_teatro_master/features/drafts/theme_draft_screens.dart';
import 'support/fake_theme_draft_repository.dart';

void main() {
  test('draft completeness requires every required concept field', () {
    final incomplete = ThemeDraft(
      id: 'draft',
      title: 'A concept',
      status: 'draft',
      updatedAt: DateTime(2026),
      centralMessage: 'A message',
    );
    expect(incomplete.complete, isFalse);
    expect(incomplete.editable, isTrue);

    final complete = ThemeDraft(
      id: 'draft',
      title: 'A concept',
      status: 'draft',
      updatedAt: DateTime(2026),
      centralMessage: 'A message',
      dramaticConflict: 'A conflict',
      characters: 'A character',
      targetAudience: 'An audience',
      stageConcept: 'A stage concept',
    );
    expect(complete.complete, isTrue);
    expect(
      ThemeDraft(
        id: 'submitted',
        title: complete.title,
        status: 'under_review',
        updatedAt: complete.updatedAt,
      ).editable,
      isFalse,
    );
  });

  test(
    'fake repository creates, edits, restores, and versions drafts',
    () async {
      final repository = FakeThemeDraftRepository();
      final created = await repository.saveDraft(
        ThemeDraft(
          id: '',
          title: 'River Story',
          status: 'draft',
          updatedAt: DateTime(2026),
          centralMessage: 'Community matters.',
          dramaticConflict: 'A flood threatens the village.',
          characters: 'Two siblings',
          targetAudience: 'Families',
          stageConcept: 'A cloth river on stage',
        ),
      );
      expect((await repository.listDrafts()).single.title, 'River Story');

      final restored = await repository.getDraft(created.id);
      expect(restored.centralMessage, 'Community matters.');
      final updated = await repository.saveDraft(
        ThemeDraft(
          id: restored.id,
          title: restored.title,
          status: restored.status,
          updatedAt: restored.updatedAt,
          centralMessage: 'Neighbors act together.',
          dramaticConflict: restored.dramaticConflict,
          characters: restored.characters,
          targetAudience: restored.targetAudience,
          stageConcept: restored.stageConcept,
        ),
      );
      expect(updated.centralMessage, 'Neighbors act together.');

      await repository.submitDraft(updated.id);
      final submitted = await repository.getDraft(updated.id);
      expect(submitted.status, 'submitted');
      expect(submitted.submissions.map((item) => item.version), [1]);
      expect(
        () => repository.submitDraft(updated.id),
        throwsStateError,
        reason: 'A submitted snapshot cannot be submitted or edited again.',
      );

      repository.requestRevision(updated.id, 'Clarify the staging choice.');
      final revision = await repository.getDraft(updated.id);
      final revised = await repository.saveDraft(
        ThemeDraft(
          id: revision.id,
          title: 'Revised river play',
          status: revision.status,
          updatedAt: revision.updatedAt,
          centralMessage: revision.centralMessage,
          dramaticConflict: revision.dramaticConflict,
          characters: revision.characters,
          targetAudience: revision.targetAudience,
          stageConcept: 'A blue cloth becomes the flood and recedes.',
          submissions: revision.submissions,
        ),
      );
      expect(revised.status, 'revision_requested');
      await repository.submitDraft(revised.id);
      final resubmitted = await repository.getDraft(revised.id);
      expect(resubmitted.status, 'submitted');
      expect(resubmitted.submissions.map((item) => item.version), [1, 2]);
      expect(resubmitted.submissions.first.content['title'], 'River Story');
      expect(
        resubmitted.submissions.last.content['title'],
        'Revised river play',
      );
      expect(
        resubmitted.submissions.first.feedback,
        'Clarify the staging choice.',
      );
    },
  );

  testWidgets(
    'editor restores saved text and keeps step data when navigating',
    (tester) async {
      final repository = FakeThemeDraftRepository();
      final draft = await repository.saveDraft(
        ThemeDraft(
          id: '',
          title: 'Saved play',
          status: 'draft',
          updatedAt: DateTime(2026),
          centralMessage: 'An inherited song carries hope.',
          dramaticConflict: 'The choir loses its music.',
          characters: 'A singer and an elder',
          targetAudience: 'Students',
          stageConcept: 'A circle of lanterns',
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ThemeBuilderScreen(
                repository: repository,
                initialDraftId: draft.id,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Saved play'), findsOneWidget);
      await tester.tap(find.text('2. Central message'));
      await tester.pumpAndSettle();
      expect(find.text('An inherited song carries hope.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('mobile theme builder uses a compact six-step navigator', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ThemeBuilderScreen(repository: FakeThemeDraftRepository()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Step 1 of 6'), findsOneWidget);
    expect(find.byType(DropdownButton<int>), findsOneWidget);
    expect(find.text('1. Cultural inspiration'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('incomplete concept cannot submit from the review step', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ThemeBuilderScreen(repository: FakeThemeDraftRepository()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('6. Review and save').last);
    await tester.pumpAndSettle();

    final submit = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Submit for review'),
    );
    expect(submit.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'draft list shows a genuine empty state for an empty fake repository',
    (tester) async {
      final repository = FakeThemeDraftRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StudentDraftsScreen(
                repository: repository,
                onOpenBuilder: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No drafts yet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('incomplete draft is editable but cannot be submitted', (
    tester,
  ) async {
    final repository = FakeThemeDraftRepository();
    await repository.saveDraft(
      ThemeDraft(
        id: '',
        title: 'Incomplete concept',
        status: 'draft',
        updatedAt: DateTime(2026, 11, 1),
        centralMessage: 'A saved central message.',
      ),
    );
    String? openedId;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StudentDraftsScreen(
            repository: repository,
            onOpenBuilder: (id) => openedId = id,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('View details'), findsOneWidget);
    expect(find.text('Continue editing'), findsOneWidget);
    expect(find.text('Submit for review'), findsNothing);
    await tester.tap(find.text('Continue editing'));
    expect(openedId, repository.drafts.single.id);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'student drafts show saved feedback and immutable version history',
    (tester) async {
      final repository = FakeThemeDraftRepository();
      await repository.saveDraft(
        ThemeDraft(
          id: '',
          title: 'Revised theme',
          status: 'revision_requested',
          updatedAt: DateTime(2026, 10, 31),
          centralMessage: 'Communities share responsibility.',
          submissions: [
            ThemeSubmission(
              id: 'submission-v1',
              version: 1,
              status: 'revision_requested',
              submittedAt: DateTime(2026, 10, 30),
              content: const {'title': 'Revised theme'},
              feedback: 'Clarify the main character’s choice.',
            ),
          ],
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StudentDraftsScreen(
                repository: repository,
                onOpenBuilder: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Version 1 · Revision requested · 30 Oct 2026'),
        findsOneWidget,
      );
      await tester.tap(find.text('View teacher feedback'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Clarify the main character’s choice.'),
        findsOneWidget,
      );
    },
  );

  test(
    'dashboard recent drafts use the same fake repository records',
    () async {
      final repository = FakeThemeDraftRepository();
      await repository.saveDraft(
        ThemeDraft(
          id: '',
          title: 'Shared draft',
          status: 'draft',
          updatedAt: DateTime(2026),
          centralMessage: 'A message',
        ),
      );
      final dashboard = SupabaseStudentDashboardDataSource(
        client: SupabaseClient(
          'https://example.supabase.co',
          'public-anon-key',
        ),
        draftRepository: repository,
      );
      final recent = await dashboard.loadRecentDrafts();
      expect(recent.single.title, 'Shared draft');
      expect(recent.single.id, (await repository.listDrafts()).single.id);
    },
  );
}
