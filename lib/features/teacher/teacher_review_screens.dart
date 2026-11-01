import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/app_theme.dart';
import '../../core/widgets/teatro_widgets.dart';
import '../../core/widgets/teatro_design_widgets.dart';
import 'data/teacher_review_repository.dart';
import 'models/teacher_review_models.dart';

class ReviewQueueScreen extends StatefulWidget {
  const ReviewQueueScreen({
    required this.repository,
    required this.onOpenSubmission,
    super.key,
  });

  final TeacherReviewRepository repository;
  final ValueChanged<String> onOpenSubmission;

  @override
  State<ReviewQueueScreen> createState() => _ReviewQueueScreenState();
}

class _ReviewQueueScreenState extends State<ReviewQueueScreen> {
  final _searchController = TextEditingController();
  late Future<List<TeacherSubmission>> _queue;
  String _filter = 'Needs review';
  String _query = '';

  @override
  void initState() {
    super.initState();
    _queue = widget.repository.loadQueue();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _reload() => setState(() => _queue = widget.repository.loadQueue());

  List<TeacherSubmission> _visible(List<TeacherSubmission> submissions) =>
      submissions.where((submission) {
        final statusMatches = switch (_filter) {
          'Needs review' => submission.eligibleForReview,
          'Submitted' => submission.status == 'submitted',
          'Under review' => submission.status == 'under_review',
          'Revision requested' => submission.status == 'revision_requested',
          'Approved' => submission.status == 'approved',
          _ => true,
        };
        final query = _query.trim().toLowerCase();
        final queryMatches =
            query.isEmpty ||
            '${submission.studentName} ${submission.title}'
                .toLowerCase()
                .contains(query);
        return statusMatches && queryMatches;
      }).toList();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TeatroPageIntro(
        eyebrow: 'THEME ASSESSMENTS',
        title: 'Review queue',
        trailing: IconButton(
          tooltip: 'Refresh queue',
          onPressed: _reload,
          icon: const Icon(Icons.refresh),
        ),
      ),
      FutureBuilder<List<TeacherSubmission>>(
        future: _queue,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ReviewMessage(
              message: _reviewError(snapshot.error!),
              icon: Icons.cloud_off_outlined,
              action: TextButton.icon(
                onPressed: _reload,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(36),
                child: CircularProgressIndicator(),
              ),
            );
          }
          final submissions = _visible(snapshot.data!);
          if (snapshot.data!.isEmpty) {
            return const TeatroEmptyState(
              title: 'No assigned submissions',
              description:
                  'Submissions from your assigned students will appear here.',
              icon: Icons.inbox_outlined,
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final search = TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search student or theme',
                    ),
                    onChanged: (value) => setState(() => _query = value),
                  );
                  final filters = DropdownButtonFormField<String>(
                    initialValue: _filter,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Review status',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Needs review',
                        child: Text('Needs review'),
                      ),
                      DropdownMenuItem(
                        value: 'All',
                        child: Text('All statuses'),
                      ),
                      DropdownMenuItem(
                        value: 'Submitted',
                        child: Text('Submitted'),
                      ),
                      DropdownMenuItem(
                        value: 'Under review',
                        child: Text('Under review'),
                      ),
                      DropdownMenuItem(
                        value: 'Revision requested',
                        child: Text('Revision requested'),
                      ),
                      DropdownMenuItem(
                        value: 'Approved',
                        child: Text('Approved'),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _filter = value ?? _filter),
                  );
                  return constraints.maxWidth < 700
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            search,
                            const SizedBox(height: 10),
                            filters,
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(flex: 3, child: search),
                            const SizedBox(width: 12),
                            Expanded(child: filters),
                          ],
                        );
                },
              ),
              const SizedBox(height: 14),
              if (submissions.isEmpty)
                const TeatroEmptyState(
                  title: 'No submissions match',
                  description: 'Adjust your search or status filter.',
                  icon: Icons.search_off_outlined,
                )
              else
                for (final submission in submissions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: _QueueCard(
                      submission: submission,
                      onTap: () => widget.onOpenSubmission(submission.id),
                    ),
                  ),
            ],
          );
        },
      ),
    ],
  );
}

