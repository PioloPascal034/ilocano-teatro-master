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
import 'demo_content.dart';
import 'student_creation_screens.dart';
import 'student_learning_screens.dart' show KnowledgeCheckScreen;
import 'student_other_screens.dart' show StudentNotificationsScreen;
import 'student_story_screens.dart';
import 'teacher_screens.dart';

class PrototypeDestinationScreen extends StatelessWidget {
  const PrototypeDestinationScreen({
    required this.role,
    required this.destination,
    required this.onNavigate,
    required this.onNavigateWithPayload,
    required this.learningRepository,
    required this.profileRepository,
    required this.teacherProgressRepository,
    required this.onProfileUpdated,
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
  final ValueChanged<UserProfile> onProfileUpdated;
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
        AppDestination.quiz => KnowledgeCheckScreen(onNavigate: onNavigate),
        AppDestination.storyVault => StoryVaultScreen(
          onNavigate: onNavigate,
          onOpenStory: (story) =>
              onNavigateWithPayload(AppDestination.storyDetail, story),
        ),
        AppDestination.storyDetail => StoryDetailsScreen(
          story: arguments is DemoStory
              ? arguments as DemoStory
              : demoStories.first,
          onBack: () => onNavigate(AppDestination.storyVault),
          onUseAsInspiration: (title) =>
              onNavigateWithPayload(AppDestination.themeBuilder, title),
        ),
        AppDestination.themeBuilder => ThemeBuilderScreen(
          initialInspiration: arguments is String ? arguments as String : null,
          initialDraft: arguments is DemoDraft ? arguments as DemoDraft : null,
        ),
        AppDestination.drafts => DraftsScreen(
          onNavigate: onNavigate,
          onOpenSubmission: onNavigateWithPayload,
          onOpenBuilder: onNavigateWithPayload,
        ),
        AppDestination.submissionReview => StudentSubmissionDetailsScreen(
          draft: arguments is DemoDraft
              ? arguments as DemoDraft
              : demoDrafts.first,
          onBack: () => onNavigate(AppDestination.drafts),
          onEdit: onNavigateWithPayload,
        ),
        AppDestination.progress => StudentProgressScreen(
          repository: learningRepository,
          onNavigate: onNavigate,
          onNavigateWithPayload: onNavigateWithPayload,
        ),
        AppDestination.notifications => const StudentNotificationsScreen(),
        AppDestination.profile => UserProfileScreen(
          role: role,
          repository: profileRepository,
          initialProfile: profile,
          onProfileUpdated: onProfileUpdated,
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
        onOpenSubmission: (draft) =>
            onNavigateWithPayload(AppDestination.submissionReview, draft),
      ),
      AppDestination.submissionReview => SubmissionReviewScreen(
        draft: arguments is DemoDraft
            ? arguments as DemoDraft
            : demoDrafts.first,
        onBack: () => onNavigate(AppDestination.reviewQueue),
      ),
      AppDestination.studentProgress => TeacherStudentProgressScreen(
        repository: teacherProgressRepository,
      ),
      AppDestination.learningContent => const LearningContentScreen(),
      AppDestination.notifications => const TeacherNotificationsScreen(),
      AppDestination.profile => UserProfileScreen(
        role: role,
        repository: profileRepository,
        initialProfile: profile,
        onProfileUpdated: onProfileUpdated,
      ),
      _ => _unavailable(context),
    };
  }

  Widget _unavailable(BuildContext context) => Center(
    child: Text(
      'This screen is not available for this account role.',
      style: Theme.of(context).textTheme.bodyMedium,
    ),
  );
}
