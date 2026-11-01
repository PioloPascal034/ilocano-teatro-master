import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../core/widgets/teatro_widgets.dart';
import 'data/teacher_student_progress_repository.dart';
import '../../core/widgets/teatro_design_widgets.dart';

class TeacherStudentProgressScreen extends StatefulWidget {
  const TeacherStudentProgressScreen({required this.repository, super.key});

  final TeacherStudentProgressRepository repository;

  @override
  State<TeacherStudentProgressScreen> createState() =>
      _TeacherStudentProgressScreenState();
}

class _TeacherStudentProgressScreenState
    extends State<TeacherStudentProgressScreen> {
  late Future<List<TeacherStudentProgress>> _students;

  @override
  void initState() {
    super.initState();
    _students = widget.repository.loadAssignedStudents();
  }

  void _retry() =>
      setState(() => _students = widget.repository.loadAssignedStudents());

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<List<TeacherStudentProgress>>(
    future: _students,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _StateCard(
          title: 'Progress could not be loaded',
          message: snapshot.error is StateError
              ? (snapshot.error! as StateError).message
              : 'Please check your connection and try again.',
          action: TextButton.icon(
            onPressed: _retry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        );
      }
      if (!snapshot.hasData) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(44),
            child: CircularProgressIndicator(),
          ),
        );
      }
      final students = snapshot.data!;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TeatroPageBody(
            eyebrow: 'LEARNING ACTIVITY',
            title: 'Student progress',
            description: 'Progress for students assigned to your account.',
            child: SizedBox.shrink(),
          ),
          if (students.isEmpty)
            const _StateCard(
              title: 'No students assigned yet',
              message:
                  'Students will appear here after they are assigned to your teacher account.',
            )
          else
            TeatroCard(
              padding: EdgeInsets.zero,
              child: LayoutBuilder(
                builder: (context, constraints) => constraints.maxWidth < 720
                    ? Column(
                        children: [
                          for (final student in students)
                            _StudentProgressTile(
                              student: student,
                              onTap: () => _showDetails(context, student),
                            ),
                        ],
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: const WidgetStatePropertyAll(
                            Color(0xFFF7F4EE),
                          ),
                          columns: const [
                            DataColumn(label: Text('STUDENT')),
                            DataColumn(label: Text('LESSONS COMPLETED')),
                            DataColumn(label: Text('COMPLETION')),
                            DataColumn(label: Text('QUIZ AVERAGE')),
                            DataColumn(label: Text('STATUS')),
                          ],
                          rows: [
                            for (final student in students)
                              DataRow(
                                onSelectChanged: (_) =>
                                    _showDetails(context, student),
                                cells: [
                                  DataCell(Text(_provided(student.fullName))),
                                  DataCell(
                                    Text(
                                      '${student.completedLessons} / ${student.totalLessons}',
                                    ),
                                  ),
                                  DataCell(_CompletionCell(student: student)),
                                  DataCell(Text(_score(student.quizAverage))),
                                  DataCell(
                                    TeatroStatus(status: student.status),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
              ),
            ),
        ],
      );
    },
  );

  Future<void> _showDetails(
    BuildContext context,
    TeacherStudentProgress student,
  ) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(_provided(student.fullName)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lessons completed: ${student.completedLessons} of ${student.totalLessons}',
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: student.completion),
          const SizedBox(height: 12),
          Text('Quiz average: ${_score(student.quizAverage)}'),
          Text('Status: ${student.status}'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

class _StudentProgressTile extends StatelessWidget {
  const _StudentProgressTile({required this.student, required this.onTap});
  final TeacherStudentProgress student;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
    leading: CircleAvatar(
      backgroundColor: const Color(0xFFE5C4AE),
      child: Text(_initials(student.fullName)),
    ),
    title: Text(_provided(student.fullName)),
    subtitle: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 5),
        Text(
          '${student.completedLessons} / ${student.totalLessons} lessons · Quiz ${_score(student.quizAverage)}',
        ),
        const SizedBox(height: 5),
        LinearProgressIndicator(value: student.completion),
      ],
    ),
    trailing: TeatroStatus(status: student.status),
  );
}

class _CompletionCell extends StatelessWidget {
  const _CompletionCell({required this.student});
  final TeacherStudentProgress student;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 124,
    child: Row(
      children: [
        Expanded(child: LinearProgressIndicator(value: student.completion)),
        const SizedBox(width: 7),
        Text('${(student.completion * 100).round()}%'),
      ],
    ),
  );
}

class _StateCard extends StatelessWidget {
  const _StateCard({required this.title, required this.message, this.action});
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => TeatroCard(
    child: Column(
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 5),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: TeatroColors.muted),
        ),
        ?action,
      ],
    ),
  );
}

String _score(double? score) =>
    score == null ? 'Not available' : '${score.toStringAsFixed(1)}%';
String _provided(String value) =>
    value.trim().isEmpty ? 'Not provided' : value.trim();
String _initials(String value) {
  final words = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty);
  return words
      .take(2)
      .map((word) => String.fromCharCode(word.runes.first))
      .join()
      .toUpperCase();
}
