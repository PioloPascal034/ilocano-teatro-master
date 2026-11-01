import 'package:ilocano_teatro_master/features/drafts/data/theme_draft_repository.dart';

class FakeThemeDraftRepository implements ThemeDraftRepository {
  final drafts = <ThemeDraft>[];
  final inspirations = <CulturalInspiration>[
    const CulturalInspiration(id: 'story-1', title: 'Test cultural story'),
    const CulturalInspiration(id: 'story-angalo', title: 'Angalo'),
  ];
  var _id = 0;
  var _submissionVersion = 0;

  @override
  Future<List<CulturalInspiration>> listInspirations() async => inspirations;

  @override
  Future<List<ThemeDraft>> listDrafts() async => List.unmodifiable(drafts);

  @override
  Future<ThemeDraft> getDraft(String id) async =>
      drafts.firstWhere((d) => d.id == id);

  @override
  Future<ThemeDraft> saveDraft(ThemeDraft draft) async {
    final saved = ThemeDraft(
      id: draft.id.isEmpty ? 'draft-${++_id}' : draft.id,
      title: draft.title,
      status: draft.status,
      updatedAt: DateTime(2026, 11, 1),
      storyId: draft.storyId,
      inspiration: draft.storyId == null ? null : 'Test cultural story',
      centralMessage: draft.centralMessage,
      dramaticConflict: draft.dramaticConflict,
      characters: draft.characters,
      targetAudience: draft.targetAudience,
      stageConcept: draft.stageConcept,
      sourceAcknowledgment: draft.sourceAcknowledgment,
      submissions: draft.submissions,
    );
    final index = drafts.indexWhere((item) => item.id == saved.id);
    if (index < 0) {
      drafts.add(saved);
    } else {
      drafts[index] = saved;
    }
    return saved;
  }

  @override
  Future<String> submitDraft(String id) async {
    final index = drafts.indexWhere((draft) => draft.id == id);
    if (index < 0) throw StateError('Draft not found');
    final draft = drafts[index];
    _submissionVersion++;
    drafts[index] = ThemeDraft(
      id: draft.id,
      title: draft.title,
      status: 'submitted',
      updatedAt: draft.updatedAt,
      storyId: draft.storyId,
      inspiration: draft.inspiration,
      centralMessage: draft.centralMessage,
      dramaticConflict: draft.dramaticConflict,
      characters: draft.characters,
      targetAudience: draft.targetAudience,
      stageConcept: draft.stageConcept,
      sourceAcknowledgment: draft.sourceAcknowledgment,
      submissions: [
        ...draft.submissions,
        ThemeSubmission(
          id: 'submission-$_submissionVersion',
          version: _submissionVersion,
          status: 'submitted',
          submittedAt: DateTime(2026, 11, 1),
          content: {'title': draft.title},
        ),
      ],
    );
    return 'submission-$_submissionVersion';
  }
}
