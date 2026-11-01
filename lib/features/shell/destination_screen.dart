import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../learning/data/student_learning_repository.dart';
import '../learning/models/learning_models.dart';
import '../learning/student_learning_screens.dart';
import '../learning/student_progress_screen.dart';
import '../profile/user_profile.dart';
import '../profile/user_profile_repository.dart';
import '../profile/user_profile_screen.dart';
import '../teacher/data/teacher_student_progress_repository.dart';
import '../teacher/teacher_student_progress_screen.dart';
import '../teacher/data/curriculum_repository.dart';
import '../teacher/data/teacher_review_repository.dart';
import '../teacher/teacher_review_screens.dart';
import '../teacher/teacher_curriculum_screen.dart';
import '../quiz/data/quiz_repository.dart';
import '../quiz/data/quiz_management_repository.dart';
import '../drafts/data/theme_draft_repository.dart';
import '../notifications/notifications_screen.dart';
import '../notifications/data/notification_repository.dart';
import '../drafts/theme_draft_screens.dart';
import '../quiz/student_quiz_screen.dart';
import '../story_vault/data/story_vault_repository.dart';
import '../story_vault/models/story_models.dart';
import '../story_vault/story_editor_screens.dart';
import '../story_vault/story_vault_screens.dart';
import '../teacher/teacher_dashboard_screen.dart';

class DestinationScreen extends StatelessWidget {
  const DestinationScreen({
    required this.role,
    required this.destination,
    required this.onNavigate,
    required this.onNavigateWithPayload,
    required this.learningRepository,
    required this.profileRepository,
    required this.teacherProgressRepository,
    required this.curriculumRepository,
    required this.quizRepository,
    required this.quizManagementRepository,
    required this.themeDraftRepository,
    required this.teacherReviewRepository,
    required this.storyVaultRepository,
    this.notificationRepository,
    this.onUnreadNotificationCountChanged,
    required this.onProfileUpdated,
    this.onSignOut,
    this.arguments,
    this.profile,
    super.key,
  });

  final AppRole role;
  final AppDestination destination;
  final ValueChanged<AppDestination> onNavigate;
  final void Function(AppDestination, Object?) onNavigateWithPayload;
  final StudentLearningRepository learningRepository;
  final UserProfileRepository profileRepository;
  final TeacherStudentProgressRepository teacherProgressRepository;
  final CurriculumRepository curriculumRepository;
  final QuizRepository quizRepository;
  final QuizManagementRepository quizManagementRepository;
  final ThemeDraftRepository themeDraftRepository;
  final TeacherReviewRepository teacherReviewRepository;
  final StoryVaultRepository storyVaultRepository;
  final NotificationRepository? notificationRepository;
  final ValueChanged<int>? onUnreadNotificationCountChanged;
  final ValueChanged<UserProfile> onProfileUpdated;
  final Future<void> Function()? onSignOut;
  final UserProfile? profile;
  final Object? arguments;

