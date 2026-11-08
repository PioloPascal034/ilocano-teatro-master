import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/app_routes.dart';
import '../../app/app_theme.dart';
import '../../core/widgets/teatro_widgets.dart';
import '../../core/widgets/teatro_design_widgets.dart';
import 'data/notification_repository.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    required this.role,
    required this.onNavigate,
    this.repository,
    this.onUnreadCountChanged,
    super.key,
  });

  final AppRole role;
  final NotificationRepository? repository;
  final ValueChanged<int>? onUnreadCountChanged;
  final void Function(AppDestination, Object?) onNavigate;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final NotificationRepository _repository;
  late Future<List<AppNotification>> _future;
  String _filter = 'All Notifications';

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ??
        SupabaseNotificationRepository(Supabase.instance.client);
    _future = _repository.loadNotifications();
  }

  void _reload() {
    setState(() {
      _future = _repository.loadNotifications();
    });
  }

  Future<void> _open(AppNotification item) async {
    if (!item.isRead) {
      try {
        await _repository.markRead(item.id, true);
        _reload();
      } catch (error) {
        if (mounted) _showError(error);
        return;
      }
    }

    final submissionId = item.relatedSubmissionId;
    if (submissionId != null) {
      widget.onNavigate(AppDestination.submissionReview, submissionId);
    }
  }

  Future<void> _mark(AppNotification item, bool read) async {
    try {
      await _repository.markRead(item.id, read);
      _reload();
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<void> _markAll() async {
    try {
      await _repository.markAllRead();
      _reload();
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  void _showError(Object error) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Could not update notifications: $error')),
  );

  @override
  Widget build(BuildContext context) => FutureBuilder<List<AppNotification>>(
    future: _future,
    builder: (context, snapshot) {
      final items = snapshot.data ?? const <AppNotification>[];
      final unread = items.where((item) => !item.isRead).length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onUnreadCountChanged?.call(unread);
      });
      final filters = <String>{
        'All Notifications',
        'Unread',
        ...items.map((item) => _labelFor(item.type)),
      }.toList();
      final visible = items.where((item) {
        if (_filter == 'All Notifications') return true;
        if (_filter == 'Unread') return !item.isRead;
        return _labelFor(item.type) == _filter;
      }).toList();
      return TeatroPageBody(
        eyebrow: widget.role == AppRole.student
            ? 'STUDENT UPDATES'
            : 'REVIEWER UPDATES',
        title: 'Notifications${unread > 0 ? '  $unread' : ''}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed:
                    unread == 0 ||
                        snapshot.connectionState == ConnectionState.waiting
                    ? null
                    : _markAll,
                icon: const Icon(Icons.done_all, size: 16),
                label: const Text('Mark all as read'),
              ),
            ),
            if (snapshot.hasError)
              Column(
                children: [
                  const TeatroEmptyState(
                    title: 'Notifications unavailable',
                    description: 'Could not load notifications. Try again.',
                    icon: Icons.cloud_off_outlined,
                  ),
                  TextButton.icon(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              )
            else if (snapshot.connectionState == ConnectionState.waiting)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              _NotificationFilters(
                labels: filters,
                selected: _filter,
                onSelected: (v) => setState(() => _filter = v),
              ),
              const SizedBox(height: 13),
              if (visible.isEmpty)
                const TeatroEmptyState(
                  title: 'No notifications here',
                  description:
                      'Notifications will appear here when there is an update.',
                  icon: Icons.notifications_none_outlined,
                )
              else
                for (final item in visible)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _NotificationCard(
                      item: item,
                      onMark: () => _mark(item, !item.isRead),
                      onOpen: () => _open(item),
                    ),
                  ),
            ],
          ],
        ),
      );
    },
  );
}

String _labelFor(String type) => switch (type) {
  'new_submission' => 'New Submissions',
  'revision_requested' => 'Revisions',
  'approved' => 'Approvals',
  _ =>
    type
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' '),
};

class _NotificationFilters extends StatelessWidget {
  const _NotificationFilters({
    required this.labels,
    required this.selected,
    required this.onSelected,
  });
  final List<String> labels;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (final label in labels)
          Padding(
            padding: const EdgeInsets.only(right: 7),
            child: ChoiceChip(
              label: Text(label),
              selected: label == selected,
              onSelected: (_) => onSelected(label),
            ),
          ),
      ],
    ),
  );
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.item,
    required this.onMark,
    required this.onOpen,
  });
  final AppNotification item;
  final VoidCallback onMark;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onOpen,
    borderRadius: BorderRadius.circular(10),
    child: TeatroCard(
      padding: const EdgeInsets.all(14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 520;
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 3),
              Text(
                item.message,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: TeatroColors.muted),
              ),
              const SizedBox(height: 4),
              Text(
                '${_labelFor(item.type)} · ${_dateLabel(item.createdAt)}',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: TeatroColors.muted),
              ),
              Text(
                item.relatedSubmissionId == null
                    ? 'Tap to mark as read'
                    : 'Open submission',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: TeatroColors.rust),
              ),
            ],
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
              Expanded(child: copy),
              compact
                  ? PopupMenuButton<String>(
                      tooltip: 'Notification actions',
                      onSelected: (_) => onMark(),
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'toggle',
                          child: Text(
                            item.isRead ? 'Mark unread' : 'Mark read',
                          ),
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
    ),
  );
}

String _dateLabel(DateTime date) {
  final local = date.toLocal();
  final now = DateTime.now();
  if (now.difference(local).inDays == 0) {
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    return 'Today, $hour:$minute ${local.hour < 12 ? 'AM' : 'PM'}';
  }
  return '${local.month}/${local.day}/${local.year}';
}
