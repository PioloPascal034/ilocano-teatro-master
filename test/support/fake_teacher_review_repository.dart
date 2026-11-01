import 'package:ilocano_teatro_master/features/teacher/data/teacher_review_repository.dart';
import 'package:ilocano_teatro_master/features/teacher/models/teacher_review_models.dart';

TeacherSubmission teacherSubmissionFixture({
  required String id,
  required String draftId,
  required String studentId,
  required String studentName,
  String title = 'A Test Theme',
  String status = 'submitted',
  int version = 1,
  SavedSubmissionReview? review,
}) => TeacherSubmission(
  id: id,
  draftId: draftId,
  studentId: studentId,
  studentName: studentName,
  status: status,
  version: version,
  submittedAt: DateTime(2026, 10, 30),
  culturalInspiration: 'Verified test story',
  review: review,
  content: {
    'title': title,
    'story_id': 'story-fixture',
    'central_message': 'Communities grow through mutual care.',
    'dramatic_conflict': 'A leader must decide whether to share scarce water.',
    'characters': 'A leader and a neighbor',
    'target_audience': 'Students and families',
    'stage_concept': 'A simple open plaza with fabric props.',
    'source_acknowledgment': 'Inspired by a teacher-verified story.',
  },
  history: [
    SubmissionVersionReview(
      id: id,
      version: version,
      status: status,
      submittedAt: DateTime(2026, 10, 30),
      review: review,
    ),
  ],
);

class FakeTeacherReviewRepository implements TeacherReviewRepository {
  FakeTeacherReviewRepository({
    required this.assignedStudentIds,
    required this.submissions,
    this.failQueue = false,
    this.failReview = false,
    this.failSave = false,
  });

  final Set<String> assignedStudentIds;
  final List<TeacherSubmission> submissions;
  final bool failQueue;
  final bool failReview;
  final bool failSave;
  final List<CompleteReviewRequest> savedReviews = [];

  static const criteria = [
    ReviewCriterion(
      id: 'criterion-theme',
      name: 'Theme Clarity',
      description: 'Clear main message.',
      weight: 25,
      displayOrder: 1,
    ),
    ReviewCriterion(
      id: 'criterion-conflict',
      name: 'Conflict and Dramatic Potential',
      description: 'Conflict creates stage-worthy stakes.',
      weight: 25,
      displayOrder: 2,
    ),
    ReviewCriterion(
      id: 'criterion-culture',
      name: 'Cultural Grounding and Source Acknowledgment',
      description: 'Source is treated respectfully and credited.',
      weight: 20,
      displayOrder: 3,
    ),
    ReviewCriterion(
      id: 'criterion-audience',
      name: 'Audience Relevance',
      description: 'Theme is meaningful to its intended audience.',
      weight: 15,
      displayOrder: 4,
    ),
    ReviewCriterion(
      id: 'criterion-stage',
      name: 'Stage Adaptability',
      description: 'Concept can be staged with available resources.',
      weight: 15,
      displayOrder: 5,
    ),
  ];

  @override
  Future<List<TeacherSubmission>> loadQueue() async {
    if (failQueue) throw StateError('queue unavailable');
    return submissions
        .where(
          (submission) => assignedStudentIds.contains(submission.studentId),
        )
        .toList();
  }

  @override
  Future<SubmissionReviewData> loadReview(String submissionId) async {
    if (failReview) throw StateError('review unavailable');
    final submission = (await loadQueue()).firstWhere(
      (item) => item.id == submissionId,
    );
    return SubmissionReviewData(submission: submission, criteria: criteria);
  }

  @override
  Future<void> completeReview(CompleteReviewRequest request) async {
    if (failSave) throw StateError('save rejected');
    if (request.scores.length != criteria.length ||
        request.scores.values.any((rating) => rating < 1 || rating > 4)) {
      throw StateError('Provide one valid score for each criterion.');
    }
    if (request.comment.trim().isEmpty) {
      throw StateError('Feedback is required.');
    }
    if (savedReviews.any(
      (review) => review.submissionId == request.submissionId,
    )) {
      throw StateError('Already reviewed');
    }
    savedReviews.add(request);
    final index = submissions.indexWhere(
      (submission) => submission.id == request.submissionId,
    );
    final current = submissions[index];
    final review = SavedSubmissionReview(
      id: 'review-${request.submissionId}',
      decision: request.decision,
      comment: request.comment,
      reviewedAt: DateTime(2026, 11, 1),
      scores: request.scores,
    );
    submissions[index] = TeacherSubmission(
      id: current.id,
      draftId: current.draftId,
      studentId: current.studentId,
      studentName: current.studentName,
      status: request.decision,
      version: current.version,
      submittedAt: current.submittedAt,
      content: current.content,
      culturalInspiration: current.culturalInspiration,
      review: review,
      history: [
        for (final version in current.history)
          if (version.id == current.id)
            SubmissionVersionReview(
              id: version.id,
              version: version.version,
              status: request.decision,
              submittedAt: version.submittedAt,
              review: review,
            )
          else
            version,
      ],
    );
  }
}
