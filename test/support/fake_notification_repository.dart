import 'package:ilocano_teatro_master/features/notifications/data/notification_repository.dart';

class FakeNotificationRepository implements NotificationRepository {
  FakeNotificationRepository({List<AppNotification> notifications = const []})
    : notifications = [...notifications];

  final List<AppNotification> notifications;

  @override
  Future<List<AppNotification>> loadNotifications() async => [...notifications];

  @override
  Future<void> markRead(String notificationId, bool isRead) async {
    final index = notifications.indexWhere((item) => item.id == notificationId);
    if (index < 0) return;
    final item = notifications[index];
    notifications[index] = AppNotification(
      id: item.id,
      title: item.title,
      message: item.message,
      type: item.type,
      createdAt: item.createdAt,
      isRead: isRead,
      relatedSubmissionId: item.relatedSubmissionId,
    );
  }

  @override
  Future<void> markAllRead() async {
    for (final item in [...notifications]) {
      await markRead(item.id, true);
    }
  }
}