class _QueueCard extends StatelessWidget {
  const _QueueCard({required this.submission, required this.onTap});
  final TeacherSubmission submission;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: TeatroColors.paper,
    borderRadius: BorderRadius.circular(9),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: TeatroCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 580;
            final identity = Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFFE5C4AE),
                  child: Text(
                    _initials(submission.studentName),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: const Color(0xFF804123),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    submission.studentName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
              ],
            );
            final title = Text(
              submission.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            );
            final status = TeatroStatusIndicator(
              label: _statusLabel(submission.status),
              tone: _statusTone(submission.status),
            );
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  identity,
                  const SizedBox(height: 9),
                  title,
                  const SizedBox(height: 8),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Version ${submission.version} · ${_date(submission.submittedAt)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: TeatroColors.muted,
                        ),
                      ),
                      status,
                    ],
                  ),
                ],
              );
            }
            return Row(
              children: [
                SizedBox(width: 205, child: identity),
                const SizedBox(width: 12),
                Expanded(child: title),
                const SizedBox(width: 12),
                Text(
                  'V${submission.version} · ${_date(submission.submittedAt)}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: TeatroColors.muted),
                ),
                const SizedBox(width: 12),
                status,
                const Icon(Icons.chevron_right, color: TeatroColors.muted),
              ],
            );
          },
        ),
      ),
    ),
  );
}

class SubmissionReviewScreen extends StatefulWidget {
  const SubmissionReviewScreen({
    required this.repository,
    required this.submissionId,
    required this.onBack,
    required this.onReviewCompleted,
    super.key,
  });

  final TeacherReviewRepository repository;
  final String submissionId;
  final VoidCallback onBack;
  final VoidCallback onReviewCompleted;

  @override
  State<SubmissionReviewScreen> createState() => _SubmissionReviewScreenState();
}

