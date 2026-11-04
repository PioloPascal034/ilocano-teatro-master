import 'dart:typed_data';

import 'package:ilocano_teatro_master/features/profile/user_profile.dart';
import 'package:ilocano_teatro_master/features/profile/class_assignment.dart';
import 'package:ilocano_teatro_master/features/profile/user_profile_repository.dart';
import 'package:ilocano_teatro_master/features/profile/profile_avatar_validator.dart';
import 'package:ilocano_teatro_master/features/teacher/data/teacher_student_progress_repository.dart';

class FakeUserProfileRepository implements UserProfileRepository {
  FakeUserProfileRepository({
    String role = 'student',
    this.failAvatarUpload = false,
    this.failAvatarSave = false,
    this.failAvatarDelete = false,
    this.failAvatarDownload = false,
  }) : profile = UserProfile(
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
  final Map<String, Uint8List> avatarFiles = {};
  bool failAvatarUpload;
  bool failAvatarSave;
  bool failAvatarDelete;
  bool failAvatarDownload;
  final Set<String> failAvatarDownloadPaths = {};
  int avatarUploadCount = 0;
  int avatarDeleteCount = 0;
  final List<String?> profilePathsWhenDeleting = [];
  TeacherConnection? teacherConnection;
  ActiveClassCode? activeClassCode;

  @override
  Future<UserProfile> loadCurrentProfile() async {
    final path = profile.avatarStoragePath;
    if (path != null &&
        (failAvatarDownload || failAvatarDownloadPaths.contains(path))) {
      return profile.withAvatar(
        storagePath: path,
        loadError:
            'The saved photo could not be downloaded. Retry or choose a new photo.',
      );
    }
    return profile.withAvatar(
      storagePath: path,
      bytes: path == null ? null : avatarFiles[path],
    );
  }

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
      avatarUrl: profile.avatarUrl,
      avatarStoragePath: profile.avatarStoragePath,
    );
    return loadCurrentProfile();
  }

  @override
  Future<String> uploadAvatar(Uint8List bytes) async {
    avatarUploadCount++;
    if (failAvatarUpload) throw StateError('Avatar upload failed');
    final format = ProfileAvatarValidator.validate(bytes);
    final path = '${profile.id}/avatar_$avatarUploadCount.${format.extension}';
    avatarFiles[path] = bytes;
    return path;
  }

  @override
  Future<void> saveAvatarStoragePath(String? storagePath) async {
    if (failAvatarSave) throw StateError('Avatar profile save failed');
    if (storagePath != null && !storagePath.startsWith('${profile.id}/')) {
      throw StateError('Avatar path does not belong to this account');
    }
    profile = profile.withAvatar(storagePath: storagePath);
  }

  @override
  Future<void> deleteAvatar(String storagePath) async {
    avatarDeleteCount++;
    profilePathsWhenDeleting.add(profile.avatarStoragePath);
    if (failAvatarDelete) throw StateError('Avatar cleanup failed');
    if (!storagePath.startsWith('${profile.id}/')) {
      throw StateError('Avatar path does not belong to this account');
    }
    avatarFiles.remove(storagePath);
  }

  @override
  Future<TeacherConnection?> loadTeacherConnection() async => teacherConnection;

  @override
  Future<ActiveClassCode?> loadActiveClassCode() async => activeClassCode;

  @override
  Future<ActiveClassCode> generateClassCode() async {
    activeClassCode = ActiveClassCode(
      id: 'class-code-1',
      code: 'IT-TESTCODE',
      expiresAt: DateTime.now().toUtc().add(const Duration(days: 30)),
    );
    return activeClassCode!;
  }

  @override
  Future<void> revokeClassCode() async {
    activeClassCode = null;
  }

  @override
  Future<TeacherConnection> joinClassCode(String code) async {
    if (code != 'IT-TESTCODE') {
      throw StateError('That class code is invalid, expired, or revoked.');
    }
    teacherConnection = const TeacherConnection(
      teacherId: 'teacher-1',
      teacherName: 'Test Teacher',
    );
    return teacherConnection!;
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
