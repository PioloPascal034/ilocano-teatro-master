import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../core/widgets/teatro_widgets.dart';

class DemoPageIntro extends StatelessWidget {
  const DemoPageIntro({
    required this.eyebrow,
    required this.title,
    this.description,
    this.action,
    this.trailing,
    super.key,
  });

  final String eyebrow;
  final String title;
  final String? description;
  final Widget? action;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 22),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TeatroEyebrow(eyebrow, color: TeatroColors.rust),
              const SizedBox(height: 5),
              Text(title, style: Theme.of(context).textTheme.displayMedium),
              if (description != null) ...[
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Text(
                    description!,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: TeatroColors.muted),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
      ],
    ),
  );
}

class DemoDataNotice extends StatelessWidget {
  const DemoDataNotice({super.key});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFFF4EEE0),
      border: Border.all(color: const Color(0xFFE8DDBF)),
      borderRadius: BorderRadius.circular(7),
    ),
    child: Row(
      children: [
        const Icon(Icons.science_outlined, size: 16, color: TeatroColors.rust),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'DEMO DATA · Actions and sample records on this screen are not saved to Supabase.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: TeatroColors.ink),
          ),
        ),
      ],
    ),
  );
}

class DemoPageBody extends StatelessWidget {
  const DemoPageBody({
    required this.eyebrow,
    required this.title,
    this.description,
    required this.child,
    this.action,
    super.key,
  });

  final String eyebrow;
  final String title;
  final String? description;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      DemoPageIntro(
        eyebrow: eyebrow,
        title: title,
        description: description,
        trailing: action,
      ),
      const DemoDataNotice(),
      child,
    ],
  );
}

class DemoSectionTitle extends StatelessWidget {
  const DemoSectionTitle({
    required this.title,
    this.eyebrow,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String? eyebrow;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow != null) ...[
                TeatroEyebrow(eyebrow!),
                const SizedBox(height: 4),
              ],
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
            ],
          ),
        ),
        if (actionLabel != null)
          TextButton.icon(
            onPressed: onAction,
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.arrow_forward, size: 16),
            label: Text(actionLabel!),
            style: TextButton.styleFrom(foregroundColor: TeatroColors.ink),
          ),
      ],
    ),
  );
}

class DemoFilterTabs extends StatelessWidget {
  const DemoFilterTabs({
    required this.labels,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final List<String> labels;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: labels
          .map(
            (label) => Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(label),
                selected: label == selected,
                onSelected: (_) => onSelected(label),
                showCheckmark: false,
                backgroundColor: TeatroColors.paper,
                selectedColor: const Color(0xFFF2EEE5),
                side: BorderSide(
                  color: label == selected
                      ? const Color(0xFFD9CFC0)
                      : TeatroColors.line,
                ),
                labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: label == selected
                      ? TeatroColors.rust
                      : TeatroColors.muted,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
            ),
          )
          .toList(),
    ),
  );
}

class DemoSearchField extends StatelessWidget {
  const DemoSearchField({
    required this.controller,
    required this.hint,
    this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    onChanged: onChanged,
    decoration: InputDecoration(
      hintText: hint,
      prefixIcon: const Icon(Icons.search, size: 19),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
    ),
  );
}

class DemoEmptyState extends StatelessWidget {
  const DemoEmptyState({
    required this.title,
    required this.description,
    this.icon = Icons.auto_stories_outlined,
    super.key,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) => TeatroCard(
    child: Column(
      children: [
        Icon(icon, color: TeatroColors.muted, size: 28),
        const SizedBox(height: 10),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 5),
        Text(
          description,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: TeatroColors.muted),
        ),
      ],
    ),
  );
}

class DemoBackButton extends StatelessWidget {
  const DemoBackButton({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.arrow_back, size: 16),
      label: Text(label),
      style: TextButton.styleFrom(foregroundColor: TeatroColors.muted),
    ),
  );
}

class DemoStatus extends StatelessWidget {
  const DemoStatus({required this.status, super.key});

  final String status;

  @override
  Widget build(BuildContext context) => TeatroStatusIndicator(
    label: status,
    tone: switch (status.toLowerCase().replaceAll(' ', '_')) {
      'approved' || 'on_track' => TeatroStatusTone.approved,
      'revision_requested' || 'needs_support' => TeatroStatusTone.revision,
      'submitted' || 'under_review' || 'pending' => TeatroStatusTone.pending,
      _ => TeatroStatusTone.neutral,
    },
  );
}

void showDemoMessage(BuildContext context, String action) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text('Demo only: $action. Nothing was saved to Supabase.'),
      ),
    );
}

class DemoPrimaryButton extends StatelessWidget {
  const DemoPrimaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.fullWidth = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final button = FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon ?? Icons.arrow_forward, size: 16),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFFEBBC4B),
        foregroundColor: TeatroColors.dark,
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        textStyle: Theme.of(context).textTheme.labelLarge,
      ),
    );
    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class DemoActionButton extends StatelessWidget {
  const DemoActionButton({
    required this.label,
    required this.onPressed,
    this.icon,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onPressed,
    icon: Icon(icon ?? Icons.chevron_right, size: 16),
    label: Text(label),
    style: OutlinedButton.styleFrom(
      foregroundColor: TeatroColors.ink,
      backgroundColor: TeatroColors.paper,
      side: const BorderSide(color: TeatroColors.line),
      minimumSize: const Size(0, 42),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      textStyle: Theme.of(context).textTheme.labelMedium,
    ),
  );
}
