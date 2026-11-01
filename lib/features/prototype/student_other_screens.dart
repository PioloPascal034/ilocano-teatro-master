import 'package:flutter/material.dart';
import '../../app/app_theme.dart';
import '../../core/widgets/teatro_widgets.dart';
import 'demo_content.dart';
import 'prototype_widgets.dart';

class StudentNotificationsScreen extends StatefulWidget {
  const StudentNotificationsScreen({super.key});

  @override
  State<StudentNotificationsScreen> createState() =>
      _StudentNotificationsScreenState();
}

class _StudentNotificationsScreenState
    extends State<StudentNotificationsScreen> {
  late List<_NoticeState> _items;
  String _filter = 'All Notifications';

  @override
  void initState() {
    super.initState();
    _items = demoStudentNotifications.map(_NoticeState.new).toList();
  }

  List<_NoticeState> get _visible => _items.where((item) {
    if (_filter == 'All Notifications') return true;
    if (_filter == 'Unread') return !item.isRead;
    return item.notification.category == _filter;
  }).toList();

  @override
  Widget build(BuildContext context) {
    final unreadCount = _items.where((item) => !item.isRead).length;
    final filters = [
      'All Notifications',
      'Unread',
      'Submissions',
      'Learning & Reminders',
    ];
    return DemoPageBody(
      eyebrow: 'STUDENT UPDATES',
      title: 'Notifications${unreadCount > 0 ? '  $unreadCount' : ''}',
      child: Column(
        children: [
          const DemoDataNotice(),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => setState(() {
                for (final item in _items) {
                  item.isRead = true;
                }
              }),
              icon: const Icon(Icons.done_all, size: 16),
              label: const Text('Mark all as read'),
            ),
          ),
          DemoFilterTabs(
            labels: filters,
            selected: _filter,
            onSelected: (value) => setState(() => _filter = value),
          ),
          const SizedBox(height: 13),
          if (_visible.isEmpty)
            const DemoEmptyState(
              title: 'No notifications here',
              description:
                  'There are no sample notifications matching this filter.',
              icon: Icons.notifications_none_outlined,
            )
          else
            for (final item in _visible)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _NotificationRow(
                  item: item,
                  onOpen: () => setState(() => item.isRead = true),
                  onMark: () => setState(() => item.isRead = !item.isRead),
                ),
              ),
        ],
      ),
    );
  }
}

class _NoticeState {
  _NoticeState(this.notification) : isRead = notification.isRead;
  final DemoNotification notification;
  bool isRead;
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({
    required this.item,
    required this.onOpen,
    required this.onMark,
  });
  final _NoticeState item;
  final VoidCallback onOpen;
  final VoidCallback onMark;

  @override
  Widget build(BuildContext context) => TeatroCard(
    padding: const EdgeInsets.all(14),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        final copy = Expanded(
          child: InkWell(
            onTap: onOpen,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.notification.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 3),
                Text(
                  item.notification.detail,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: TeatroColors.muted),
                ),
                const SizedBox(height: 4),
                Text(
                  item.notification.dateLabel,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: TeatroColors.muted),
                ),
              ],
            ),
          ),
        );
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              item.isRead
                  ? Icons.notifications_none_outlined
                  : Icons.notifications_active_outlined,
              color: item.isRead ? TeatroColors.muted : TeatroColors.success,
              size: 21,
            ),
            const SizedBox(width: 11),
            copy,
            const SizedBox(width: 5),
            compact
                ? PopupMenuButton<String>(
                    tooltip: 'Notification actions',
                    onSelected: (_) => onMark(),
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'read',
                        child: Text(item.isRead ? 'Mark unread' : 'Mark read'),
                      ),
                    ],
                  )
                : TextButton(
                    onPressed: onMark,
                    child: Text(item.isRead ? 'Mark unread' : 'Mark read'),
                  ),
          ],
        );
      },
    ),
  );
}
