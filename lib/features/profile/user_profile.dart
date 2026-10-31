class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.school,
    this.yearLevel,
    this.section,
    this.department,
    this.avatarUrl,
  });

  final String id;
  final String email;
  final String fullName;
  final String role;
  final String? school;
  final String? yearLevel;
  final String? section;
  final String? department;
  final String? avatarUrl;

  String get firstName {
    final normalized = fullName.trim();
    return normalized.isEmpty ? '' : normalized.split(RegExp(r'\s+')).first;
  }

  String get initials {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty);
    final initials = parts
        .take(2)
        .map((part) => String.fromCharCode(part.runes.first))
        .join()
        .toUpperCase();
    return initials.isEmpty ? '?' : initials;
  }

  factory UserProfile.fromRows({
    required String id,
    required String email,
    required Map<String, dynamic> row,
  }) => UserProfile(
    id: id,
    email: email,
    fullName: row['full_name'] as String? ?? '',
    role: row['role'] as String? ?? '',
    school: row['school'] as String?,
    yearLevel: row['year_level'] as String?,
    section: row['section'] as String?,
    department: row['department'] as String?,
    avatarUrl: row['avatar_url'] as String?,
  );
}
