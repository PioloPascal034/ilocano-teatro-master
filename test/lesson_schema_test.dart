import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ilocano_teatro_master/features/learning/data/lesson_schema.dart';

void main() {
  test('Stage A fallback keeps the student publication filter', () async {
    final requests = <Uri>[];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      httpClient: MockClient((request) async {
        requests.add(request.url);
        if (requests.length == 1) {
          return http.Response(
            jsonEncode({
              'code': '42703',
              'message': 'column lessons.overview does not exist',
            }),
            400,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          '[]',
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.dispose);
    final result = await loadLessonRows(client, publishedOnly: true);
    expect(result.hasMetadata, isFalse);
    expect(requests, hasLength(2));
    expect(
      requests.every((uri) => uri.queryParameters['is_published'] == 'eq.true'),
      isTrue,
    );
    expect(requests.last.queryParameters['select'], lessonBaseColumns);
  });

  test('Permission errors are not mistaken for a missing migration', () async {
    var calls = 0;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      httpClient: MockClient((request) async {
        calls++;
        return http.Response(
          jsonEncode({'code': '42501', 'message': 'permission denied'}),
          403,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.dispose);
    await expectLater(
      loadLessonRows(client),
      throwsA(isA<PostgrestException>()),
    );
    expect(calls, 1);
  });
}
