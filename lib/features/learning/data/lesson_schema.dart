import 'package:supabase_flutter/supabase_flutter.dart';

const lessonBaseColumns =
    'lesson_id,module_id,title,objectives,content,sections,lesson_order,is_published';
const lessonMetadataColumns = 'overview,estimated_reading_minutes';

Future<({List<Map<String, dynamic>> rows, bool hasMetadata})> loadLessonRows(
  SupabaseClient client, {
  bool publishedOnly = false,
}) async {
  Future<List<Map<String, dynamic>>> query(String columns) async {
    var request = client.from('lessons').select(columns);
    if (publishedOnly) request = request.eq('is_published', true);
    return await request.order('lesson_order');
  }

  try {
    return (
      rows: await query('$lessonBaseColumns,$lessonMetadataColumns'),
      hasMetadata: true,
    );
  } on PostgrestException catch (error) {
    final missingMetadata =
        (error.code == '42703' || error.code == 'PGRST204') &&
        (error.message.contains('overview') ||
            error.message.contains('estimated_reading_minutes'));
    if (!missingMetadata) rethrow;
    return (rows: await query(lessonBaseColumns), hasMetadata: false);
  }
}
