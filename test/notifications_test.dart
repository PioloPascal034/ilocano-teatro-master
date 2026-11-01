import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilocano_teatro_master/app/app_routes.dart';
import 'package:ilocano_teatro_master/app/app_theme.dart';
import 'package:ilocano_teatro_master/features/drafts/data/theme_draft_repository.dart';
import 'package:ilocano_teatro_master/features/drafts/theme_draft_screens.dart';
import 'package:ilocano_teatro_master/features/notifications/data/notification_repository.dart';
import 'package:ilocano_teatro_master/features/notifications/notifications_screen.dart';
import 'support/fake_notification_repository.dart';
import 'support/fake_theme_draft_repository.dart';

void main() {
  final now = DateTime.now();
  testWidgets('loads actual repository items, count, filter and mark read', (
    tester,
  ) async {
    final repository = FakeNotificationRepository(
      notifications: [
        AppNotification(
          id: 'a',
          title: 'Approved theme',
          message: 'Well done',
          type: 'approved',
          createdAt: now,
          isRead: false,
          relatedSubmissionId: 'submission-1',
        ),
        AppNotification(
          id: 'b',
          title: 'New theme submission',
          message: 'Review requested',
          type: 'new_submission',
          createdAt: now,
          isRead: true,
        ),
      ],
    );
    var destination = AppDestination.dashboard;
    Object? payload;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: NotificationsScreen(
            role: AppRole.student,
            repository: repository,
            onNavigate: (next, value) {
              destination = next;
              payload = value;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Notifications  1'), findsOneWidget);
    expect(find.text('Approved theme'), findsOneWidget);
    await tester.tap(find.text('Approvals'));
    await tester.pumpAndSettle();
    expect(find.text('New theme submission'), findsNothing);
    await tester.tap(find.text('Open submission'));
    await tester.pumpAndSettle();
    expect(destination, AppDestination.submissionReview);
    expect(payload, 'submission-1');
    expect(repository.notifications.first.isRead, isTrue);
  });

  testWidgets('mark all as read persists and empty result has no fake rows', (
    tester,
  ) async {
    final repository = FakeNotificationRepository(
      notifications: [
        AppNotification(
          id: 'a',
          title: 'Revision requested',
          message: 'Please revise',
          type: 'revision_requested',
          createdAt: now,
          isRead: false,
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: NotificationsScreen(
            role: AppRole.teacher,
            repository: repository,
            onNavigate: (_, _) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark all as read'));
    await tester.pumpAndSettle();
    expect(repository.notifications.single.isRead, isTrue);
    expect(repository.notifications.single.isRead, isTrue);
  });

  testWidgets('notification screen fits narrow mobile width', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: NotificationsScreen(
            role: AppRole.student,
            repository: FakeNotificationRepository(),
            onNavigate: (_, _) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('No notifications here'), findsOneWidget);
  });

  testWidgets('notification submission id opens its draft feedback history', (
    tester,
  ) async {
    final drafts = FakeThemeDraftRepository();
    final saved = await drafts.saveDraft(
      ThemeDraft(
        id: '',
        title: 'Test submission theme',
        status: 'draft',
        updatedAt: now,
      ),
    );
    await drafts.submitDraft(saved.id);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: StudentDraftsScreen(
              repository: drafts,
              onOpenBuilder: (_) {},
              focusSubmissionId: 'submission-1',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Submission history'), findsOneWidget);
    expect(find.textContaining('Version 1'), findsOneWidget);
  });
}
