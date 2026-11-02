import 'package:flutter/material.dart';
import '../../app/app_routes.dart';
import '../../app/app_theme.dart';
import '../../core/storage/private_media_avatar.dart';
import '../../core/widgets/teatro_widgets.dart';
import '../profile/user_profile.dart';
import '../teacher/data/teacher_student_progress_repository.dart';
import '../../core/widgets/teatro_design_widgets.dart';

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
                DesignPrimaryButton(
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
          TeatroSectionTitle(
            title: 'Assigned student progress',
            eyebrow: 'STUDENT ACTIVITY',
            actionLabel: 'View all students',
            onAction: () => onNavigate(AppDestination.studentProgress),
          ),
          const SizedBox(height: 11),
          if (snapshot.hasError)
            const TeatroEmptyState(
              title: 'Progress unavailable',
              description:
                  'Reopen this dashboard to retry loading assigned student records.',
              icon: Icons.cloud_off_outlined,
            )
          else if (snapshot.connectionState == ConnectionState.waiting)
            const Center(child: CircularProgressIndicator())
          else if (students!.isEmpty)
            const TeatroEmptyState(
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
                      PrivateMediaAvatar(
                        userId: student.id,
                        storagePath: student.avatarStoragePath,
                        label: 'Photo of ${student.fullName}',
                        fallback: _initials(student.fullName),
                        radius: 20,
                      ),
                      const SizedBox(width: 12),
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

  String _initials(String name) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty);
    final value = words
        .take(2)
        .map((word) => String.fromCharCode(word.runes.first))
        .join()
        .toUpperCase();
    return value.isEmpty ? '?' : value;
  }
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