  @override
  Widget build(BuildContext context) {
    if (role == AppRole.student) {
      return switch (destination) {
        AppDestination.learning => StudentLearningScreen(
          repository: learningRepository,
          onNavigate: onNavigate,
          onNavigateWithPayload: onNavigateWithPayload,
        ),
        AppDestination.moduleOverview => ModuleOverviewScreen(
          repository: learningRepository,
          moduleId: arguments is String ? arguments as String : null,
          onNavigate: onNavigate,
          onNavigateWithPayload: onNavigateWithPayload,
        ),
        AppDestination.lesson => LessonReaderScreen(
          repository: learningRepository,
          route: arguments is LearningLessonRoute
              ? arguments as LearningLessonRoute
              : null,
          onNavigate: onNavigate,
          onNavigateWithPayload: onNavigateWithPayload,
        ),
        AppDestination.quiz => StudentQuizScreen(
          repository: quizRepository,
          onNavigate: onNavigate,
          initialQuizId: arguments is String ? arguments as String : null,
        ),
        AppDestination.storyVault => _storyVault(),
        AppDestination.storyDetail =>
          arguments is String
              ? _storyOverview(arguments as String)
              : _unavailable(context),
        AppDestination.storyChapter =>
          arguments is StoryChapterRouteArgs
              ? _storyChapter(arguments as StoryChapterRouteArgs)
              : _unavailable(context),
        AppDestination.storyEditor => _unavailable(context),
        AppDestination.storyChapterEditor => _unavailable(context),
        AppDestination.themeBuilder => ThemeBuilderScreen(
          repository: themeDraftRepository,
          initialInspiration:
              _themeBuilderStart?.storyTitle ??
              (arguments is String && !_looksLikeUuid(arguments as String)
                  ? arguments as String
                  : null),
          initialStoryId: _themeBuilderStart?.storyId,
          initialDraftId:
              _themeBuilderStart?.draftId ??
              (arguments is String && _looksLikeUuid(arguments as String)
                  ? arguments as String
                  : null),
          onSubmitted: () => onNavigate(AppDestination.drafts),
        ),
        AppDestination.drafts => StudentDraftsScreen(
          repository: themeDraftRepository,
          onOpenBuilder: (id) => onNavigateWithPayload(
            AppDestination.themeBuilder,
            id.isEmpty ? null : id,
          ),
        ),
        AppDestination.submissionReview => StudentDraftsScreen(
          repository: themeDraftRepository,
          focusSubmissionId: arguments is String ? arguments as String : null,
          onOpenBuilder: (id) =>
              onNavigateWithPayload(AppDestination.themeBuilder, id),
        ),
        AppDestination.progress => StudentProgressScreen(
          repository: learningRepository,
          quizRepository: quizRepository,
          onNavigate: onNavigate,
          onNavigateWithPayload: onNavigateWithPayload,
        ),
        AppDestination.notifications => NotificationsScreen(
          role: role,
          repository: notificationRepository,
          onUnreadCountChanged: onUnreadNotificationCountChanged,
          onNavigate: onNavigateWithPayload,
        ),
        AppDestination.profile => UserProfileScreen(
          role: role,
          repository: profileRepository,
          initialProfile: profile,
          onProfileUpdated: onProfileUpdated,
          onSignOut: onSignOut,
        ),
        AppDestination.dashboard => const SizedBox.shrink(),
        _ => _unavailable(context),
      };
    }

    return switch (destination) {
      AppDestination.dashboard => TeacherDashboardScreen(
        onNavigate: onNavigate,
        profile: profile,
        progressRepository: teacherProgressRepository,
      ),
      AppDestination.reviewQueue => ReviewQueueScreen(
        repository: teacherReviewRepository,
        onOpenSubmission: (submissionId) => onNavigateWithPayload(
          AppDestination.submissionReview,
          submissionId,
        ),
      ),
      AppDestination.submissionReview => SubmissionReviewScreen(
        repository: teacherReviewRepository,
        submissionId: arguments is String ? arguments as String : '',
        onBack: () => onNavigate(AppDestination.reviewQueue),
        onReviewCompleted: () => onNavigate(AppDestination.reviewQueue),
      ),
      AppDestination.studentProgress => TeacherStudentProgressScreen(
        repository: teacherProgressRepository,
      ),
      AppDestination.learningContent => TeacherCurriculumScreen(
        repository: curriculumRepository,
        quizManagementRepository: quizManagementRepository,
      ),
      AppDestination.storyVault => _storyVault(),
      AppDestination.storyDetail =>
        arguments is String
            ? _storyOverview(arguments as String)
            : _unavailable(context),
      AppDestination.storyChapter =>
        arguments is StoryChapterRouteArgs
            ? _storyChapter(arguments as StoryChapterRouteArgs)
            : _unavailable(context),
      AppDestination.storyEditor => StoryEditorScreen(
        storyId: arguments is String ? arguments as String : null,
        repository: storyVaultRepository,
        onBack: () => onNavigate(AppDestination.storyVault),
        onPreview: (storyId) =>
            onNavigateWithPayload(AppDestination.storyDetail, storyId),
        onEditChapter: (storyId, chapterId) => onNavigateWithPayload(
          AppDestination.storyChapterEditor,
          StoryChapterEditorRouteArgs(storyId: storyId, chapterId: chapterId),
        ),
      ),
      AppDestination.storyChapterEditor =>
        arguments is StoryChapterEditorRouteArgs
            ? StoryChapterEditorScreen(
                storyId: (arguments as StoryChapterEditorRouteArgs).storyId,
                chapterId: (arguments as StoryChapterEditorRouteArgs).chapterId,
                repository: storyVaultRepository,
                onBack: () => onNavigateWithPayload(
                  AppDestination.storyEditor,
                  (arguments as StoryChapterEditorRouteArgs).storyId,
                ),
              )
            : _unavailable(context),
      AppDestination.notifications => NotificationsScreen(
        role: role,
        repository: notificationRepository,
        onUnreadCountChanged: onUnreadNotificationCountChanged,
        onNavigate: onNavigateWithPayload,
      ),
      AppDestination.profile => UserProfileScreen(
        role: role,
        repository: profileRepository,
        initialProfile: profile,
        onProfileUpdated: onProfileUpdated,
        onSignOut: onSignOut,
      ),
      _ => _unavailable(context),
    };
  }

