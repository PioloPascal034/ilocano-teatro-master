import 'package:flutter/material.dart';
import '../../app/app_routes.dart';
import '../../app/app_theme.dart';
import '../../core/widgets/teatro_widgets.dart';
import 'demo_content.dart';
import 'prototype_widgets.dart';

class StudentProgressScreen extends StatelessWidget {
  const StudentProgressScreen({required this.onNavigate, super.key});
  final ValueChanged<AppDestination> onNavigate;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: TeatroColors.dark,
          borderRadius: BorderRadius.circular(13),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 560;
            final copy = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TeatroEyebrow(
                  'YOUR LEARNING JOURNEY',
                  color: Color(0xFFD4D9D1),
                ),
                const SizedBox(height: 8),
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'Small steps make\n'),
                      TextSpan(
                        text: 'great stories.',
                        style: const TextStyle(
                          color: Color(0xFFE5BD57),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                  style: Theme.of(
                    context,
                  ).textTheme.displayMedium?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 7),
                Text(
                  'This example shows how learning progress will be presented.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFFD4DCD4),
                  ),
                ),
              ],
            );
            final percent = Column(
              children: [
                Container(
                  width: 104,
                  height: 104,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFE5BD57),
                      width: 5,
                    ),
                  ),
                  child: Text(
                    '30%',
                    style: Theme.of(
                      context,
                    ).textTheme.headlineLarge?.copyWith(color: Colors.white),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'sample completion',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFFD4DCD4),
                  ),
                ),
              ],
            );
            return compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [copy, const SizedBox(height: 20), percent],
                  )
                : Row(
                    children: [
                      Expanded(child: copy),
                      const SizedBox(width: 24),
                      percent,
                    ],
                  );
          },
        ),
      ),
      const SizedBox(height: 20),
      const DemoDataNotice(),
      const SizedBox(height: 2),
      Wrap(
        spacing: 13,
        runSpacing: 13,
        children: const [
          _ProgressStat(
            value: '6',
            label: 'Lessons completed',
            tone: TeatroColors.rust,
            icon: Icons.check,
          ),
          _ProgressStat(
            value: '82%',
            label: 'Average quiz score',
            tone: TeatroColors.blue,
            icon: Icons.auto_awesome_outlined,
          ),
          _ProgressStat(
            value: '1',
            label: 'Modules completed',
            tone: TeatroColors.moss,
            icon: Icons.theater_comedy_outlined,
          ),
        ],
      ),
      const SizedBox(height: 34),
      const DemoSectionTitle(
        eyebrow: 'MODULE PROGRESS',
        title: 'Keep your path in view',
      ),
      const SizedBox(height: 12),
      for (var i = 0; i < demoModules.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: _ModuleProgressRow(
            module: demoModules[i],
            percentage: const [75, 25, 0, 0, 0][i],
            onOpen: () => onNavigate(AppDestination.moduleOverview),
          ),
        ),
    ],
  );
}

class _ProgressStat extends StatelessWidget {
  const _ProgressStat({
    required this.value,
    required this.label,
    required this.tone,
    required this.icon,
  });
  final String value;
  final String label;
  final Color tone;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 220,
    child: TeatroCard(
      padding: const EdgeInsets.all(17),
      child: Row(
        children: [
          Icon(icon, color: tone),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: Theme.of(context).textTheme.headlineMedium),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: TeatroColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _ModuleProgressRow extends StatelessWidget {
  const _ModuleProgressRow({
    required this.module,
    required this.percentage,
    required this.onOpen,
  });
  final DemoModule module;
  final int percentage;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => TeatroCard(
    padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 13),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 640;
        final icon = Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: _tone(module.tone).withValues(alpha: .13),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.theater_comedy_outlined, color: _tone(module.tone)),
        );
        final title = Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TeatroEyebrow(
                'MODULE ${module.number.toString().padLeft(2, '0')}',
              ),
              Text(
                module.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        );
        final progress = SizedBox(
          width: compact ? double.infinity : 180,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(
                value: percentage / 100,
                minHeight: 5,
                color: _tone(module.tone),
                backgroundColor: TeatroColors.line,
              ),
              const SizedBox(height: 5),
              Text(
                percentage == 0
                    ? 'Not started · sample'
                    : '$percentage% complete · sample',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: TeatroColors.muted),
              ),
            ],
          ),
        );
        return compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      icon,
                      const SizedBox(width: 11),
                      title,
                      IconButton(
                        onPressed: onOpen,
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  progress,
                ],
              )
            : Row(
                children: [
                  icon,
                  const SizedBox(width: 12),
                  title,
                  const SizedBox(width: 16),
                  progress,
                  IconButton(
                    onPressed: onOpen,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              );
      },
    ),
  );
}

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

Color _tone(String name) => switch (name) {
  'rust' => const Color(0xFFB6512D),
  'blue' => const Color(0xFF668B97),
  'moss' => const Color(0xFF74835D),
  'plum' => const Color(0xFF876076),
  _ => const Color(0xFFB58A22),
};
