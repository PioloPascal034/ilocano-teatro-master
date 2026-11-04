class TeacherConnection {
  const TeacherConnection({required this.teacherId, required this.teacherName});

  final String teacherId;
  final String teacherName;
}

class ActiveClassCode {
  const ActiveClassCode({
    required this.id,
    required this.code,
    required this.expiresAt,
  });

  final String id;
  final String code;
  final DateTime expiresAt;

  bool get isExpired => !expiresAt.isAfter(DateTime.now().toUtc());
}
