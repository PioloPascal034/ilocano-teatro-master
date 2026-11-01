import 'package:ilocano_teatro_master/features/dashboard/data/student_dashboard_data_source.dart';
import 'package:ilocano_teatro_master/features/dashboard/models/student_dashboard_data.dart';

class FakeStudentDashboardDataSource implements StudentDashboardDataSource {
  FakeStudentDashboardDataSource({
    this.profile = const StudentDashboardProfile(fullName: 'Maria Alvarado'),
    this.learning = const StudentLearningOverview(
      modules: [],
      completedLessonCount: 0,
      publishedLessonCount: 0,
      averageQuizScore: null,
    ),
    this.drafts = const [],
    this.failProfile = false,
    this.failLearning = false,
    this.failDrafts = false,
  });

  final StudentDashboardProfile profile;
  final StudentLearningOverview learning;
  final List<StudentRecentDraft> drafts;
  final bool failProfile;
  final bool failLearning;
  final bool failDrafts;

  @override
  Future<StudentDashboardProfile> loadProfile() async {
    if (failProfile) throw StateError('profile query failed');
    return profile;
  }

  @override
  Future<StudentLearningOverview> loadLearningOverview() async {
    if (failLearning) throw StateError('learning query failed');
    return learning;
  }

  @override
  Future<List<StudentRecentDraft>> loadRecentDrafts() async {
    if (failDrafts) throw StateError('draft query failed');
    return drafts;
  }
}
