import 'dart:math';
import 'dart:ui' as ui;
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
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

  String get _projectOrigin => Uri.parse(_client.rest.url).origin;

  static const bucketName = 'ilocano-profile-avatars';
  static const _profileColumns =
      'id, full_name, role, school, year_level, section, department, avatar_url, avatar_storage_path';

  User get _user {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Sign in to view your profile.');
    return user;
  }

  @override
  Future<UserProfile> loadCurrentProfile() async {
    final user = _user;
    final sessionUserId = _client.auth.currentSession?.user.id;
    final row = await _client
        .from('profiles')
        .select(_profileColumns)
        .eq('id', user.id)
        .maybeSingle();
    if (row == null) throw StateError('Your profile record was not found.');
    final profileRowId = row['id'] as String?;
    final rowStoragePath = row['avatar_storage_path'] as String?;
    if (kDebugMode) {
      debugPrint(
        'Profile avatar profile row loaded: auth_user_id=${user.id}, session_user_id=${sessionUserId ?? '(no active session)'}, row_user_id=${profileRowId ?? '(missing id)'}, stored_path="${rowStoragePath ?? '(null)'}".',
      );
    }
    if (profileRowId != user.id) {
      throw StateError('The loaded profile does not match the active account.');
    }
    final profile = UserProfile.fromRows(
      id: user.id,
      email: user.email ?? '',
      row: Map<String, dynamic>.from(row),
    );
    final storagePath = profile.avatarStoragePath;
    if (storagePath == null || storagePath.isEmpty) return profile;

    var stage = 'validating saved object path';
    try {
      _requireOwnedPath(user.id, storagePath);
      stage = 'checking active session';
      final downloadSessionUserId = _client.auth.currentSession?.user.id;
      if (kDebugMode) {
        debugPrint(
          'Profile avatar request: project_origin="$_projectOrigin", operation=storage.object.get_authenticated, bucket="$bucketName", object_name="$storagePath", auth_user_id=${user.id}, session_user_id=${downloadSessionUserId ?? '(no active session)'}.',
        );
      }
      if (downloadSessionUserId != user.id) {
        throw StateError(
          'The active Supabase session changed before the avatar download.',
        );
      }
      stage = 'authenticated Storage object download';
      final bytes = await _client.storage
          .from(bucketName)
          .download(storagePath);
      stage = 'decoding downloaded image bytes';
      final dimensions = await _validateImageBytes(bytes);
      if (kDebugMode) {
        debugPrint(
          'Profile avatar response: bucket="$bucketName", object_name="$storagePath", bytes=${bytes.length}, decoded=${dimensions.$1}x${dimensions.$2}.',
        );
      }
      return profile.withAvatar(storagePath: storagePath, bytes: bytes);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'Profile avatar load failed at $stage for "$storagePath": ${_storageDiagnostic(error)}',
        );
        debugPrintStack(stackTrace: stackTrace);
        if (stage == 'authenticated Storage object download' &&
            error is StorageException) {
          await _diagnoseRawAuthenticatedGet(
            userId: user.id,
            storagePath: storagePath,
          );
        }
      }
      return profile.withAvatar(
        storagePath: storagePath,
        loadError:
            'The saved photo could not be downloaded. Retry or choose a new photo.',
      );
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
    final sessionUserId = _client.auth.currentSession?.user.id;
    if (kDebugMode) {
      debugPrint(
        'Profile avatar upload started: bucket="$bucketName", auth_user_id=${user.id}, session_user_id=${sessionUserId ?? '(no active session)'}, bytes=${bytes.length}.',
      );
    }
    if (sessionUserId != user.id) {
      throw StateError('The active Supabase session changed before upload.');
    }
    final format = ProfileAvatarValidator.validate(bytes);
    try {
      final dimensions = await _validateImageBytes(bytes);
      if (kDebugMode) {
        debugPrint(
          'Selected profile image decoded: ${dimensions.$1}x${dimensions.$2}, format=${format.mimeType}.',
        );
      }
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Selected profile image bytes could not be decoded: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      rethrow;
    }
    final nonce =
        '${DateTime.now().microsecondsSinceEpoch}_'
        '${Random.secure().nextInt(0x7fffffff).toRadixString(16)}';
    final path = '${user.id}/$nonce.${format.extension}';
    final uploadSessionUserId = _client.auth.currentSession?.user.id;
    if (kDebugMode) {
      debugPrint(
        'Profile avatar upload request: project_origin="$_projectOrigin", operation=storage.object.upload, bucket="$bucketName", object_name="$path", auth_user_id=${user.id}, session_user_id=${uploadSessionUserId ?? '(no active session)'}.',
      );
    }
    if (uploadSessionUserId != user.id) {
      throw StateError('The active Supabase session changed before upload.');
    }

    late final String returnedKey;
    try {
      returnedKey = await _client.storage
          .from(bucketName)
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: format.mimeType,
              upsert: false,
            ),
          );
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'Profile avatar upload failed: bucket="$bucketName", object_name="$path": ${_storageDiagnostic(error)}',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
      rethrow;
    }
    final bucketPrefix = '$bucketName/';
    final returnedPath = returnedKey.startsWith(bucketPrefix)
        ? returnedKey.substring(bucketPrefix.length)
        : returnedKey;
    if (kDebugMode) {
      debugPrint(
        'Profile avatar upload response: requested_object_name="$path", returned_key="$returnedKey", normalized_object_name="$returnedPath".',
      );
    }
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
    if (kDebugMode) debugPrint('Profile avatar upload succeeded: "$path".');
    return path;
  }

  @override
  Future<void> saveAvatarStoragePath(String? storagePath) async {
    final user = _user;
    if (storagePath != null) _requireOwnedPath(user.id, storagePath);
    late final Map<String, dynamic>? row;
    try {
      row = await _client
          .from('profiles')
          .update({'avatar_storage_path': storagePath})
          .eq('id', user.id)
          .select('id, avatar_storage_path')
          .maybeSingle();
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'Profile avatar path update failed: auth_user_id=${user.id}, requested_path="${storagePath ?? '(null)'}", error=$error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
      rethrow;
    }
    if (row == null) {
      throw StateError('Your avatar path could not be saved to your profile.');
    }
    final returnedPath = row['avatar_storage_path'] as String?;
    if (kDebugMode) {
      debugPrint(
        'Profile avatar database update: auth_user_id=${user.id}, row_user_id=${row['id']}, requested_path="${storagePath ?? '(null)'}", returned_path="${returnedPath ?? '(null)'}".',
      );
    }
    if (returnedPath != storagePath) {
      throw StateError(
        'The saved profile photo path did not match the upload.',
      );
    }
  }

  @override
  Future<void> deleteAvatar(String storagePath) async {
    final user = _user;
    _requireOwnedPath(user.id, storagePath);
    try {
      if (kDebugMode) {
        debugPrint(
          'Profile avatar cleanup request: project_origin="$_projectOrigin", operation=storage.object.delete_many, bucket="$bucketName", object_name="$storagePath", auth_user_id=${user.id}, session_user_id=${_client.auth.currentSession?.user.id ?? '(no active session)'}.',
        );
      }
      await _client.storage.from(bucketName).remove([storagePath]);
      if (kDebugMode) {
        debugPrint('Profile avatar object removed: "$storagePath".');
      }
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'Profile avatar object removal failed for "$storagePath": ${_storageDiagnostic(error)}',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
      rethrow;
    }
  }

  Future<(int, int)> _validateImageBytes(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      final frame = await codec.getNextFrame();
      final dimensions = (frame.image.width, frame.image.height);
      frame.image.dispose();
      return dimensions;
    } finally {
      codec.dispose();
    }
  }

  Future<void> _diagnoseRawAuthenticatedGet({
    required String userId,
    required String storagePath,
  }) async {
    final session = _client.auth.currentSession;
    if (session == null) {
      debugPrint('Avatar raw HTTP diagnostic skipped: no active user session.');
      return;
    }
    if (session.user.id != userId) {
      debugPrint(
        'Avatar raw HTTP diagnostic skipped: active session user does not match profile user.',
      );
      return;
    }
    const publishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
    if (publishableKey.isEmpty) {
      debugPrint(
        'Avatar raw HTTP diagnostic skipped: publishable key define is unavailable.',
      );
      return;
    }

    final restUri = Uri.parse(_client.rest.url);
    final projectSegments = restUri.pathSegments.toList();
    if (projectSegments.length >= 2 &&
        projectSegments[projectSegments.length - 2] == 'rest' &&
        projectSegments.last == 'v1') {
      projectSegments.removeRange(
        projectSegments.length - 2,
        projectSegments.length,
      );
    }
    final uri = restUri.replace(
      pathSegments: [
        ...projectSegments,
        'storage',
        'v1',
        'object',
        bucketName,
        ...storagePath.split('/'),
      ],
    );
    final client = http.Client();
    try {
      final jwtContext = _safeJwtContext(session.accessToken);
      debugPrint(
        'Avatar raw HTTP diagnostic request: project_origin="${uri.origin}", method=GET, path="${uri.path}", auth_user_id=${session.user.id}, jwt_sub=${jwtContext['sub'] ?? '(unavailable)'}, jwt_role=${jwtContext['role'] ?? '(unavailable)'}, jwt_aud=${jwtContext['aud'] ?? '(unavailable)'}, jwt_expired=${jwtContext['expired'] ?? '(unavailable)'}, access_token_present=true (token not logged).',
      );
      final response = await client
          .get(
            uri,
            headers: {
              'apikey': publishableKey,
              'Authorization': 'Bearer ${session.accessToken}',
            },
          )
          .timeout(const Duration(seconds: 15));
      final requestId =
          response.headers['sb-request-id'] ??
          response.headers['x-request-id'] ??
          '(not returned)';
      if (response.statusCode >= 200 && response.statusCode < 300) {
        try {
          final dimensions = await _validateImageBytes(response.bodyBytes);
          debugPrint(
            'Avatar raw HTTP diagnostic response: status=${response.statusCode}, request_id="$requestId", bytes=${response.bodyBytes.length}, decoded=${dimensions.$1}x${dimensions.$2}.',
          );
        } catch (error) {
          debugPrint(
            'Avatar raw HTTP diagnostic response: status=${response.statusCode}, request_id="$requestId", bytes=${response.bodyBytes.length}, image_decode_error=$error.',
          );
        }
        return;
      }

      var error = 'unparsed response';
      var code = 'unspecified';
      var message = 'response body omitted';
      try {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        if (body is Map<String, dynamic>) {
          error = body['error']?.toString() ?? error;
          code = body['code']?.toString() ?? code;
          message = body['message']?.toString() ?? message;
        }
      } catch (_) {
        message = 'non-JSON body (${response.bodyBytes.length} bytes)';
      }
      debugPrint(
        'Avatar raw HTTP diagnostic response: http_status=${response.statusCode}, request_id="$requestId", error="$error", code="$code", message="$message".',
      );
    } catch (error) {
      debugPrint('Avatar raw HTTP diagnostic request failed: $error.');
    } finally {
      client.close();
    }
  }

  Map<String, Object?> _safeJwtContext(String accessToken) {
    try {
      final segments = accessToken.split('.');
      if (segments.length < 2) return const {};
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(segments[1]))),
      );
      if (payload is! Map<String, dynamic>) return const {};
      final expiry = payload['exp'];
      return {
        'sub': payload['sub'],
        'role': payload['role'],
        'aud': payload['aud'],
        'expired': expiry is num
            ? DateTime.now().millisecondsSinceEpoch ~/ 1000 >= expiry
            : null,
      };
    } catch (_) {
      return const {};
    }
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

  String _storageDiagnostic(Object error) {
    if (error is StorageException) {
      final status = error.statusCode ?? 'unknown';
      final code = error.error ?? 'unspecified';
      final responseText = '${error.error} ${error.message}'.toLowerCase();
      final normalizedCode = code.toLowerCase();
      final cause =
          status == '401' ||
              status == '403' ||
              normalizedCode == 'accessdenied' ||
              responseText.contains('unauthorized') ||
              responseText.contains('permission')
          ? 'authentication or Storage policy rejected the request'
          : normalizedCode == 'nosuchkey'
          ? 'the Storage key was not found or is not visible to this session'
          : normalizedCode == 'nosuchbucket'
          ? 'the Storage bucket was not found or is not visible to this session'
          : status == '404'
          ? 'Storage returned not found; the object may be missing or hidden by access policy'
          : 'Storage request failed';
      return '$cause (status: $status, code: $code, message: ${error.message})';
    }
    return error.toString();
  }

  String? _emptyToNull(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }
}
