import 'package:ilocano_teatro_master/features/profile/user_profile.dart';
import 'package:ilocano_teatro_master/features/profile/user_profile_repository.dart';
import 'package:ilocano_teatro_master/features/teacher/data/teacher_student_progress_repository.dart';

class FakeUserProfileRepository implements UserProfileRepository {
  FakeUserProfileRepository({String role = 'student'})
    : profile = UserProfile(
        id: 'test-user',
        email: role == 'student'
            ? 'student@example.test'
            : 'teacher@example.test',
        fullName: role == 'student' ? 'Test Student' : 'Test Teacher',
        role: role,
        school: 'Test School',
        yearLevel: role == 'student' ? 'Grade 10' : null,
        section: role == 'student' ? 'Rizal' : null,
        department: role == 'teacher' ? 'Languages' : null,
      );

  UserProfile profile;

  @override
  Future<UserProfile> loadCurrentProfile() async => profile;

  @override
  Future<UserProfile> updateCurrentProfile({
    required String fullName,
    required String? school,
    required String? yearLevel,
    required String? section,
    required String? department,
  }) async {
    profile = UserProfile(
      id: profile.id,
      email: profile.email,
      fullName: fullName,
      role: profile.role,
      school: school,
      yearLevel: yearLevel,
      section: section,
      department: department,
    );
    return profile;
  }
}

class FakeTeacherStudentProgressRepository
    implements TeacherStudentProgressRepository {
  FakeTeacherStudentProgressRepository({
    this.students = const [],
    this.metrics = const TeacherDashboardMetrics(
      pendingSubmissions: 0,
      completedReviews: 0,
      revisionRequests: 0,
    ),
  });

  final List<TeacherStudentProgress> students;
  final TeacherDashboardMetrics metrics;

  @override
  Future<List<TeacherStudentProgress>> loadAssignedStudents() async => students;

  @override
  Future<TeacherDashboardMetrics> loadDashboardMetrics() async => metrics;
}
