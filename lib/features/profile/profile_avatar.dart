import 'package:flutter/material.dart';

import 'user_profile.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    required this.profile,
    required this.size,
    this.backgroundColor = const Color(0xFFE5C4AE),
    this.foregroundColor = const Color(0xFF804123),
    super.key,
  });

  final UserProfile? profile;
  final double size;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    final bytes = profile?.avatarBytes;
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: backgroundColor,
      child: bytes == null
          ? Text(
              profile?.initials ?? '?',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: foregroundColor,
                fontSize: size * .3,
              ),
            )
          : ClipOval(
              child: Image.memory(
                bytes,
                width: size,
                height: size,
                fit: BoxFit.cover,
                semanticLabel:
                    '${profile?.fullName ?? 'Account'} profile photo',
                errorBuilder: (context, error, stackTrace) => Center(
                  child: Text(
                    profile?.initials ?? '?',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: foregroundColor,
                      fontSize: size * .3,
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
