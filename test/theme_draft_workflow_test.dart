import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ilocano_teatro_master/features/dashboard/data/student_dashboard_data_source.dart';
import 'package:ilocano_teatro_master/features/drafts/data/theme_draft_repository.dart';
import 'package:ilocano_teatro_master/features/drafts/theme_draft_screens.dart';
import 'support/fake_theme_draft_repository.dart';

void main() {
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
      await repository.submitDraft(updated.id);
      expect(
        (await repository.getDraft(
          updated.id,
        )).submissions.map((item) => item.version),
        [1, 2],
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

  testWidgets(
    'draft list shows a genuine empty state for an empty fake repository',
    (tester) async {
      final repository = FakeThemeDraftRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StudentDraftsScreen(
              repository: repository,
              onOpenBuilder: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No drafts yet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

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
            body: StudentDraftsScreen(
              repository: repository,
              onOpenBuilder: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Version 1 · Revision requested · 30 Oct 2026'),
        findsOneWidget,
      );
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
