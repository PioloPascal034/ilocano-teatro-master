import 'package:flutter/material.dart';
import '../../app/app_routes.dart';
import '../../app/app_theme.dart';
import '../../core/widgets/teatro_widgets.dart';
import '../profile/user_profile.dart';
import '../teacher/data/teacher_student_progress_repository.dart';
import 'demo_content.dart';
import 'prototype_widgets.dart';

class TeacherDashboardScreen extends StatelessWidget {
  const TeacherDashboardScreen({
    required this.onNavigate,
    required this.profile,
    required this.progressRepository,
    super.key,
  });
  final ValueChanged<AppDestination> onNavigate;
  final UserProfile? profile;
  final TeacherStudentProgressRepository progressRepository;

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<(List<TeacherStudentProgress>, TeacherDashboardMetrics)>(
    future: _loadOverview(),
    builder: (context, snapshot) {
      final overview = snapshot.data;
      final students = overview?.$1;
      final metrics = overview?.$2;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: TeatroColors.dark,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TeatroEyebrow(
                  'REVIEWER OVERVIEW',
                  color: Color(0xFFD4D9D1),
                ),
                const SizedBox(height: 7),
                if (profile?.firstName.isNotEmpty == true) ...[
                  Text(
                    'Welcome back, ${profile!.firstName}.',
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                ],
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'Support every student\n'),
                      TextSpan(
                        text: 'story in progress.',
                        style: const TextStyle(
                          color: Color(0xFFE5BD57),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                  style: Theme.of(
                    context,
                  ).textTheme.displayMedium?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.hasError
                      ? 'Assigned student information could not be loaded.'
                      : snapshot.connectionState == ConnectionState.waiting
                      ? 'Loading your assigned student activity…'
                      : '${students!.length} students are assigned to your account.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFD4DCD4),
                  ),
                ),
                const SizedBox(height: 16),
                DemoPrimaryButton(
                  label: 'Open review queue',
                  icon: Icons.arrow_forward,
                  onPressed: () => onNavigate(AppDestination.reviewQueue),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth <= 650 ? 2 : 4;
              final width =
                  (constraints.maxWidth - (columns - 1) * 12) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _TeacherMetric(
                    width: width,
                    value: students == null ? '—' : '${students.length}',
                    label: 'Assigned students',
                    icon: Icons.description_outlined,
                    color: TeatroColors.rust,
                  ),
                  _TeacherMetric(
                    width: width,
                    value: metrics == null
                        ? '—'
                        : '${metrics.pendingSubmissions}',
                    label: 'Pending submissions',
                    icon: Icons.groups_2_outlined,
                    color: TeatroColors.blue,
                  ),
                  _TeacherMetric(
                    width: width,
                    value: metrics == null
                        ? '—'
                        : '${metrics.completedReviews}',
                    label: 'Completed reviews',
                    icon: Icons.school_outlined,
                    color: TeatroColors.moss,
                  ),
                  _TeacherMetric(
                    width: width,
                    value: metrics == null
                        ? '—'
                        : '${metrics.revisionRequests}',
                    label: 'Revision requests',
                    icon: Icons.bar_chart,
                    color: TeatroColors.gold,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 31),
          DemoSectionTitle(
            title: 'Assigned student progress',
            eyebrow: 'STUDENT ACTIVITY',
            actionLabel: 'View all students',
            onAction: () => onNavigate(AppDestination.studentProgress),
          ),
          const SizedBox(height: 11),
          if (snapshot.hasError)
            const DemoEmptyState(
              title: 'Progress unavailable',
              description:
                  'Reopen this dashboard to retry loading assigned student records.',
              icon: Icons.cloud_off_outlined,
            )
          else if (snapshot.connectionState == ConnectionState.waiting)
            const Center(child: CircularProgressIndicator())
          else if (students!.isEmpty)
            const DemoEmptyState(
              title: 'No students assigned yet',
              description: 'Assigned students will appear here.',
              icon: Icons.groups_2_outlined,
            )
          else
            for (final student in students.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TeatroCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          student.fullName.trim().isEmpty
                              ? 'Not provided'
                              : student.fullName,
                        ),
                      ),
                      Text(
                        '${student.completedLessons} / ${student.totalLessons} lessons',
                      ),
                    ],
                  ),
                ),
              ),
        ],
      );
    },
  );

  Future<(List<TeacherStudentProgress>, TeacherDashboardMetrics)>
  _loadOverview() async => (
    await progressRepository.loadAssignedStudents(),
    await progressRepository.loadDashboardMetrics(),
  );
}