class _SubmissionReviewScreenState extends State<SubmissionReviewScreen> {
  final _formKey = GlobalKey<FormState>();
  final _feedback = TextEditingController();
  late Future<SubmissionReviewData> _data;
  final Map<String, int?> _ratings = {};
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _data = widget.repository.loadReview(widget.submissionId);
  }

  @override
  void dispose() {
    _feedback.dispose();
    super.dispose();
  }

  double? _weightedScore(List<ReviewCriterion> criteria) {
    if (criteria.isEmpty || criteria.any((c) => _ratings[c.id] == null)) {
      return null;
    }
    final totalWeight = criteria.fold<double>(
      0,
      (sum, item) => sum + item.weight,
    );
    if (totalWeight == 0) return null;
    final weighted = criteria.fold<double>(
      0,
      (total, criterion) =>
          total + (_ratings[criterion.id]! / 4) * criterion.weight,
    );
    return weighted * 100 / totalWeight;
  }

  Future<void> _save(SubmissionReviewData data, String decision) async {
    if (!_formKey.currentState!.validate()) return;
    final ratings = <String, int>{
      for (final criterion in data.criteria)
        criterion.id: ?_ratings[criterion.id],
    };
    if (ratings.length != data.criteria.length) {
      setState(() => _error = 'Score every rubric criterion before saving.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.completeReview(
        CompleteReviewRequest(
          submissionId: widget.submissionId,
          decision: decision,
          comment: _feedback.text.trim(),
          scores: ratings,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            decision == 'approved'
                ? 'Submission approved.'
                : 'Revision requested.',
          ),
        ),
      );
      widget.onReviewCompleted();
    } catch (error) {
      if (mounted) setState(() => _error = _reviewError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<SubmissionReviewData>(
    future: _data,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextButton.icon(
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Review queue'),
            ),
            _ReviewMessage(
              message: _reviewError(snapshot.error!),
              icon: Icons.cloud_off_outlined,
              action: TextButton.icon(
                onPressed: () => setState(
                  () =>
                      _data = widget.repository.loadReview(widget.submissionId),
                ),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ),
          ],
        );
      }
      if (!snapshot.hasData) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(36),
            child: CircularProgressIndicator(),
          ),
        );
      }
      final data = snapshot.data!;
      final submission = data.submission;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextButton.icon(
            onPressed: widget.onBack,
            icon: const Icon(Icons.arrow_back),
            label: const Text('Review queue'),
            style: TextButton.styleFrom(alignment: Alignment.centerLeft),
          ),
          TeatroPageIntro(
            eyebrow:
                '${submission.studentName.toUpperCase()} · VERSION ${submission.version}',
            title: submission.title,
            description: 'Submitted ${_date(submission.submittedAt)}',
            trailing: TeatroStatusIndicator(
              label: _statusLabel(submission.status),
              tone: _statusTone(submission.status),
            ),
          ),
          _snapshotCard(submission),
          const SizedBox(height: 14),
          _historyCard(submission.history, submission.id),
          const SizedBox(height: 14),
          if (submission.review != null)
            _savedReviewCard(submission.review!, data.criteria)
          else if (submission.eligibleForReview)
            _assessmentForm(data)
          else
            const TeatroEmptyState(
              title: 'This submission is not reviewable',
              description:
                  'Only submissions in an eligible database status can be reviewed.',
              icon: Icons.lock_outline,
            ),
        ],
      );
    },
  );

  Widget _snapshotCard(TeacherSubmission submission) => TeatroCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Submitted theme snapshot',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        _SnapshotField(
          label: 'Cultural inspiration',
          value:
              submission.culturalInspiration ??
              (submission.content['story_id'] == null
                  ? 'Original student story'
                  : 'Referenced cultural story is unavailable'),
        ),
        _SnapshotField(
          label: 'Central message',
          value: _contentValue(submission.content, 'central_message'),
        ),
        _SnapshotField(
          label: 'Dramatic conflict',
          value: _contentValue(submission.content, 'dramatic_conflict'),
        ),
        _SnapshotField(
          label: 'Characters',
          value: _contentValue(submission.content, 'characters'),
        ),
        _SnapshotField(
          label: 'Target audience',
          value: _contentValue(submission.content, 'target_audience'),
        ),
        _SnapshotField(
          label: 'Stage presentation',
          value: _contentValue(submission.content, 'stage_concept'),
        ),
        _SnapshotField(
          label: 'Source acknowledgment',
          value: _contentValue(submission.content, 'source_acknowledgment'),
        ),
      ],
    ),
  );

  Widget _historyCard(
    List<SubmissionVersionReview> history,
    String activeId,
  ) => TeatroCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Submission history',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 7),
        for (final version in history)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Version ${version.version}${version.id == activeId ? ' · Current' : ''} · ${_statusLabel(version.status)} · ${_date(version.submittedAt)}',
                ),
                if (version.review case final review?) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 10),
                    child: Text(
                      '${review.decision == 'approved' ? 'Approved' : 'Revision requested'} · ${review.comment}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: TeatroColors.muted,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    ),
  );

  Widget _savedReviewCard(
    SavedSubmissionReview review,
    List<ReviewCriterion> criteria,
  ) => TeatroCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Saved review · ${review.decision == 'approved' ? 'Approved' : 'Revision requested'}',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        Text('Reviewed ${_date(review.reviewedAt)}'),
        const SizedBox(height: 10),
        if (review.comment.trim().isNotEmpty) Text(review.comment),
        for (final criterion in criteria)
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Text(
              '${criterion.name} (${criterion.weight.toStringAsFixed(0)}%): ${review.scores[criterion.id] ?? 'No saved score'} / 4',
            ),
          ),
      ],
    ),
  );

  Widget _assessmentForm(SubmissionReviewData data) {
    if (data.criteria.isEmpty) {
      return const TeatroEmptyState(
        title: 'Rubric unavailable',
        description: 'The database has no active rubric criteria to assess.',
        icon: Icons.rule_outlined,
      );
    }
    final weighted = _weightedScore(data.criteria);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TeatroCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Theme assessment rubric',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                for (final criterion in data.criteria)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                criterion.name,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            Text(
                              '${criterion.weight.toStringAsFixed(0)}%',
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(color: TeatroColors.rust),
                            ),
                          ],
                        ),
                        if (criterion.description.trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(
                              criterion.description,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: TeatroColors.muted),
                            ),
                          ),
                        DropdownButtonFormField<int>(
                          initialValue: _ratings[criterion.id],
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Rating · ${criterion.name}',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 1,
                              child: Text('1 · Needs revision'),
                            ),
                            DropdownMenuItem(
                              value: 2,
                              child: Text('2 · Developing'),
                            ),
                            DropdownMenuItem(
                              value: 3,
                              child: Text('3 · Proficient'),
                            ),
                            DropdownMenuItem(
                              value: 4,
                              child: Text('4 · Exemplary'),
                            ),
                          ],
                          validator: (value) =>
                              value == null ? 'Rate this criterion.' : null,
                          onChanged: (value) =>
                              setState(() => _ratings[criterion.id] = value),
                        ),
                      ],
                    ),
                  ),
                if (weighted != null) ...[
                  const Divider(height: 25),
                  Text(
                    'Weighted rubric preview: ${weighted.toStringAsFixed(1)} / 100',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 13),
          TeatroCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const TeatroEyebrow('WRITTEN FEEDBACK'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _feedback,
                  minLines: 4,
                  maxLines: 7,
                  decoration: const InputDecoration(
                    hintText: 'Write supportive, actionable feedback',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Add feedback before making a decision.'
                      : null,
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: TeatroColors.error),
                    ),
                  ),
                const SizedBox(height: 13),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _saving
                          ? null
                          : () => _save(data, 'revision_requested'),
                      icon: const Icon(Icons.edit_note),
                      label: Text(_saving ? 'Saving…' : 'Request revision'),
                    ),
                    FilledButton.icon(
                      onPressed: _saving ? null : () => _save(data, 'approved'),
                      icon: const Icon(Icons.check),
                      label: Text(_saving ? 'Saving…' : 'Approve submission'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SnapshotField extends StatelessWidget {
  const _SnapshotField({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 13),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TeatroEyebrow(label),
        const SizedBox(height: 4),
        Text(value.isEmpty ? 'Not provided in this submission.' : value),
      ],
    ),
  );
}

