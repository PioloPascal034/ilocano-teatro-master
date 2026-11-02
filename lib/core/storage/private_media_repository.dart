import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

enum PrivateMediaType { avatar, storyCover, chapterIllustration }

abstract interface class PrivateMediaRepository {
  Future<Uint8List> download({
    required PrivateMediaType type,
    required String recordId,
    required String cacheVersion,
  });
}

class PrivateMediaException implements Exception {
  const PrivateMediaException(this.statusCode, this.code);

  final int statusCode;
  final String code;

  @override
  String toString() => 'Private media request failed ($statusCode, $code).';
}

class SupabasePrivateMediaRepository implements PrivateMediaRepository {
  SupabasePrivateMediaRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  static const _cacheDuration = Duration(minutes: 1);
  static final Map<String, _CachedMedia> _cache = {};

  final SupabaseClient _client;

  @override
  Future<Uint8List> download({
    required PrivateMediaType type,
    required String recordId,
    required String cacheVersion,
  }) async {
    final session = _client.auth.currentSession;
    final userId = _client.auth.currentUser?.id;
    if (session == null || userId == null || session.accessToken.isEmpty) {
      throw const PrivateMediaException(401, 'unauthenticated');
    }

    final cacheKey = '$userId:${type.name}:$recordId:$cacheVersion';
    final now = DateTime.now();
    _cache.removeWhere((_, entry) => !entry.expiresAt.isAfter(now));
    final cached = _cache[cacheKey];
    if (cached != null && cached.expiresAt.isAfter(now)) {
      return cached.bytes;
    }
    if (cached != null) _cache.remove(cacheKey);

    final request = _fetch(session.accessToken, type: type, recordId: recordId);
    final entry = _CachedMedia(
      bytes: request,
      expiresAt: now.add(_cacheDuration),
    );
    _cache[cacheKey] = entry;
    try {
      return await request;
    } catch (_) {
      if (identical(_cache[cacheKey], entry)) _cache.remove(cacheKey);
      rethrow;
    }
  }

  Future<Uint8List> _fetch(
    String accessToken, {
    required PrivateMediaType type,
    required String recordId,
  }) async {
    const baseUrl = String.fromEnvironment('SUPABASE_URL');
    const publishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
    if (baseUrl.isEmpty || publishableKey.isEmpty) {
      throw const PrivateMediaException(503, 'media_service_unavailable');
    }

    final endpoint = _functionUri(Uri.parse(_client.rest.url));
    final response = await http
        .post(
          endpoint,
          headers: {
            'apikey': publishableKey,
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json; charset=utf-8',
            'Accept': 'image/jpeg, image/png, image/webp',
          },
          body: jsonEncode({'type': _typeName(type), 'recordId': recordId}),
        )
        .timeout(const Duration(seconds: 20));

    final contentType = response.headers['content-type']?.split(';').first;
    if (response.statusCode != 200) {
      throw PrivateMediaException(
        response.statusCode,
        _errorCode(response.bodyBytes),
      );
    }

    if (!const {
      'image/jpeg',
      'image/png',
      'image/webp',
    }.contains(contentType)) {
      throw const PrivateMediaException(502, 'invalid_media_response');
    }
    if (response.bodyBytes.isEmpty) {
      throw const PrivateMediaException(502, 'empty_media_response');
    }
    return Uint8List.fromList(response.bodyBytes);
  }

  Uri _functionUri(Uri restUri) {
    final projectSegments = restUri.pathSegments.toList();
    if (projectSegments.length >= 2 &&
        projectSegments[projectSegments.length - 2] == 'rest' &&
        projectSegments.last == 'v1') {
      projectSegments.removeRange(
        projectSegments.length - 2,
        projectSegments.length,
      );
    }
    return restUri.replace(
      pathSegments: [
        ...projectSegments,
        'functions',
        'v1',
        'get-private-media',
      ],
    );
  }

  String _typeName(PrivateMediaType type) => switch (type) {
    PrivateMediaType.avatar => 'avatar',
    PrivateMediaType.storyCover => 'story_cover',
    PrivateMediaType.chapterIllustration => 'chapter_illustration',
  };

  String _errorCode(Uint8List bodyBytes) {
    try {
      final body = jsonDecode(utf8.decode(bodyBytes));
      if (body is Map<String, dynamic>) {
        return body['error']?.toString() ?? 'media_request_failed';
      }
    } catch (_) {
      // Error bodies are intentionally reduced to a stable code.
    }
    return 'media_request_failed';
  }
}

class _CachedMedia {
  const _CachedMedia({required this.bytes, required this.expiresAt});

  final Future<Uint8List> bytes;
  final DateTime expiresAt;
}