  ThemeBuilderStart? get _themeBuilderStart =>
      arguments is ThemeBuilderStart ? arguments as ThemeBuilderStart : null;

  Widget _storyVault() => StoryVaultScreen(
    role: role,
    repository: storyVaultRepository,
    onOpenStory: (storyId) =>
        onNavigateWithPayload(AppDestination.storyDetail, storyId),
    onReadChapter: (storyId, chapterId, {preview = false}) =>
        onNavigateWithPayload(
          AppDestination.storyChapter,
          StoryChapterRouteArgs(
            storyId: storyId,
            chapterId: chapterId,
            preview: preview,
          ),
        ),
    onUseStory: (selection) => onNavigateWithPayload(
      AppDestination.themeBuilder,
      ThemeBuilderStart(
        storyId: selection.storyId,
        storyTitle: selection.title,
      ),
    ),
    onEditStory: (storyId) =>
        onNavigateWithPayload(AppDestination.storyEditor, storyId),
  );

  Widget _storyOverview(String storyId) => StoryOverviewScreen(
    storyId: storyId,
    role: role,
    repository: storyVaultRepository,
    onBack: () => onNavigate(AppDestination.storyVault),
    onReadChapter: (id, chapterId, {preview = false}) => onNavigateWithPayload(
      AppDestination.storyChapter,
      StoryChapterRouteArgs(
        storyId: id,
        chapterId: chapterId,
        preview: preview,
      ),
    ),
    onUseStory: (selection) => onNavigateWithPayload(
      AppDestination.themeBuilder,
      ThemeBuilderStart(
        storyId: selection.storyId,
        storyTitle: selection.title,
      ),
    ),
    onEditStory: (id) => onNavigateWithPayload(AppDestination.storyEditor, id),
  );

  Widget _storyChapter(StoryChapterRouteArgs route) => StoryChapterReaderScreen(
    storyId: route.storyId,
    chapterId: route.chapterId,
    preview: route.preview,
    role: role,
    repository: storyVaultRepository,
    onNavigate: onNavigateWithPayload,
  );

  Widget _unavailable(BuildContext context) => Center(
    child: Text(
      'This screen is not available for this account role.',
      style: Theme.of(context).textTheme.bodyMedium,
    ),
  );
}

bool _looksLikeUuid(String value) => RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
).hasMatch(value);
