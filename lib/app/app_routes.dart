import 'package:flutter/material.dart';

import '../features/shell/app_shell.dart';

enum AppRole { student, teacher }

enum AppDestination {
  dashboard('/dashboard', 'Dashboard', 'grid'),
  learning('/learning', 'My Learning', 'learn'),
  moduleOverview('/module', 'Module overview', 'book'),
  lesson('/lesson', 'Lesson room', 'book'),
  quiz('/quiz', 'Knowledge check', 'check'),
  storyVault('/story-vault', 'Story Vault', 'book'),
  storyDetail('/story', 'Story details', 'book'),
  storyChapter('/story-chapter', 'Chapter reader', 'book'),
  storyEditor('/story-editor', 'Story editor', 'edit'),
  storyChapterEditor('/story-chapter-editor', 'Chapter editor', 'edit'),
  themeBuilder('/theme-builder', 'Theme Builder', 'edit'),
  drafts('/drafts', 'My Drafts', 'file'),
  progress('/progress', 'My Progress', 'chart'),
  reviewQueue('/review-queue', 'Review Queue', 'inbox'),
  submissionReview('/submission', 'Submission review', 'file'),
  studentProgress('/student-progress', 'Student Progress', 'people'),
  learningContent('/learning-content', 'Learning Content', 'book'),
  notifications('/notifications', 'Notifications', 'bell'),
  profile('/profile', 'Profile', 'person');

  const AppDestination(this.path, this.label, this.iconName);

  final String path;
  final String label;
  final String iconName;

  static AppDestination? fromPath(String? path) {
    if (path == null) return null;
    final segments = Uri.tryParse(path)?.pathSegments;
    if (segments == null || segments.isEmpty) return null;
    final basePath = '/${segments.first}';
    for (final destination in AppDestination.values) {
      if (destination.path == basePath) return destination;
    }
    return null;
  }
}

abstract final class AppRoutes {
  static const signIn = '/sign-in';
  static const signUp = '/sign-up';
  static const forgotPassword = '/forgot-password';

  static String forDestination(AppDestination destination) => destination.path;
  static String module(String moduleId) =>
      '/module/${Uri.encodeComponent(moduleId)}';
  static String lesson(String lessonId) =>
      '/lesson/${Uri.encodeComponent(lessonId)}';
  static String quiz(String quizId) => '/quiz/${Uri.encodeComponent(quizId)}';
  static String story(String storyId) =>
      '/story/${Uri.encodeComponent(storyId)}';
  static String submission(String submissionId) =>
      '/submission/${Uri.encodeComponent(submissionId)}';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final destination = AppDestination.fromPath(settings.name);
    final arguments = settings.arguments;
    if (destination == null || arguments is! AppRole) {
      return PageRouteBuilder<void>(
        settings: settings,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (context, animation, secondaryAnimation) => const Scaffold(
          body: Center(child: Text('This page is not available.')),
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            child,
      );
    }
    return PageRouteBuilder<void>(
      settings: settings,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (context, animation, secondaryAnimation) =>
          AppShell(role: arguments, initialDestination: destination),
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          child,
    );
  }
}
