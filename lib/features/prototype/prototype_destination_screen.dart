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
import '../teacher/teacher_curriculum_screen.dart';
import '../quiz/data/quiz_repository.dart';
import '../quiz/data/quiz_management_repository.dart';
import '../drafts/data/theme_draft_repository.dart';
import '../drafts/theme_draft_screens.dart';
import '../quiz/student_quiz_screen.dart';
import 'demo_content.dart';
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
    required this.curriculumRepository,
    required this.quizRepository,
    required this.quizManagementRepository,
    required this.themeDraftRepository,
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
  final CurriculumRepository curriculumRepository;
  final QuizRepository quizRepository;
  final QuizManagementRepository quizManagementRepository;
  final ThemeDraftRepository themeDraftRepository;
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
        AppDestination.quiz => StudentQuizScreen(
          repository: quizRepository,
          onNavigate: onNavigate,
          initialQuizId: arguments is String ? arguments as String : null,
        ),
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
          repository: themeDraftRepository,
          initialInspiration: arguments is String ? arguments as String : null,
          initialDraftId: arguments is String && _looksLikeUuid(arguments) ? arguments : null,
          onSubmitted: () => onNavigate(AppDestination.drafts),
        ),
        AppDestination.drafts => StudentDraftsScreen(
          repository: themeDraftRepository,
          onOpenBuilder: (id) => onNavigateWithPayload(AppDestination.themeBuilder, id.isEmpty ? null : id),
        ),
        AppDestination.submissionReview => StudentDraftsScreen(
          repository: themeDraftRepository,
          onOpenBuilder: (id) => onNavigateWithPayload(AppDestination.themeBuilder, id),
        ),
        AppDestination.progress => StudentProgressScreen(
          repository: learningRepository,
          quizRepository: quizRepository,
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
      AppDestination.learningContent => TeacherCurriculumScreen(
        repository: curriculumRepository,
        quizManagementRepository: quizManagementRepository,
      ),
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

bool _looksLikeUuid(String value) => RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
).hasMatch(value);
