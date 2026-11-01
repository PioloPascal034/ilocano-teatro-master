import 'package:flutter/material.dart';

import '../../app/app_theme.dart';

class TeatroPrimaryButton extends StatelessWidget {
  const TeatroPrimaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.expand = true,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (busy)
          const SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        else if (icon != null)
          Icon(icon, size: 17),
        if (busy || icon != null) const SizedBox(width: 9),
        Text(label),
      ],
    );
    return FilledButton(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: TeatroColors.rust,
        foregroundColor: Colors.white,
        disabledBackgroundColor: TeatroColors.rust.withValues(alpha: .55),
        minimumSize: const Size(0, 46),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
      ),
      child: child,
    );
  }
}

class TeatroSecondaryButton extends StatelessWidget {
  const TeatroSecondaryButton({
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
    icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 16),
    label: Text(label),
    style: OutlinedButton.styleFrom(
      foregroundColor: TeatroColors.ink,
      backgroundColor: TeatroColors.paper,
      side: const BorderSide(color: TeatroColors.line),
      minimumSize: const Size(0, 44),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
    ),
  );
}

class TeatroCard extends StatelessWidget {
  const TeatroCard({required this.child, this.padding, this.margin, super.key});

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) => Container(
    margin: margin,
    padding: padding ?? const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: TeatroColors.paper,
      border: Border.all(color: TeatroColors.line),
      borderRadius: BorderRadius.circular(10),
    ),
    child: child,
  );
}

class TeatroFormField extends StatelessWidget {
  const TeatroFormField({
    required this.controller,
    required this.label,
    this.hintText,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onFieldSubmitted,
    this.suffix,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String? hintText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onFieldSubmitted;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    decoration: InputDecoration(
      labelText: label,
      hintText: hintText,
      suffixIcon: suffix,
    ),
    obscureText: obscureText,
    keyboardType: keyboardType,
    textInputAction: textInputAction,
    validator: validator,
    onFieldSubmitted: onFieldSubmitted,
  );
}

enum TeatroStatusTone { neutral, pending, approved, revision, inProgress }

class TeatroStatusIndicator extends StatelessWidget {
  const TeatroStatusIndicator({
    required this.label,
    this.tone = TeatroStatusTone.neutral,
    super.key,
  });

  final String label;
  final TeatroStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (tone) {
      TeatroStatusTone.pending => (
        const Color(0xFFF4E9D2),
        const Color(0xFF8B6718),
      ),
      TeatroStatusTone.approved => (
        const Color(0xFFE8EFE1),
        TeatroColors.success,
      ),
      TeatroStatusTone.revision => (
        const Color(0xFFF5E3D8),
        TeatroColors.error,
      ),
      TeatroStatusTone.inProgress => (
        const Color(0xFFE4EDF0),
        const Color(0xFF4F7583),
      ),
      TeatroStatusTone.neutral => (const Color(0xFFF2EEE5), TeatroColors.muted),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: foreground,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class TeatroEyebrow extends StatelessWidget {
  const TeatroEyebrow(this.label, {this.color = TeatroColors.muted, super.key});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(
    label.toUpperCase(),
    style: Theme.of(context).textTheme.labelSmall?.copyWith(
      color: color,
      fontFamily: TeatroTypography.labelFamily,
      fontSize: 10,
      letterSpacing: 1.1,
    ),
  );
}
