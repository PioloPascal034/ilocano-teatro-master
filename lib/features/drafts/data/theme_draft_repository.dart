import 'package:supabase_flutter/supabase_flutter.dart';

class ThemeSubmission {
  const ThemeSubmission({
    required this.id,
    required this.version,
    required this.status,
    required this.submittedAt,
    required this.content,
    this.feedback,
  });

  final String id;
  final int version;
  final String status;
  final DateTime submittedAt;
  final Map<String, dynamic> content;
  final String? feedback;
}

class CulturalInspiration {
  const CulturalInspiration({required this.id, required this.title});
  final String id;
  final String title;
}

class ThemeDraft {
  const ThemeDraft({
    required this.id,
    required this.title,
    required this.status,
    required this.updatedAt,
    this.storyId,
    this.inspiration,
    this.centralMessage,
    this.dramaticConflict,
    this.characters,
    this.targetAudience,
    this.stageConcept,
    this.sourceAcknowledgment,
    this.submissions = const [],
  });

  final String id;
  final String title;
  final String status;
  final DateTime updatedAt;
  final String? storyId;
  final String? inspiration;
  final String? centralMessage;
  final String? dramaticConflict;
  final String? characters;
  final String? targetAudience;
  final String? stageConcept;
  final String? sourceAcknowledgment;
  final List<ThemeSubmission> submissions;

  bool get editable => status == 'draft' || status == 'revision_requested';
  bool get complete =>
      title.trim().isNotEmpty &&
      centralMessage?.trim().isNotEmpty == true &&
      dramaticConflict?.trim().isNotEmpty == true &&
      characters?.trim().isNotEmpty == true &&
      targetAudience?.trim().isNotEmpty == true &&
      stageConcept?.trim().isNotEmpty == true;

  factory ThemeDraft.fromMap(Map<String, dynamic> row) => ThemeDraft(
    id: row['draft_id'] as String,
    title: row['title'] as String? ?? 'Untitled Theme',
    status: row['status'] as String? ?? 'draft',
    updatedAt: DateTime.parse(row['updated_at'] as String),
    storyId: row['story_id'] as String?,
    centralMessage: row['central_message'] as String?,
    dramaticConflict: row['dramatic_conflict'] as String?,
    characters: row['characters'] as String?,
    targetAudience: row['target_audience'] as String?,
    stageConcept: row['stage_concept'] as String?,
    sourceAcknowledgment: row['source_acknowledgment'] as String?,
  );
}

abstract interface class ThemeDraftRepository {
  Future<List<CulturalInspiration>> listInspirations();
  Future<List<ThemeDraft>> listDrafts();
  Future<ThemeDraft> getDraft(String id);
  Future<ThemeDraft> saveDraft(ThemeDraft draft);
  Future<String> submitDraft(String id);
}

