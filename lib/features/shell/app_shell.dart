import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/app_routes.dart';
import '../../app/app_theme.dart';
import '../../core/widgets/teatro_widgets.dart';
import '../dashboard/data/student_dashboard_data_source.dart';
import '../dashboard/student_dashboard.dart';
import '../learning/data/student_learning_repository.dart';
import '../profile/user_profile.dart';
import '../profile/user_profile_repository.dart';
import '../profile/profile_avatar.dart';
import '../teacher/data/teacher_student_progress_repository.dart';
import '../teacher/data/curriculum_repository.dart';
import '../teacher/data/teacher_review_repository.dart';
import '../quiz/data/quiz_repository.dart';
import '../quiz/data/quiz_management_repository.dart';
import '../drafts/data/theme_draft_repository.dart';
import 'destination_screen.dart';
import '../notifications/data/notification_repository.dart';
import '../story_vault/data/story_vault_repository.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    required this.role,
    this.initialDestination = AppDestination.dashboard,
    this.dashboardDataSource,
    this.learningRepository,
    this.profileRepository,
    this.teacherProgressRepository,
    this.curriculumRepository,
    this.quizRepository,
    this.quizManagementRepository,
    this.themeDraftRepository,
    this.teacherReviewRepository,
    this.notificationRepository,
    this.storyVaultRepository,
    super.key,
  });

  final AppRole role;
  final AppDestination initialDestination;
  final StudentDashboardDataSource? dashboardDataSource;
  final StudentLearningRepository? learningRepository;
  final UserProfileRepository? profileRepository;
  final TeacherStudentProgressRepository? teacherProgressRepository;
  final CurriculumRepository? curriculumRepository;
  final QuizRepository? quizRepository;
  final QuizManagementRepository? quizManagementRepository;
  final ThemeDraftRepository? themeDraftRepository;
  final TeacherReviewRepository? teacherReviewRepository;
  final NotificationRepository? notificationRepository;
  final StoryVaultRepository? storyVaultRepository;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late AppDestination _destination = widget.initialDestination;
  Object? _destinationArguments;
  late StudentLearningRepository _learningRepository;
  late UserProfileRepository _profileRepository;
  late TeacherStudentProgressRepository _teacherProgressRepository;
  late CurriculumRepository _curriculumRepository;
  late QuizRepository _quizRepository;
  late QuizManagementRepository _quizManagementRepository;
  late ThemeDraftRepository _themeDraftRepository;
  late TeacherReviewRepository _teacherReviewRepository;
  NotificationRepository? _notificationRepository;
  late StoryVaultRepository _storyVaultRepository;
  UserProfile? _profile;
  int _unreadNotificationCount = 0;

  @override
  void initState() {
    super.initState();
    _learningRepository =
        widget.learningRepository ?? SupabaseStudentLearningRepository();
    _profileRepository =
        widget.profileRepository ?? SupabaseUserProfileRepository();
    _teacherProgressRepository =
        widget.teacherProgressRepository ??
        SupabaseTeacherStudentProgressRepository();
    _curriculumRepository =
        widget.curriculumRepository ?? SupabaseCurriculumRepository();
    _quizRepository = widget.quizRepository ?? SupabaseQuizRepository();
    _quizManagementRepository =
        widget.quizManagementRepository ?? SupabaseQuizManagementRepository();
    _themeDraftRepository =
        widget.themeDraftRepository ?? SupabaseThemeDraftRepository();
    _teacherReviewRepository =
        widget.teacherReviewRepository ?? SupabaseTeacherReviewRepository();
    _storyVaultRepository =
        widget.storyVaultRepository ?? SupabaseStoryVaultRepository();
    _notificationRepository = widget.notificationRepository;
    if (_notificationRepository == null) {
      try {
        _notificationRepository = SupabaseNotificationRepository(
          Supabase.instance.client,
        );
      } catch (_) {
        // Tests and pre-auth UI may render before Supabase is initialized.
      }
    }
    _loadUnreadNotificationCount();
    _loadProfile();
  }

  Future<void> _loadUnreadNotificationCount() async {
    final repository = _notificationRepository;
    if (repository == null) return;
    try {
      final items = await repository.loadNotifications();
      if (mounted) {
        setState(() {
          _unreadNotificationCount = items.where((item) => !item.isRead).length;
        });
      }
    } catch (_) {
      // The notification screen shows a retry action for load failures.
    }
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _profileRepository.loadCurrentProfile();
      if (mounted) setState(() => _profile = profile);
    } catch (_) {
      // The profile screen provides a retry state when the record is unavailable.
    }
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    setState(() {
      _profile = null;
      _unreadNotificationCount = 0;
      _destination = AppDestination.dashboard;
      _destinationArguments = null;
    });
  }

  List<AppDestination> get _primaryDestinations =>
      widget.role == AppRole.student
      ? const [
          AppDestination.learning,
          AppDestination.storyVault,
          AppDestination.themeBuilder,
          AppDestination.drafts,
        ]
      : const [
          AppDestination.dashboard,
          AppDestination.reviewQueue,
          AppDestination.studentProgress,
          AppDestination.storyVault,
        ];

  List<AppDestination> get _allDestinations => widget.role == AppRole.student
      ? const [
          AppDestination.dashboard,
          AppDestination.learning,
          AppDestination.storyVault,
          AppDestination.themeBuilder,
          AppDestination.drafts,
          AppDestination.progress,
          AppDestination.notifications,
          AppDestination.profile,
        ]
      : const [
          AppDestination.dashboard,
          AppDestination.reviewQueue,
          AppDestination.studentProgress,
          AppDestination.learningContent,
          AppDestination.storyVault,
          AppDestination.notifications,
          AppDestination.profile,
        ];

  AppDestination get _selectedNavigationDestination => switch (_destination) {
    AppDestination.moduleOverview ||
    AppDestination.lesson ||
    AppDestination.quiz => AppDestination.learning,
    AppDestination.storyDetail ||
    AppDestination.storyChapter ||
    AppDestination.storyEditor ||
    AppDestination.storyChapterEditor => AppDestination.storyVault,
    AppDestination.submissionReview =>
      widget.role == AppRole.teacher
          ? AppDestination.reviewQueue
          : AppDestination.drafts,
    _ => _destination,
  };

  void _navigate(AppDestination destination, {Object? arguments}) {
    final detailDestinations = widget.role == AppRole.student
        ? const {
            AppDestination.moduleOverview,
            AppDestination.lesson,
            AppDestination.quiz,
            AppDestination.storyDetail,
            AppDestination.storyChapter,
            AppDestination.submissionReview,
          }
        : const {
            AppDestination.submissionReview,
            AppDestination.storyDetail,
            AppDestination.storyChapter,
            AppDestination.storyEditor,
            AppDestination.storyChapterEditor,
          };
    if (!_allDestinations.contains(destination) &&
        !detailDestinations.contains(destination)) {
      return;
    }
    if (destination == _destination && arguments == _destinationArguments) {
      return;
    }
    setState(() {
      _destination = destination;
      _destinationArguments = arguments;
    });
  }

  Future<void> _openMore() async {
    final remaining = _allDestinations
        .where((item) => !_primaryDestinations.contains(item))
        .toList();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: TeatroColors.paper,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('More', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
              ...remaining.map(
                (item) => ListTile(
                  leading: Icon(
                    _iconFor(item.iconName),
                    color: TeatroColors.muted,
                  ),
                  title: Text(item.label),
                  selected: item == _selectedNavigationDestination,
                  selectedColor: TeatroColors.rust,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _navigate(item);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth <= 700;
        final sidebarWidth = constraints.maxWidth <= 1050 ? 214.0 : 248.0;
        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: Row(
              children: [
                if (!mobile)
                  _DesktopSidebar(
                    width: sidebarWidth,
                    role: widget.role,
                    profile: _profile,
                    selected: _selectedNavigationDestination,
                    onSelect: _navigate,
                    unreadNotificationCount: _unreadNotificationCount,
                  ),
                Expanded(
                  child: Column(
                    children: [
                      _TopBar(
                        role: widget.role,
                        profile: _profile,
                        destination: _destination,
                        compact: mobile,
                        onSelect: _navigate,
                        unreadNotificationCount: _unreadNotificationCount,
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(
                            mobile ? 20 : constraints.maxWidth * .055,
                            mobile ? 22 : 28,
                            mobile ? 20 : constraints.maxWidth * .055,
                            34,
                          ),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1320),
                              child: _destinationPage(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: mobile
              ? _MobileNavigation(
                  role: widget.role,
                  primaryDestinations: _primaryDestinations,
                  selected: _selectedNavigationDestination,
                  onSelect: _navigate,
                  onMore: _openMore,
                )
              : null,
        );
      },
    );
  }

  Widget _destinationPage() {
    if (widget.role == AppRole.student &&
        _destination == AppDestination.dashboard) {
      return StudentDashboard(
        onNavigate: _navigate,
        dataSource:
            widget.dashboardDataSource ??
            SupabaseStudentDashboardDataSource(
              draftRepository: _themeDraftRepository,
            ),
        profile: _profile,
      );
    }
    return DestinationScreen(
      role: widget.role,
      destination: _destination,
      arguments: _destinationArguments,
      learningRepository: _learningRepository,
      profileRepository: _profileRepository,
      teacherProgressRepository: _teacherProgressRepository,
      curriculumRepository: _curriculumRepository,
      quizRepository: _quizRepository,
      quizManagementRepository: _quizManagementRepository,
      themeDraftRepository: _themeDraftRepository,
      teacherReviewRepository: _teacherReviewRepository,
      notificationRepository: _notificationRepository,
      storyVaultRepository: _storyVaultRepository,
      onUnreadNotificationCountChanged: (count) {
        if (_unreadNotificationCount != count) {
          setState(() => _unreadNotificationCount = count);
        }
      },
      profile: _profile,
      onProfileUpdated: (profile) => setState(() => _profile = profile),
      onNavigate: _navigate,
      onNavigateWithPayload: (destination, arguments) =>
          _navigate(destination, arguments: arguments),
      onSignOut: _signOut,
    );
  }
}

class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({
    required this.width,
    required this.role,
    required this.profile,
    required this.selected,
    required this.onSelect,
    required this.unreadNotificationCount,
  });

  final double width;
  final AppRole role;
  final UserProfile? profile;
  final AppDestination selected;
  final ValueChanged<AppDestination> onSelect;
  final int unreadNotificationCount;

  List<AppDestination> get _mainItems => role == AppRole.student
      ? const [
          AppDestination.dashboard,
          AppDestination.learning,
          AppDestination.storyVault,
          AppDestination.themeBuilder,
          AppDestination.drafts,
          AppDestination.progress,
        ]
      : const [
          AppDestination.dashboard,
          AppDestination.reviewQueue,
          AppDestination.studentProgress,
          AppDestination.learningContent,
          AppDestination.storyVault,
        ];

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: double.infinity,
    padding: const EdgeInsets.fromLTRB(14, 26, 14, 14),
    decoration: const BoxDecoration(
      color: TeatroColors.paper,
      border: Border(right: BorderSide(color: TeatroColors.line)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _BrandMark(),
        const SizedBox(height: 25),
        ..._mainItems.map(
          (item) => _NavigationItem(
            destination: item,
            selected: selected == item,
            onTap: () => onSelect(item),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 16),
          child: Divider(),
        ),
        _NavigationItem(
          destination: AppDestination.notifications,
          selected: selected == AppDestination.notifications,
          onTap: () => onSelect(AppDestination.notifications),
          unreadCount: unreadNotificationCount,
        ),
        _NavigationItem(
          destination: AppDestination.profile,
          selected: selected == AppDestination.profile,
          onTap: () => onSelect(AppDestination.profile),
        ),
        const Spacer(),
        const Divider(),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          leading: _UserAvatar(
            size: 32,
            profile: profile,
            onTap: () => onSelect(AppDestination.profile),
          ),
          title: Text(
            profile?.fullName.trim().isNotEmpty == true
                ? profile!.fullName
                : 'Account',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          subtitle: Text(
            profile?.email.isNotEmpty == true
                ? profile!.email
                : role == AppRole.student
                ? 'Student'
                : 'Teacher / Reviewer',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: TeatroColors.muted),
          ),
          dense: true,
        ),
      ],
    ),
  );
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.role,
    required this.profile,
    required this.destination,
    required this.compact,
    required this.onSelect,
    required this.unreadNotificationCount,
  });

  final AppRole role;
  final UserProfile? profile;
  final AppDestination destination;
  final bool compact;
  final ValueChanged<AppDestination> onSelect;
  final int unreadNotificationCount;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 82),
    padding: EdgeInsets.symmetric(
      horizontal: compact ? 20 : 44,
      vertical: compact ? 14 : 20,
    ),
    decoration: const BoxDecoration(
      color: TeatroColors.paper,
      border: Border(bottom: BorderSide(color: TeatroColors.line)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TeatroEyebrow(
                role == AppRole.student
                    ? 'Student space'
                    : 'Teacher / Reviewer space',
              ),
              const SizedBox(height: 4),
              Text(
                _pageTitle(destination),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
        ),
        if (!compact) ...[
          TextButton(
            onPressed: () => onSelect(AppDestination.notifications),
            child: const Text('Need help?'),
          ),
          const SizedBox(width: 8),
        ],
        IconButton(
          tooltip: 'Notifications',
          onPressed: () => onSelect(AppDestination.notifications),
          icon: Badge(
            isLabelVisible: unreadNotificationCount > 0,
            label: Text(
              unreadNotificationCount > 99 ? '99+' : '$unreadNotificationCount',
            ),
            child: const Icon(Icons.notifications_none_outlined),
          ),
        ),
        const SizedBox(width: 7),
        _UserAvatar(
          size: 34,
          profile: profile,
          onTap: () => onSelect(AppDestination.profile),
        ),
      ],
    ),
  );
}