class _TeacherMetric extends StatelessWidget {
  const _TeacherMetric({
    required this.width,
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });
  final double width;
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: TeatroCard(
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: Theme.of(context).textTheme.headlineMedium),
                Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: TeatroColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class ReviewQueueScreen extends StatefulWidget {
  const ReviewQueueScreen({required this.onOpenSubmission, super.key});
  final ValueChanged<DemoDraft> onOpenSubmission;

  @override
  State<ReviewQueueScreen> createState() => _ReviewQueueScreenState();
}

class _ReviewQueueScreenState extends State<ReviewQueueScreen> {
  final _searchController = TextEditingController();
  String _filter = 'Pending';
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<DemoDraft> get _visibleDrafts => demoReviewQueue.where((draft) {
    final matchesFilter =
        _filter == 'All' || _statusMatches(draft.status, _filter);
    final matchesQuery = '${draft.student} ${draft.title}'
        .toLowerCase()
        .contains(_query.toLowerCase());
    return matchesFilter && matchesQuery;
  }).toList();

  bool _statusMatches(String status, String filter) => switch (filter) {
    'Pending' => status == 'Submitted',
    'Under Review' => status == 'Under Review',
    'Revision Requested' => status == 'Revision Requested',
    'Approved' => status == 'Approved',
    _ => true,
  };

  @override
  Widget build(BuildContext context) => DemoPageBody(
    eyebrow: 'THEME ASSESSMENTS',
    title: 'Review queue',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const DemoDataNotice(),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 850;
            final search = SizedBox(
              width: compact ? double.infinity : 355,
              child: DemoSearchField(
                controller: _searchController,
                hint: 'Search student or concept',
                onChanged: (value) => setState(() => _query = value),
              ),
            );
            final filters = DemoFilterTabs(
              labels: const [
                'All',
                'Pending',
                'Under Review',
                'Revision Requested',
                'Approved',
              ],
              selected: _filter,
              onSelected: (value) => setState(() => _filter = value),
            );
            return compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [search, const SizedBox(height: 10), filters],
                  )
                : Row(
                    children: [
                      Expanded(child: search),
                      const SizedBox(width: 14),
                      Expanded(flex: 2, child: filters),
                    ],
                  );
          },
        ),
        const SizedBox(height: 15),
        if (_visibleDrafts.isEmpty)
          const DemoEmptyState(
            title: 'No submissions match',
            description: 'Adjust your search or status filter.',
            icon: Icons.inbox_outlined,
          )
        else
          for (final draft in _visibleDrafts)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _QueueRow(
                draft: draft,
                onTap: () => widget.onOpenSubmission(draft),
              ),
            ),
      ],
    ),
  );
}

