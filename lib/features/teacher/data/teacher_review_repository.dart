import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/teacher_review_models.dart';

abstract interface class TeacherReviewRepository {
  Future<List<TeacherSubmission>> loadQueue();
  Future<SubmissionReviewData> loadReview(String submissionId);
  Future<void> completeReview(CompleteReviewRequest request);
}

class SupabaseTeacherReviewRepository implements TeacherReviewRepository {
  SupabaseTeacherReviewRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String get _teacherId {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw StateError('Your session has expired. Sign in again to review.');
    }
    return id;
  }

  Future<List<ReviewCriterion>> _loadCriteria() async {
    final rows = await _client
        .from('rubric_criteria')
        .select(
          'criterion_id, criterion_name, description, weight, display_order',
        )
        .order('display_order');
    return rows.map((row) {
      final criterion = Map<String, dynamic>.from(row);
      return ReviewCriterion(
        id: criterion['criterion_id'] as String,
        name: criterion['criterion_name'] as String,
        description: criterion['description'] as String? ?? '',
        weight: (criterion['weight'] as num).toDouble(),
        displayOrder: (criterion['display_order'] as num).toInt(),
      );
    }).toList();
  }

  @override
  Future<List<TeacherSubmission>> loadQueue() async {
    final assignments = await _client
        .from('teacher_students')
        .select('student_id')
        .eq('teacher_id', _teacherId);
    final studentIds = assignments
        .map((row) => row['student_id'] as String)
        .toSet()
        .toList();
    if (studentIds.isEmpty) return const [];

    final drafts = await _client
        .from('theme_drafts')
        .select('draft_id, student_id, title')
        .inFilter('student_id', studentIds);
    if (drafts.isEmpty) return const [];
    final draftRows = drafts
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
    final draftById = {
      for (final draft in draftRows) draft['draft_id'] as String: draft,
    };
    final assignedStudentIds = draftRows
        .map((draft) => draft['student_id'] as String)
        .toSet()
        .toList();

    final profiles = await _client
        .from('profiles')
        .select('id, full_name')
        .inFilter('id', assignedStudentIds)
        .eq('role', 'student');
    final names = {
      for (final row in profiles)
        row['id'] as String: (row['full_name'] as String? ?? '').trim(),
    };

    final submissionRows = await _client
        .from('submissions')
        .select(
          'submission_id, draft_id, version_number, submitted_content, status, submitted_at',
        )
        .inFilter('draft_id', draftById.keys.toList())
        .order('submitted_at', ascending: false);
    if (submissionRows.isEmpty) return const [];
    final submissions = submissionRows
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
    final submissionIds = submissions
        .map((row) => row['submission_id'] as String)
        .toList();
    final reviews = await _loadReviews(submissionIds);
    final storyNames = await _loadStoryNames(submissions);
    final historiesByDraft = <String, List<SubmissionVersionReview>>{};
    for (final row in submissions) {
      final draftId = row['draft_id'] as String;
      historiesByDraft
          .putIfAbsent(draftId, () => [])
          .add(
            SubmissionVersionReview(
              id: row['submission_id'] as String,
              version: (row['version_number'] as num).toInt(),
              status: row['status'] as String,
              submittedAt: DateTime.parse(row['submitted_at'] as String),
              review: reviews[row['submission_id'] as String],
            ),
          );
    }

    return submissions.map((row) {
      final draftId = row['draft_id'] as String;
      final draft = draftById[draftId]!;
      final studentId = draft['student_id'] as String;
      final content = Map<String, dynamic>.from(
        row['submitted_content'] as Map,
      );
      final storyId = content['story_id'] as String?;
      return TeacherSubmission(
        id: row['submission_id'] as String,
        draftId: draftId,
        studentId: studentId,
        studentName: names[studentId]?.isNotEmpty == true
            ? names[studentId]!
            : 'Name unavailable',
        status: row['status'] as String,
        version: (row['version_number'] as num).toInt(),
        submittedAt: DateTime.parse(row['submitted_at'] as String),
        content: content,
        history: historiesByDraft[draftId] ?? const [],
        review: reviews[row['submission_id'] as String],
        culturalInspiration: storyId == null ? null : storyNames[storyId],
      );
    }).toList();
  }

  Future<Map<String, SavedSubmissionReview>> _loadReviews(
    List<String> submissionIds,
  ) async {
    final rows = await _client
        .from('reviews')
        .select(
          'review_id, submission_id, overall_comment, decision, reviewed_at',
        )
        .inFilter('submission_id', submissionIds);
    if (rows.isEmpty) return const {};
    final reviewRows = rows
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
    final reviewIds = reviewRows
        .map((row) => row['review_id'] as String)
        .toList();
    final scoreRows = await _client
        .from('review_scores')
        .select('review_id, criterion_id, rating')
        .inFilter('review_id', reviewIds);
    final scoresByReview = <String, Map<String, int>>{};
    for (final row in scoreRows) {
      final score = Map<String, dynamic>.from(row);
      scoresByReview.putIfAbsent(
        score['review_id'] as String,
        () => {},
      )[score['criterion_id'] as String] = (score['rating'] as num)
          .toInt();
    }
    return {
      for (final row in reviewRows)
        row['submission_id'] as String: SavedSubmissionReview(
          id: row['review_id'] as String,
          decision: row['decision'] as String,
          comment: row['overall_comment'] as String? ?? '',
          reviewedAt: DateTime.parse(row['reviewed_at'] as String),
          scores: scoresByReview[row['review_id'] as String] ?? const {},
        ),
    };
  }

  Future<Map<String, String>> _loadStoryNames(
    List<Map<String, dynamic>> submissions,
  ) async {
    final ids = submissions
        .map(
          (row) => Map<String, dynamic>.from(
            row['submitted_content'] as Map,
          )['story_id'],
        )
        .whereType<String>()
        .toSet()
        .toList();
    if (ids.isEmpty) return const {};
    final rows = await _client
        .from('cultural_stories')
        .select('story_id, title')
        .inFilter('story_id', ids);
    return {
      for (final row in rows) row['story_id'] as String: row['title'] as String,
    };
  }

  @override
  Future<SubmissionReviewData> loadReview(String submissionId) async {
    final queue = await loadQueue();
    final submission = queue.firstWhere((item) => item.id == submissionId);
    return SubmissionReviewData(
      submission: submission,
      criteria: await _loadCriteria(),
    );
  }

  @override
  Future<void> completeReview(CompleteReviewRequest request) async {
    if (request.comment.trim().isEmpty) {
      throw ArgumentError('Written feedback is required.');
    }
    final result = await _client.rpc(
      'complete_review',
      params: {
        'p_submission_id': request.submissionId,
        'p_decision': request.decision,
        'p_comment': request.comment.trim(),
        'p_scores': request.scores,
      },
    );
    if (result is! String) throw const FormatException('Review did not save.');
  }
}
