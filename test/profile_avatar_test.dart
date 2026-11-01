import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilocano_teatro_master/app/app_routes.dart';
import 'package:ilocano_teatro_master/app/app_theme.dart';
import 'package:ilocano_teatro_master/features/profile/profile_avatar.dart';
import 'package:ilocano_teatro_master/features/profile/profile_avatar_validator.dart';
import 'package:ilocano_teatro_master/features/profile/user_profile.dart';
import 'package:ilocano_teatro_master/features/profile/user_profile_screen.dart';
import 'package:ilocano_teatro_master/features/shell/app_shell.dart';
import 'support/fake_curriculum_repository.dart';
import 'support/fake_quiz_management_repository.dart';
import 'support/fake_quiz_repository.dart';
import 'support/fake_story_vault_repository.dart';
import 'support/fake_student_dashboard_data_source.dart';
import 'support/fake_student_learning_repository.dart';
import 'support/fake_teacher_review_repository.dart';
import 'support/fake_theme_draft_repository.dart';
import 'support/fake_notification_repository.dart';
import 'support/fake_identity_repositories.dart';

Future<Uint8List> _logoBytes() async {
  final data = await rootBundle.load('assets/branding/applogo.png');
  return data.buffer.asUint8List();
}

Future<void> _pumpProfile(
  WidgetTester tester,
  FakeUserProfileRepository repository, {
  required UserProfile initialProfile,
  ProfileAvatarPicker? picker,
  ValueChanged<UserProfile>? onUpdated,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: SingleChildScrollView(
          child: UserProfileScreen(
            role: AppRole.student,
            repository: repository,
            initialProfile: initialProfile,
            onProfileUpdated: onUpdated ?? (_) {},
            avatarPicker: picker,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('avatar validator accepts JPEG, PNG, WebP and enforces 5 MiB', () {
    expect(
      ProfileAvatarValidator.validate(Uint8List.fromList([0xff, 0xd8, 0xff])),
      ProfileAvatarFormat.jpeg,
    );
    expect(
      ProfileAvatarValidator.validate(
        Uint8List.fromList([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
      ),
      ProfileAvatarFormat.png,
    );
    expect(
      ProfileAvatarValidator.validate(
        Uint8List.fromList([
          0x52,
          0x49,
          0x46,
          0x46,
          0,
          0,
          0,
          0,
          0x57,
          0x45,
          0x42,
          0x50,
        ]),
      ),
      ProfileAvatarFormat.webp,
    );
    expect(
      () => ProfileAvatarValidator.validate(Uint8List(5 * 1024 * 1024 + 1)),
      throwsFormatException,
    );
  });

  testWidgets(
    'change photo previews locally then uploads and replaces safely',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final oldBytes = await _logoBytes();
      final repository = FakeUserProfileRepository();
      const oldPath = 'test-user/old.png';
      repository.avatarFiles[oldPath] = oldBytes;
      repository.profile = repository.profile.withAvatar(
        storagePath: oldPath,
        bytes: oldBytes,
      );
      final selectedBytes = oldBytes;
      UserProfile? updatedProfile;

      await _pumpProfile(
        tester,
        repository,
        initialProfile: await repository.loadCurrentProfile(),
        picker: () async => selectedBytes,
        onUpdated: (profile) => updatedProfile = profile,
      );
      await tester.tap(find.text('Change Photo'));
      await tester.pumpAndSettle();
      expect(find.text('Preview your photo before uploading.'), findsOneWidget);
      expect(repository.avatarUploadCount, 0);

      await tester.tap(find.text('Upload Photo'));
      await tester.pumpAndSettle();
      expect(repository.avatarUploadCount, 1);
      expect(repository.avatarDeleteCount, 1);
      expect(repository.avatarFiles.containsKey(oldPath), isFalse);
      expect(updatedProfile?.avatarStoragePath, isNot(oldPath));
      expect(
        repository.profilePathsWhenDeleting.single,
        updatedProfile?.avatarStoragePath,
      );
      expect(updatedProfile?.avatarBytes, selectedBytes);

      final persisted = await repository.loadCurrentProfile();
      expect(persisted.avatarStoragePath, updatedProfile?.avatarStoragePath);
      expect(persisted.avatarBytes, selectedBytes);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed profile-path save preserves the old avatar and cleans upload',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final bytes = await _logoBytes();
      final repository = FakeUserProfileRepository(failAvatarSave: true);
      const oldPath = 'test-user/old.png';
      repository.avatarFiles[oldPath] = bytes;
      repository.profile = repository.profile.withAvatar(
        storagePath: oldPath,
        bytes: bytes,
      );
      await _pumpProfile(
        tester,
        repository,
        initialProfile: await repository.loadCurrentProfile(),
        picker: () async => bytes,
      );

      await tester.tap(find.text('Change Photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Upload Photo'));
      await tester.pumpAndSettle();

      expect(repository.profile.avatarStoragePath, oldPath);
      expect(repository.avatarFiles.keys, [oldPath]);
      expect(repository.avatarDeleteCount, 1);
      expect(repository.profilePathsWhenDeleting, [oldPath]);
      expect(find.textContaining('Avatar profile save failed'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('remove clears the profile path before deleting the old object', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final bytes = await _logoBytes();
    final repository = FakeUserProfileRepository();
    const path = 'test-user/current.webp';
    repository.avatarFiles[path] = bytes;
    repository.profile = repository.profile.withAvatar(
      storagePath: path,
      bytes: bytes,
    );
    await _pumpProfile(
      tester,
      repository,
      initialProfile: await repository.loadCurrentProfile(),
    );

    await tester.tap(find.text('Remove Photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove photo'));
    await tester.pumpAndSettle();

    expect(repository.profile.avatarStoragePath, isNull);
    expect(repository.avatarFiles, isEmpty);
    expect(repository.profilePathsWhenDeleting, [null]);
    expect(find.text('TS'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('upload errors preserve current avatar and show feedback', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final bytes = await _logoBytes();
    final repository = FakeUserProfileRepository(failAvatarUpload: true);
    const path = 'test-user/current.png';
    repository.avatarFiles[path] = bytes;
    repository.profile = repository.profile.withAvatar(
      storagePath: path,
      bytes: bytes,
    );
    await _pumpProfile(
      tester,
      repository,
      initialProfile: await repository.loadCurrentProfile(),
      picker: () async => bytes,
    );

    await tester.tap(find.text('Change Photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upload Photo'));
    await tester.pumpAndSettle();

    expect(repository.profile.avatarStoragePath, path);
    expect(repository.avatarFiles.keys, [path]);
    expect(find.textContaining('Avatar upload failed'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('top bar and profile card use the same saved avatar', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    final bytes = await _logoBytes();
    final repository = FakeUserProfileRepository();
    const path = 'test-user/saved.jpg';
    repository.avatarFiles[path] = bytes;
    repository.profile = repository.profile.withAvatar(
      storagePath: path,
      bytes: bytes,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AppShell(
          role: AppRole.student,
          initialDestination: AppDestination.profile,
          dashboardDataSource: FakeStudentDashboardDataSource(),
          learningRepository: FakeStudentLearningRepository(),
          profileRepository: repository,
          teacherProgressRepository: FakeTeacherStudentProgressRepository(),
          curriculumRepository: FakeCurriculumRepository(),
          quizRepository: FakeQuizRepository(),
          quizManagementRepository: FakeQuizManagementRepository(),
          themeDraftRepository: FakeThemeDraftRepository(),
          teacherReviewRepository: FakeTeacherReviewRepository(
            assignedStudentIds: const {},
            submissions: const [],
          ),
          notificationRepository: FakeNotificationRepository(),
          storyVaultRepository: FakeStoryVaultRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final avatars = tester.widgetList<ProfileAvatar>(
      find.byType(ProfileAvatar),
    );
    expect(avatars.length, 2);
    expect(
      avatars.every((avatar) => avatar.profile?.avatarBytes != null),
      isTrue,
    );
    expect(
      avatars.every((avatar) => avatar.profile?.avatarStoragePath == path),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });
}