class _QueueRow extends StatelessWidget {
  const _QueueRow({required this.draft, required this.onTap});
  final DemoDraft draft;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: TeatroColors.paper,
    borderRadius: BorderRadius.circular(8),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: TeatroCard(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 570) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 15,
                        backgroundColor: const Color(0xFFE5C4AE),
                        child: Text(
                          _initials(draft.student),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: const Color(0xFF804123)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          draft.student,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                      DemoStatus(status: draft.status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    draft.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              );
            }
            return Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFFE5C4AE),
                  child: Text(
                    _initials(draft.student),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: const Color(0xFF804123),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 175,
                  child: Text(
                    draft.student,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                Expanded(
                  child: Text(
                    draft.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(width: 10),
                DemoStatus(status: draft.status),
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
    required this.draft,
    required this.onBack,
    super.key,
  });
  final DemoDraft draft;
  final VoidCallback onBack;

  @override
  State<SubmissionReviewScreen> createState() => _SubmissionReviewScreenState();
}

class _SubmissionReviewScreenState extends State<SubmissionReviewScreen> {
  final _feedbackController = TextEditingController(
    text:
        'Your central message is clear and compassionate. Strengthen the conflict by showing what the community could lose if the leader does not change.',
  );
  final _formKey = GlobalKey<FormState>();
  final Map<String, int?> _scores = {
    for (final item in demoRubric) item.$1: null,
  };

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _submitDecision(String decision) async {
    if (!_formKey.currentState!.validate()) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$decision this concept?'),
        content: const Text(
          'This is a review prototype. No review, score, or notification will be saved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continue reviewing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(decision),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      showDemoMessage(context, 'review decision was previewed only');
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      DemoBackButton(label: 'Review queue', onPressed: widget.onBack),
      const DemoDataNotice(),
      LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth <= 700;
          final title = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TeatroEyebrow(
                '${widget.draft.student.toUpperCase()} · GRADE 10',
                color: TeatroColors.rust,
              ),
              const SizedBox(height: 5),
              Text(
                widget.draft.title,
                style: Theme.of(context).textTheme.displayMedium,
              ),
              Text(
                '${widget.draft.lastUpdated} · Inspired by ${widget.draft.inspiration}',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: TeatroColors.muted),
              ),
            ],
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (compact)
                title
              else
                Row(
                  children: [
                    Expanded(child: title),
                    DemoStatus(status: widget.draft.status),
                  ],
                ),
              if (compact)
                const Padding(
                  padding: EdgeInsets.only(top: 7),
                  child: DemoStatus(status: 'Submitted'),
                ),
              const SizedBox(height: 17),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    compact
                        ? Column(
                            children: [
                              _ConceptCard(draft: widget.draft),
                              const SizedBox(height: 12),
                              _RubricCard(scores: _scores),
                            ],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _ConceptCard(draft: widget.draft),
                              ),
                              const SizedBox(width: 13),
                              Expanded(child: _RubricCard(scores: _scores)),
                            ],
                          ),
                    const SizedBox(height: 13),
                    TeatroCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const TeatroEyebrow('WRITTEN FEEDBACK'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _feedbackController,
                            minLines: 4,
                            maxLines: 7,
                            decoration: const InputDecoration(
                              hintText: 'Write supportive feedback',
                            ),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? 'Add feedback before making a decision.'
                                : null,
                          ),
                          const SizedBox(height: 13),
                          Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              DemoActionButton(
                                label: 'Request revision',
                                icon: Icons.edit_note,
                                onPressed: () =>
                                    _submitDecision('Request revision'),
                              ),
                              DemoPrimaryButton(
                                label: 'Approve submission',
                                icon: Icons.check,
                                onPressed: () => _submitDecision('Approve'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ],
  );
}

class _ConceptCard extends StatelessWidget {
  const _ConceptCard({required this.draft});
  final DemoDraft draft;

  @override
  Widget build(BuildContext context) => TeatroCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Student concept',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        _ReviewConceptField(
          label: 'Central message',
          value: draft.centralMessage,
        ),
        _ReviewConceptField(label: 'Dramatic conflict', value: draft.conflict),
        _ReviewConceptField(
          label: 'Stage presentation',
          value: draft.stageConcept,
        ),
      ],
    ),
  );
}

class _ReviewConceptField extends StatelessWidget {
  const _ReviewConceptField({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TeatroEyebrow(label),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: TeatroColors.muted),
        ),
      ],
    ),
  );
}

class _RubricCard extends StatelessWidget {
  const _RubricCard({required this.scores});
  final Map<String, int?> scores;