class _ReviewMessage extends StatelessWidget {
  const _ReviewMessage({
    required this.message,
    required this.icon,
    this.action,
  });
  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) => TeatroCard(
    child: LayoutBuilder(
      builder: (context, constraints) {
        final messageRow = Row(
          children: [
            Icon(icon, color: TeatroColors.rust),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        );
        if (action == null) return messageRow;
        return constraints.maxWidth < 500
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  messageRow,
                  Align(alignment: Alignment.centerRight, child: action!),
                ],
              )
            : Row(
                children: [
                  Expanded(child: messageRow),
                  action!,
                ],
              );
      },
    ),
  );
}

String _reviewError(Object error) {
  if (error is StateError) return error.message;
  if (error is PostgrestException) return error.message;
  if (error is AuthException) {
    return 'Your session may have expired. Sign in again.';
  }
  if (error is ArgumentError) {
    return error.message?.toString() ?? 'Check the review fields.';
  }
  return 'We could not load or save the review. Check your connection and try again.';
}

String _contentValue(Map<String, dynamic> content, String key) =>
    (content[key] as String? ?? '').trim();

String _date(DateTime value) =>
    '${value.day} ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][value.month - 1]} ${value.year}';

String _statusLabel(String value) => switch (value) {
  'under_review' => 'Under review',
  'revision_requested' => 'Revision requested',
  'approved' => 'Approved',
  _ => 'Submitted',
};

TeatroStatusTone _statusTone(String value) => switch (value) {
  'approved' => TeatroStatusTone.approved,
  'revision_requested' => TeatroStatusTone.revision,
  'under_review' => TeatroStatusTone.inProgress,
  _ => TeatroStatusTone.pending,
};

String _initials(String name) => name
    .split(RegExp(r'\s+'))
    .where((word) => word.isNotEmpty)
    .map((word) => word[0])
    .take(3)
    .join()
    .toUpperCase();
