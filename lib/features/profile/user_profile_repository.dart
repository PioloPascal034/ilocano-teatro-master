import 'package:supabase_flutter/supabase_flutter.dart';

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
}

class SupabaseUserProfileRepository implements UserProfileRepository {
  SupabaseUserProfileRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

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
        .select(
          'full_name, role, school, year_level, section, department, avatar_url',
        )
        .eq('id', user.id)
        .maybeSingle();
    if (row == null) throw StateError('Your profile record was not found.');
    return UserProfile.fromRows(
      id: user.id,
      email: user.email ?? '',
      row: Map<String, dynamic>.from(row),
    );
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

  String? _emptyToNull(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }
}
