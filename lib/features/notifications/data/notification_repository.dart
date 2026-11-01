import 'package:supabase_flutter/supabase_flutter.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    required this.isRead,
    this.relatedSubmissionId,
  });

  final String id;
  final String title;
  final String message;
  final String type;
  final DateTime createdAt;
  final bool isRead;
  final String? relatedSubmissionId;

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['notification_id'] as String,
        title: json['title'] as String? ?? '',
        message: json['message'] as String? ?? '',
        type: json['notification_type'] as String? ?? 'general',
        createdAt: DateTime.parse(json['created_at'] as String),
        isRead: json['is_read'] as bool? ?? false,
        relatedSubmissionId: json['related_submission_id'] as String?,
      );
}

abstract interface class NotificationRepository {
  Future<List<AppNotification>> loadNotifications();
  Future<void> markRead(String notificationId, bool isRead);
  Future<void> markAllRead();
}

class SupabaseNotificationRepository implements NotificationRepository {
  SupabaseNotificationRepository(this.client);

  final SupabaseClient client;

  @override
  Future<List<AppNotification>> loadNotifications() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw StateError('Sign in to view notifications.');
    final rows = await client
        .from('notifications')
        .select(
          'notification_id,user_id,title,message,notification_type,related_submission_id,is_read,created_at',
        )
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((row) => AppNotification.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> markRead(String notificationId, bool isRead) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw StateError('Sign in to update notifications.');
    await client
        .from('notifications')
        .update({'is_read': isRead})
        .eq('notification_id', notificationId)
        .eq('user_id', userId);
  }

  @override
  Future<void> markAllRead() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw StateError('Sign in to update notifications.');
    await client
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false);
  }
}
