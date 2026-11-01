import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/student_dashboard_data.dart';
import '../../learning/models/learning_models.dart';
import '../../drafts/data/theme_draft_repository.dart';

abstract interface class StudentDashboardDataSource {
  Future<StudentDashboardProfile> loadProfile();

  Future<StudentLearningOverview> loadLearningOverview();

  Future<List<StudentRecentDraft>> loadRecentDrafts();
}

class SupabaseStudentDashboardDataSource implements StudentDashboardDataSource {
  SupabaseStudentDashboardDataSource({
    SupabaseClient? client,
    ThemeDraftRepository? draftRepository,
  }) : _client = client ?? Supabase.instance.client,
       _draftRepository =
           draftRepository ?? SupabaseThemeDraftRepository(client: client);

  final SupabaseClient _client;
  final ThemeDraftRepository _draftRepository;

  String get _studentId {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('Sign in to view your student dashboard.');
    }
    return user.id;
  }

  @override
  Future<StudentDashboardProfile> loadProfile() async {
    final profile = await _client
        .from('profiles')
        .select('full_name, year_level, section, school')
        .eq('id', _studentId)
        .maybeSingle();
    if (profile == null) {
      throw StateError('Your student profile could not be found.');
    }
    return StudentDashboardProfile(
      fullName: profile['full_name'] as String? ?? '',
      yearLevel: profile['year_level'] as String?,
      section: profile['section'] as String?,
      school: profile['school'] as String?,
    );
  }

  @override
  Future<StudentLearningOverview> loadLearningOverview() async {
    final studentId = _studentId;
    final queriedModuleRows = await _client
        .from('learning_modules')
        .select('module_id, title, description, display_order')
        .eq('is_published', true)
        .order('display_order');
    final queriedLessonRows = await _client
        .from('lessons')
        .select('lesson_id, module_id, title, lesson_order, content')
        .eq('is_published', true)
        .order('lesson_order');
    final lessonRows = queriedLessonRows
        .where((row) => !isSeedPlaceholderLesson(row['content'] as String?))
        .toList();
    final progressRows = await _client
        .from('lesson_progress')
        .select('lesson_id, status, updated_at')
        .eq('student_id', studentId)
        .order('updated_at', ascending: false);
    final attemptRows = await _client
        .from('quiz_attempts')
        .select('score')
        .eq('student_id', studentId);

    final lessonsByModule = <String, List<Map<String, dynamic>>>{};
    final lessonById = <String, Map<String, dynamic>>{};
    for (final row in lessonRows) {
      final lesson = Map<String, dynamic>.from(row);
      final moduleId = lesson['module_id'] as String;
      lessonsByModule.putIfAbsent(moduleId, () => []).add(lesson);
      lessonById[lesson['lesson_id'] as String] = lesson;
    }
    final moduleRows = queriedModuleRows.where((row) {
      final moduleId = row['module_id'] as String;
      return (lessonsByModule[moduleId] ?? const []).isNotEmpty;
    }).toList();

    final completedLessonIds = <String>{};
    StudentResumeLesson? resumeLesson;
    for (final row in progressRows) {
      final progress = Map<String, dynamic>.from(row);
      final lessonId = progress['lesson_id'] as String;
      final lesson = lessonById[lessonId];
      if (progress['status'] == 'completed' && lesson != null) {
        completedLessonIds.add(lessonId);
      }
      if (resumeLesson == null &&
          progress['status'] == 'in_progress' &&
          lesson != null) {
        final module = moduleRows.cast<Map<String, dynamic>?>().firstWhere(
          (row) => row?['module_id'] == lesson['module_id'],
          orElse: () => null,
        );
        if (module != null) {
          resumeLesson = StudentResumeLesson(
            title: lesson['title'] as String? ?? '',
            moduleTitle: module['title'] as String? ?? '',
            lessonOrder: (lesson['lesson_order'] as num?)?.toInt() ?? 0,
            moduleOrder: (module['display_order'] as num?)?.toInt() ?? 0,
            moduleLessonCount:
                (lessonsByModule[lesson['module_id'] as String] ?? const [])
                    .length,
          );
        }
      }
    }

    final modules = moduleRows.map((row) {
      final module = Map<String, dynamic>.from(row);
      final id = module['module_id'] as String;
      final lessons = lessonsByModule[id] ?? const <Map<String, dynamic>>[];
      final completed = lessons
          .where((lesson) => completedLessonIds.contains(lesson['lesson_id']))
          .length;
      return StudentModuleProgress(
        id: id,
        title: module['title'] as String? ?? '',
        description: module['description'] as String? ?? '',
        displayOrder: (module['display_order'] as num?)?.toInt() ?? 0,
        lessonCount: lessons.length,
        completedLessonCount: completed,
      );
    }).toList();

    if (resumeLesson == null) {
      for (final moduleRow in moduleRows) {
        final moduleId = moduleRow['module_id'] as String;
        for (final lesson in lessonsByModule[moduleId] ?? const []) {
          final lessonId = lesson['lesson_id'] as String;
          if (completedLessonIds.contains(lessonId)) continue;
          resumeLesson = StudentResumeLesson(
            title: lesson['title'] as String? ?? '',
            moduleTitle: moduleRow['title'] as String? ?? '',
            lessonOrder: (lesson['lesson_order'] as num?)?.toInt() ?? 0,
            moduleOrder: (moduleRow['display_order'] as num?)?.toInt() ?? 0,
            moduleLessonCount: (lessonsByModule[moduleId] ?? const []).length,
          );
          break;
        }
        if (resumeLesson != null) break;
      }
    }

    final scores = attemptRows
        .map((row) => row['score'])
        .whereType<num>()
        .map((score) => score.toDouble())
        .toList();
    final averageScore = scores.isEmpty
        ? null
        : scores.reduce((total, score) => total + score) / scores.length;
    return StudentLearningOverview(
      modules: modules,
      completedLessonCount: completedLessonIds.length,
      publishedLessonCount: lessonById.length,
      averageQuizScore: averageScore,
      resumeLesson: resumeLesson,
    );
  }

  @override
  Future<List<StudentRecentDraft>> loadRecentDrafts() async {
    final drafts = await _draftRepository.listDrafts();
    return drafts.take(3).map((draft) {
      return StudentRecentDraft(
        id: draft.id,
        title: draft.title,
        status: draft.status,
        updatedAt: draft.updatedAt,
        centralMessage: draft.centralMessage,
      );
    }).toList();
  }
}
