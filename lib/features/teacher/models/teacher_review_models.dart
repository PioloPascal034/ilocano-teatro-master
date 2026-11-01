class ReviewCriterion {
  const ReviewCriterion({
    required this.id,
    required this.name,
    required this.description,
    required this.weight,
    required this.displayOrder,
  });

  final String id;
  final String name;
  final String description;
  final double weight;
  final int displayOrder;
}

class SavedSubmissionReview {
  const SavedSubmissionReview({
    required this.id,
    required this.decision,
    required this.comment,
    required this.reviewedAt,
    required this.scores,
  });

  final String id;
  final String decision;
  final String comment;
  final DateTime reviewedAt;
  final Map<String, int> scores;
}

class SubmissionVersionReview {
  const SubmissionVersionReview({
    required this.id,
    required this.version,
    required this.status,
    required this.submittedAt,
    this.review,
  });

  final String id;
  final int version;
  final String status;
  final DateTime submittedAt;
  final SavedSubmissionReview? review;
}

class TeacherSubmission {
  const TeacherSubmission({
    required this.id,
    required this.draftId,
    required this.studentId,
    required this.studentName,
    required this.status,
    required this.version,
    required this.submittedAt,
    required this.content,
    required this.history,
    this.review,
    this.culturalInspiration,
  });

  final String id;
  final String draftId;
  final String studentId;
  final String studentName;
  final String status;
  final int version;
  final DateTime submittedAt;
  final Map<String, dynamic> content;
  final List<SubmissionVersionReview> history;
  final SavedSubmissionReview? review;
  final String? culturalInspiration;

  String get title => content['title'] as String? ?? 'Untitled Theme';

  bool get eligibleForReview =>
      (status == 'submitted' || status == 'under_review') && review == null;
}

class SubmissionReviewData {
  const SubmissionReviewData({
    required this.submission,
    required this.criteria,
  });

  final TeacherSubmission submission;
  final List<ReviewCriterion> criteria;
}

class CompleteReviewRequest {
  const CompleteReviewRequest({
    required this.submissionId,
    required this.decision,
    required this.comment,
    required this.scores,
  });

  final String submissionId;
  final String decision;
  final String comment;
  final Map<String, int> scores;
}
