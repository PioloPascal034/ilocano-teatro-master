import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'profile_avatar_validator.dart';
import 'user_profile.dart';

abstract interface class UserProfileRepository {
  Future<UserProfile> loadCurrentProfile();

  Future<UserProfile> updateCurrentProfile({
    required String fullName,
    required String? school,
    required String? yearLevel,
    required String? section,
    required String? department,
  });

  Future<String> uploadAvatar(Uint8List bytes);

  Future<void> saveAvatarStoragePath(String? storagePath);

  Future<void> deleteAvatar(String storagePath);
}

class SupabaseUserProfileRepository implements UserProfileRepository {
  SupabaseUserProfileRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const bucketName = 'ilocano-profile-avatars';
  static const _profileColumns =
      'full_name, role, school, year_level, section, department, avatar_url, avatar_storage_path';

  User get _user {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Sign in to view your profile.');
    return user;
  }

  @override
  Future<UserProfile> loadCurrentProfile() async {
    final user = _user;
    final row = await _client
        .from('profiles')
        .select(_profileColumns)
        .eq('id', user.id)
        .maybeSingle();
    if (row == null) throw StateError('Your profile record was not found.');
    final profile = UserProfile.fromRows(
      id: user.id,
      email: user.email ?? '',
      row: Map<String, dynamic>.from(row),
    );
    final storagePath = profile.avatarStoragePath;
    if (storagePath == null || storagePath.isEmpty) return profile;

    try {
      _requireOwnedPath(user.id, storagePath);
      final bytes = await _client.storage
          .from(bucketName)
          .download(storagePath);
      return profile.withAvatar(storagePath: storagePath, bytes: bytes);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Profile avatar download failed for "$storagePath": $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      return profile.withAvatar(storagePath: storagePath);
    }
  }

  @override
  Future<UserProfile> updateCurrentProfile({
    required String fullName,
    required String? school,
    required String? yearLevel,
    required String? section,
    required String? department,
  }) async {
    final user = _user;
    await _client
        .from('profiles')
        .update({
          'full_name': fullName.trim(),
          'school': _emptyToNull(school),
          'year_level': _emptyToNull(yearLevel),
          'section': _emptyToNull(section),
          'department': _emptyToNull(department),
        })
        .eq('id', user.id);
    return loadCurrentProfile();
  }

  @override
  Future<String> uploadAvatar(Uint8List bytes) async {
    final user = _user;
    final format = ProfileAvatarValidator.validate(bytes);
    final nonce =
        '${DateTime.now().microsecondsSinceEpoch}_'
        '${Random.secure().nextInt(0x7fffffff).toRadixString(16)}';
    final path = '${user.id}/$nonce.${format.extension}';

    final returnedKey = await _client.storage
        .from(bucketName)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: format.mimeType, upsert: false),
        );
    final bucketPrefix = '$bucketName/';
    final returnedPath = returnedKey.startsWith(bucketPrefix)
        ? returnedKey.substring(bucketPrefix.length)
        : returnedKey;
    if (returnedPath != path) {
      try {
        await _client.storage.from(bucketName).remove([path]);
      } catch (error, stackTrace) {
        if (kDebugMode) {
          debugPrint(
            'Unexpected avatar path cleanup failed for "$path": $error',
          );
          debugPrintStack(stackTrace: stackTrace);
        }
      }
      throw StateError('Storage returned an unexpected avatar object path.');
    }
    return path;
  }

  @override
  Future<void> saveAvatarStoragePath(String? storagePath) async {
    final user = _user;
    if (storagePath != null) _requireOwnedPath(user.id, storagePath);
    final row = await _client
        .from('profiles')
        .update({'avatar_storage_path': storagePath})
        .eq('id', user.id)
        .select('id')
        .maybeSingle();
    if (row == null) {
      throw StateError('Your avatar path could not be saved to your profile.');
    }
  }

  @override
  Future<void> deleteAvatar(String storagePath) async {
    final user = _user;
    _requireOwnedPath(user.id, storagePath);
    await _client.storage.from(bucketName).remove([storagePath]);
  }

  void _requireOwnedPath(String userId, String storagePath) {
    final segments = storagePath.split('/');
    if (segments.length != 2 ||
        segments.first != userId ||
        segments.last.isEmpty ||
        !const {
          'jpg',
          'jpeg',
          'png',
          'webp',
        }.contains(segments.last.split('.').last.toLowerCase())) {
      throw StateError('The avatar path does not belong to this account.');
    }
  }

  String? _emptyToNull(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }
}