class _MobileNavigation extends StatelessWidget {
  const _MobileNavigation({
    required this.role,
    required this.primaryDestinations,
    required this.selected,
    required this.onSelect,
    required this.onMore,
  });

  final AppRole role;
  final List<AppDestination> primaryDestinations;
  final AppDestination selected;
  final ValueChanged<AppDestination> onSelect;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: TeatroColors.paper,
      border: Border(top: BorderSide(color: TeatroColors.line)),
    ),
    child: SafeArea(
      top: false,
      child: SizedBox(
        height: 61,
        child: Row(
          children: [
            ...primaryDestinations.map(
              (item) => Expanded(
                child: _MobileNavItem(
                  destination: item,
                  label: _mobileLabel(role, item),
                  selected: selected == item,
                  onTap: () => onSelect(item),
                ),
              ),
            ),
            Expanded(
              child: _MobileNavItem(
                destination: AppDestination.profile,
                label: 'More',
                selected: !primaryDestinations.contains(selected),
                icon: Icons.more_horiz,
                onTap: onMore,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _MobileNavItem extends StatelessWidget {
  const _MobileNavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
    this.label,
    this.icon,
  });

  final AppDestination destination;
  final bool selected;
  final VoidCallback onTap;
  final String? label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final color = selected ? TeatroColors.rust : TeatroColors.muted;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon ?? _iconFor(destination.iconName), size: 20, color: color),
          const SizedBox(height: 3),
          Text(
            label ?? destination.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontSize: 9,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.destination,
    required this.selected,
    required this.onTap,
    this.unreadCount = 0,
  });

  final AppDestination destination;
  final bool selected;
  final VoidCallback onTap;
  final int unreadCount;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: Material(
      color: selected ? const Color(0xFFF2EEE5) : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              Icon(
                _iconFor(destination.iconName),
                size: 19,
                color: selected ? TeatroColors.rust : TeatroColors.muted,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Text(
                  destination.label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: selected ? TeatroColors.rust : TeatroColors.muted,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
              if (destination == AppDestination.notifications &&
                  unreadCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: TeatroColors.rust,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$unreadCount',
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10),
    child: Row(
      children: [
        Image.asset(
          'assets/branding/applogo.png',
          width: 34,
          height: 34,
          fit: BoxFit.contain,
          semanticLabel: 'Ilocano Teatro Master logo',
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Ilocano\n'),
                TextSpan(
                  text: 'Teatro Master',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(height: 1.05),
          ),
        ),
      ],
    ),
  );
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({required this.size, required this.onTap, this.profile});

  final double size;
  final UserProfile? profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: profile?.avatarLoadError == null
        ? 'Open profile and account settings'
        : 'Open profile. The saved photo could not be loaded.',
    child: Tooltip(
      message: 'Open Profile',
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: ProfileAvatar(profile: profile, size: size),
            ),
          ),
        ),
      ),
    ),
  );
}

