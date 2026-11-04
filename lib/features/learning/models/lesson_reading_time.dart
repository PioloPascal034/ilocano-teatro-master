int lessonReadingMinutes({
  required String content,
  required Map<String, String> sections,
  String? objectives,
  String overview = '',
}) {
  final body = sections.isEmpty
      ? content
      : [
          'introduction',
          'discussion',
          'examples',
          'activities',
          'summary',
        ].map((key) => sections[key] ?? '').join(' ');
  final words = '$overview ${objectives ?? ''} $body'
      .replaceAll(RegExp(r'[#*_>]+'), ' ')
      .split(RegExp(r'\s+'))
      .where((word) => word.contains(RegExp(r'[\p{L}\p{N}]', unicode: true)))
      .length;
  return (words / 180).ceil().clamp(1, 999);
}
