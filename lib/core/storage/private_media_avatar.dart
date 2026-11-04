import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'private_media_repository.dart';

class PrivateMediaAvatar extends StatefulWidget {
  const PrivateMediaAvatar({
    required this.userId,
    required this.storagePath,
    required this.label,
    required this.fallback,
    this.radius = 24,
    super.key,
  });

  final String userId;
  final String? storagePath;
  final String label;
  final String fallback;
  final double radius;

  @override
  State<PrivateMediaAvatar> createState() => _PrivateMediaAvatarState();
}

class _PrivateMediaAvatarState extends State<PrivateMediaAvatar> {
  PrivateMediaRepository? _repository;
  Future<Uint8List>? _image;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant PrivateMediaAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId ||
        oldWidget.storagePath != widget.storagePath) {
      _load();
    }
  }

  void _load() {
    final path = widget.storagePath;
    _image = path == null || path.isEmpty
        ? null
        : (_repository ??= SupabasePrivateMediaRepository()).download(
            type: PrivateMediaType.avatar,
            recordId: widget.userId,
            cacheVersion: path,
          );
  }

  @override
  Widget build(BuildContext context) {
    final fallback = CircleAvatar(
      radius: widget.radius,
      backgroundColor: const Color(0xFFE5C4AE),
      child: Text(widget.fallback),
    );
    final image = _image;
    if (image == null) return fallback;
    return Semantics(
      image: true,
      label: widget.label,
      child: FutureBuilder<Uint8List>(
        future: image,
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          if (bytes == null) return fallback;
          return ClipOval(
            child: SizedBox(
              width: widget.radius * 2,
              height: widget.radius * 2,
              child: Image.memory(
                bytes,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              ),
            ),
          );
        },
      ),
    );
  }
}