String _pageTitle(AppDestination destination) => switch (destination) {
  AppDestination.dashboard => 'Dashboard',
  AppDestination.learning => 'My learning',
  AppDestination.moduleOverview => 'Module overview',
  AppDestination.lesson => 'Lesson room',
  AppDestination.quiz => 'Knowledge check',
  AppDestination.storyVault => 'Story vault',
  AppDestination.storyDetail => 'Story details',
  AppDestination.storyChapter => 'Chapter reader',
  AppDestination.storyEditor => 'Story editor',
  AppDestination.storyChapterEditor => 'Chapter editor',
  AppDestination.themeBuilder => 'Theme builder',
  AppDestination.drafts => 'My drafts',
  AppDestination.progress => 'My progress',
  AppDestination.reviewQueue => 'Review queue',
  AppDestination.submissionReview => 'Submission review',
  AppDestination.studentProgress => 'Student progress',
  AppDestination.learningContent => 'Learning content',
  AppDestination.notifications => 'Notifications',
  AppDestination.profile => 'Account',
};

String _mobileLabel(AppRole role, AppDestination destination) {
  if (role == AppRole.student) {
    return switch (destination) {
      AppDestination.learning => 'Learn',
      AppDestination.storyVault => 'Vault',
      AppDestination.themeBuilder => 'Build',
      AppDestination.drafts => 'Drafts',
      _ => destination.label,
    };
  }
  return switch (destination) {
    AppDestination.dashboard => 'Home',
    AppDestination.reviewQueue => 'Reviews',
    AppDestination.studentProgress => 'Students',
    _ => destination.label,
  };
}

IconData _iconFor(String name) => switch (name) {
  'grid' => Icons.grid_view_rounded,
  'learn' => Icons.school_outlined,
  'book' => Icons.menu_book_outlined,
  'edit' => Icons.edit_note_outlined,
  'file' => Icons.description_outlined,
  'chart' => Icons.bar_chart_rounded,
  'inbox' => Icons.inbox_outlined,
  'people' => Icons.groups_2_outlined,
  'bell' => Icons.notifications_none_outlined,
  'person' => Icons.person_outline_rounded,
  _ => Icons.circle_outlined,
};