  @override
  Widget build(BuildContext context) => TeatroCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Theme assessment rubric',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        for (final criterion in demoRubric)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        criterion.$1,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    Text(
                      criterion.$2,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: TeatroColors.rust,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  criterion.$3,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: TeatroColors.muted),
                ),
                const SizedBox(height: 5),
                DropdownButtonFormField<int>(
                  initialValue: scores[criterion.$1],
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Score ${criterion.$1}',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 10,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 4, child: Text('4 — Exemplary')),
                    DropdownMenuItem(value: 3, child: Text('3 — Proficient')),
                    DropdownMenuItem(value: 2, child: Text('2 — Developing')),
                    DropdownMenuItem(
                      value: 1,
                      child: Text('1 — Needs revision'),
                    ),
                  ],
                  onChanged: (value) => scores[criterion.$1] = value,
                  validator: (value) =>
                      value == null ? 'Score this criterion.' : null,
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

class TeacherNotificationsScreen extends StatefulWidget {
  const TeacherNotificationsScreen({super.key});

  @override
  State<TeacherNotificationsScreen> createState() =>
      _TeacherNotificationsScreenState();
}

class _TeacherNotificationsScreenState
    extends State<TeacherNotificationsScreen> {
  late List<_TeacherNoticeState> _items;
  String _filter = 'All Notifications';

  @override
  void initState() {
    super.initState();
    _items = demoTeacherNotifications.map(_TeacherNoticeState.new).toList();
  }

  @override
  Widget build(BuildContext context) {
    final unread = _items.where((item) => !item.read).length;
    final labels = [
      'All Notifications',
      'Unread',
      'New Submissions',
      'Revisions',
      'Reminders',
    ];
    final visible = _items
        .where(
          (item) =>
              _filter == 'All Notifications' ||
              (_filter == 'Unread'
                  ? !item.read
                  : item.value.category == _filter),
        )
        .toList();
    return DemoPageBody(
      eyebrow: 'REVIEWER UPDATES',
      title: 'Notifications${unread > 0 ? '  $unread' : ''}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DemoDataNotice(),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => setState(() {
                for (final item in _items) {
                  item.read = true;
                }
              }),
              icon: const Icon(Icons.done_all, size: 16),
              label: const Text('Mark all as read'),
            ),
          ),
          DemoFilterTabs(
            labels: labels,
            selected: _filter,
            onSelected: (value) => setState(() => _filter = value),
          ),
          const SizedBox(height: 13),
          if (visible.isEmpty)
            const DemoEmptyState(
              title: 'No notifications here',
              description: 'No sample notifications match this filter.',
              icon: Icons.notifications_none_outlined,
            )
          else
            for (final item in visible)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _TeacherNotificationRow(
                  item: item,
                  onMark: () => setState(() => item.read = !item.read),
                ),
              ),
        ],
      ),
    );
  }
}

class _TeacherNoticeState {
  _TeacherNoticeState(this.value) : read = value.isRead;
  final DemoNotification value;
  bool read;
}

class _TeacherNotificationRow extends StatelessWidget {
  const _TeacherNotificationRow({required this.item, required this.onMark});
  final _TeacherNoticeState item;
  final VoidCallback onMark;

  @override
  Widget build(BuildContext context) => TeatroCard(
    child: Row(
      children: [
        Icon(
          item.read
              ? Icons.notifications_none
              : Icons.notifications_active_outlined,
          color: item.read ? TeatroColors.muted : TeatroColors.success,
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.value.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                item.value.detail,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: TeatroColors.muted),
              ),
              Text(
                item.value.dateLabel,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: TeatroColors.muted),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: onMark,
          child: Text(item.read ? 'Mark unread' : 'Mark read'),
        ),
      ],
    ),
  );
}

String _initials(String name) => name
    .split(RegExp(r'\s+'))
    .where((word) => word.isNotEmpty)
    .map((word) => word[0])
    .take(3)
    .join()
    .toUpperCase();