class SupabaseThemeDraftRepository implements ThemeDraftRepository {
  SupabaseThemeDraftRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String get _studentId {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw StateError('Your session has expired. Sign in again.');
    }
    return id;
  }

  @override
  Future<List<CulturalInspiration>> listInspirations() async {
    final rows = await _client
        .from('cultural_stories')
        .select('story_id, title')
        .eq('is_published', true)
        .order('title');
    return rows
        .map((row) => Map<String, dynamic>.from(row))
        .map(
          (row) => CulturalInspiration(
            id: row['story_id'] as String,
            title: row['title'] as String,
          ),
        )
        .toList();
  }

  @override
  Future<List<ThemeDraft>> listDrafts() async {
    final rows = await _client
        .from('theme_drafts')
        .select(
          'draft_id, story_id, title, central_message, dramatic_conflict, characters, target_audience, stage_concept, source_acknowledgment, status, updated_at',
        )
        .eq('student_id', _studentId)
        .order('updated_at', ascending: false);
    final drafts = rows
        .map((row) => ThemeDraft.fromMap(Map<String, dynamic>.from(row)))
        .toList();
    if (drafts.isEmpty) return drafts;

    final storyIds = drafts
        .map((draft) => draft.storyId)
        .whereType<String>()
        .toSet();
    final stories = storyIds.isEmpty
        ? <Map<String, dynamic>>[]
        : (await _client
                  .from('cultural_stories')
                  .select('story_id, title')
                  .inFilter('story_id', storyIds.toList()))
              .map((row) => Map<String, dynamic>.from(row))
              .toList();
    final titles = {
      for (final story in stories) story['story_id']: story['title'] as String,
    };

    final ids = drafts.map((draft) => draft.id).toList();
    final submissionRows = await _client
        .from('submissions')
        .select(
          'submission_id, draft_id, version_number, submitted_content, status, submitted_at',
        )
        .inFilter('draft_id', ids)
        .order('version_number', ascending: false);
    final submissionMaps = submissionRows
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
    final submissionIds = submissionMaps
        .map((row) => row['submission_id'] as String)
        .toList();
    final feedbackBySubmission = <String, String>{};
    if (submissionIds.isNotEmpty) {
      final reviews = await _client
          .from('reviews')
          .select('submission_id, overall_comment')
          .inFilter('submission_id', submissionIds);
      for (final row in reviews) {
        final review = Map<String, dynamic>.from(row);
        final comment = review['overall_comment'] as String? ?? '';
        if (comment.trim().isNotEmpty) {
          feedbackBySubmission[review['submission_id'] as String] = comment;
        }
      }
    }

    final submissionsByDraft = <String, List<ThemeSubmission>>{};
    for (final row in submissionMaps) {
      submissionsByDraft
          .putIfAbsent(row['draft_id'] as String, () => [])
          .add(
            ThemeSubmission(
              id: row['submission_id'] as String,
              version: (row['version_number'] as num).toInt(),
              status: row['status'] as String,
              submittedAt: DateTime.parse(row['submitted_at'] as String),
              content: Map<String, dynamic>.from(
                row['submitted_content'] as Map,
              ),
              feedback: feedbackBySubmission[row['submission_id'] as String],
            ),
          );
    }
    return drafts
        .map(
          (draft) => ThemeDraft(
            id: draft.id,
            title: draft.title,
            status: draft.status,
            updatedAt: draft.updatedAt,
            storyId: draft.storyId,
            inspiration: titles[draft.storyId] ?? draft.inspiration,
            centralMessage: draft.centralMessage,
            dramaticConflict: draft.dramaticConflict,
            characters: draft.characters,
            targetAudience: draft.targetAudience,
            stageConcept: draft.stageConcept,
            sourceAcknowledgment: draft.sourceAcknowledgment,
            submissions: submissionsByDraft[draft.id] ?? const [],
          ),
        )
        .toList();
  }

  @override
  Future<ThemeDraft> getDraft(String id) async {
    final drafts = await listDrafts();
    return drafts.firstWhere((draft) => draft.id == id);
  }

  @override
  Future<ThemeDraft> saveDraft(ThemeDraft draft) async {
    final studentId = _studentId;
    final values = <String, dynamic>{
      'title': draft.title.trim().isEmpty
          ? 'Untitled Theme'
          : draft.title.trim(),
      'story_id': draft.storyId,
      'central_message': draft.centralMessage,
      'dramatic_conflict': draft.dramaticConflict,
      'characters': draft.characters,
      'target_audience': draft.targetAudience,
      'stage_concept': draft.stageConcept,
      'source_acknowledgment': draft.sourceAcknowledgment,
    };
    if (draft.id.isEmpty) {
      final row = await _client
          .from('theme_drafts')
          .insert({'student_id': studentId, ...values})
          .select(
            'draft_id, story_id, title, central_message, dramatic_conflict, characters, target_audience, stage_concept, source_acknowledgment, status, updated_at',
          )
          .single();
      return ThemeDraft.fromMap(Map<String, dynamic>.from(row));
    }
    final row = await _client
        .from('theme_drafts')
        .update(values)
        .eq('draft_id', draft.id)
        .eq('student_id', studentId)
        .inFilter('status', ['draft', 'revision_requested'])
        .select(
          'draft_id, story_id, title, central_message, dramatic_conflict, characters, target_audience, stage_concept, source_acknowledgment, status, updated_at',
        )
        .maybeSingle();
    if (row == null) {
      throw StateError('This draft is no longer editable or is unavailable.');
    }
    return ThemeDraft.fromMap(Map<String, dynamic>.from(row));
  }

  @override
  Future<String> submitDraft(String id) async {
    final result = await _client.rpc(
      'submit_theme',
      params: {'p_draft_id': id},
    );
    if (result is! String) throw const FormatException('Submission failed.');
    return result;
  }
}
