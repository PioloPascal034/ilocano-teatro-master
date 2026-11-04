import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    'supabase/migrations/20261103000001_class_join_codes.sql',
  ).readAsStringSync();

  test('migration uses server-side code validation and revocation', () {
    expect(migration, contains('security definer'));
    expect(
      migration,
      contains('extensions.digest(normalized_code, \'sha256\')'),
    );
    expect(migration, contains('revoked_at is null'));
    expect(migration, contains('expires_at > now()'));
    expect(migration, contains('teacher_students.assigned_at is required'));
    expect(migration, contains('extensions.gen_random_bytes is required'));
    expect(migration, contains('Only student accounts may join a class'));
    expect(migration, contains('Only teachers may create class codes'));
  });

  test(
    'migration keeps joins idempotent and preserves existing assignments',
    () {
      expect(
        migration,
        contains('on conflict on constraint teacher_students_pkey do nothing'),
      );
      expect(migration, contains('already connected to another teacher'));
      expect(migration, contains('update public.teacher_class_codes'));
      expect(migration, contains('set revoked_at = now()'));
      expect(
        migration,
        contains('teacher_students_one_teacher_per_student_idx'),
      );
      expect(migration, contains('when unique_violation then'));
    },
  );

  test('class-code table has no direct authenticated table access', () {
    expect(
      migration,
      contains(
        'revoke all on public.teacher_class_codes from public, anon, authenticated',
      ),
    );
  });
}
