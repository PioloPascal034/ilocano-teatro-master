import 'package:supabase_flutter/supabase_flutter.dart';

import '../../learning/models/learning_models.dart';

class TeacherStudentProgress {
  const TeacherStudentProgress({
    required this.id,
    required this.fullName,
    required this.avatarStoragePath,
    required this.completedLessons,
    required this.totalLessons,
    required this.quizAverage,
  });

  final String id;
  final String fullName;
  final String? avatarStoragePath;
  final int completedLessons;
  final int totalLessons;
  final double? quizAverage;

  double get completion =>
      totalLessons == 0 ? 0 : completedLessons / totalLessons;

  String get status {
    if (totalLessons == 0) return 'No lessons available';
    if (completedLessons >= totalLessons) return 'Complete';
    if (completedLessons > 0) return 'In progress';
    return 'Not started';
  }
}

abstract interface class TeacherStudentProgressRepository {
  Future<List<TeacherStudentProgress>> loadAssignedStudents();

  Future<TeacherDashboardMetrics> loadDashboardMetrics();
}

class TeacherDashboardMetrics {
  const TeacherDashboardMetrics({
    required this.pendingSubmissions,
    required this.completedReviews,
    required this.revisionRequests,
  });

  final int pendingSubmissions;
  final int completedReviews;
  final int revisionRequests;
}

class SupabaseTeacherStudentProgressRepository
    implements TeacherStudentProgressRepository {
  SupabaseTeacherStudentProgressRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String get _teacherId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('Sign in to view teacher activity.');
    return id;
  }

  @override
  Future<List<TeacherStudentProgress>> loadAssignedStudents() async {
    final teacherId = _teacherId;
    final assignments = await _client
        .from('teacher_students')
        .select('student_id')
        .eq('teacher_id', teacherId);
    final studentIds = assignments
        .map((row) => row['student_id'] as String)
        .toList();
    if (studentIds.isEmpty) return const [];

    final profiles = await _client
        .from('profiles')
        .select('id, full_name, avatar_storage_path')
        .inFilter('id', studentIds)
        .eq('role', 'student');
    final publishedModules = await _client
        .from('learning_modules')
        .select('module_id')
        .eq('is_published', true);
    final publishedModuleIds = publishedModules
        .map((row) => row['module_id'] as String)
        .toSet();
    final queriedLessons = await _client
        .from('lessons')
        .select('lesson_id, module_id, content')
        .eq('is_published', true);
    final lessons = queriedLessons
        .where(
          (row) =>
              publishedModuleIds.contains(row['module_id'] as String) &&
              !isSeedPlaceholderLesson(row['content'] as String?),
        )
        .toList();
    final progress = await _client
        .from('lesson_progress')
        .select('student_id, lesson_id, status')
        .inFilter('student_id', studentIds);
    final attempts = await _client
        .from('quiz_attempts')
        .select('student_id, score, completed_at')
        .inFilter('student_id', studentIds)
        .not('completed_at', 'is', null);

    final lessonIds = lessons.map((row) => row['lesson_id'] as String).toSet();
    final completedByStudent = <String, Set<String>>{};
    for (final row in progress) {
      if (row['status'] != 'completed') continue;
      final lessonId = row['lesson_id'] as String;
      if (!lessonIds.contains(lessonId)) continue;
      completedByStudent
          .putIfAbsent(row['student_id'] as String, () => <String>{})
          .add(lessonId);
    }

    final scoresByStudent = <String, List<double>>{};
    for (final row in attempts) {
      final score = row['score'];
      if (score is! num) continue;
      scoresByStudent
          .putIfAbsent(row['student_id'] as String, () => <double>[])
          .add(score.toDouble());
    }

    final result = profiles.map((row) {
      final id = row['id'] as String;
      final scores = scoresByStudent[id] ?? const <double>[];
      final average = scores.isEmpty
          ? null
          : scores.reduce((sum, score) => sum + score) / scores.length;
      return TeacherStudentProgress(
        id: id,
        fullName: (row['full_name'] as String? ?? '').trim(),
        avatarStoragePath: row['avatar_storage_path'] as String?,
        completedLessons: (completedByStudent[id] ?? const <String>{}).length,
        totalLessons: lessonIds.length,
        quizAverage: average,
      );
    }).toList();
    result.sort(
      (a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
    );
    return List.unmodifiable(result);
  }

  @override
  Future<TeacherDashboardMetrics> loadDashboardMetrics() async {
    if (_client.auth.currentUser == null) {
      throw StateError('Sign in to view teacher activity.');
    }
    final pending = await _client
        .from('submissions')
        .select('submission_id')
        .inFilter('status', ['submitted', 'under_review']);
    final reviews = await _client.from('reviews').select('review_id');
    final revisions = await _client
        .from('theme_drafts')
        .select('draft_id')
        .eq('status', 'revision_requested');
    return TeacherDashboardMetrics(
      pendingSubmissions: pending.length,
      completedReviews: reviews.length,
      revisionRequests: revisions.length,
    );
  }
}
