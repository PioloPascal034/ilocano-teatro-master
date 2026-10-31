import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../core/widgets/teatro_widgets.dart';
import 'data/quiz_management_repository.dart';
import 'models/quiz_management_models.dart';

class TeacherQuizManagementScreen extends StatefulWidget {
  const TeacherQuizManagementScreen({
    required this.moduleId,
    required this.repository,
    super.key,
  });
  final String moduleId;
  final QuizManagementRepository repository;

  @override
  State<TeacherQuizManagementScreen> createState() =>
      _TeacherQuizManagementScreenState();
}

class _TeacherQuizManagementScreenState
    extends State<TeacherQuizManagementScreen> {
  late Future<_QuizManagementData> _load;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load = _fetch();
  }

  @override
  void didUpdateWidget(covariant TeacherQuizManagementScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.moduleId != widget.moduleId ||
        oldWidget.repository != widget.repository) {
      _refresh();
    }
  }

  Future<_QuizManagementData> _fetch() async => _QuizManagementData(
    editor: await widget.repository.isCurriculumEditor(),
    quizzes: await widget.repository.loadQuizzes(widget.moduleId),
  );
  void _refresh() => setState(() {
    _load = _fetch();
  });

  @override
  Widget build(BuildContext context) => FutureBuilder<_QuizManagementData>(
    future: _load,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quiz management could not be loaded',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                _error(snapshot.error!),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              TextButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        );
      }
      if (!snapshot.hasData) {
        return const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      final data = snapshot.data!;
      return TeatroCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
              child: Row(
                children: [
                  const Expanded(child: TeatroEyebrow('KNOWLEDGE CHECKS')),
                  if (data.editor)
                    TextButton.icon(
                      onPressed: _busy ? null : _createQuiz,
                      icon: const Icon(Icons.add),
                      label: const Text('Create quiz'),
                    ),
                ],
              ),
            ),
            if (_busy) const LinearProgressIndicator(),
            if (data.quizzes.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                child: Text(
                  data.editor
                      ? 'No quizzes yet. Create an unpublished quiz to begin.'
                      : 'No published quizzes are available for this module.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: TeatroColors.muted),
                ),
              )
            else
              for (final quiz in data.quizzes)
                _QuizRow(
                  quiz: quiz,
                  editor: data.editor,
                  onManage: () => _manage(quiz, editor: data.editor),
                  onPublish: () => _publication(quiz),
                ),
            if (data.editor)
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 0, 18, 16),
                child: Text(
                  'Publishing requires at least one question, two options per question, and exactly one correct answer. Unpublish before editing. Content is locked after a student attempt.',
                  style: TextStyle(fontSize: 12, color: TeatroColors.muted),
                ),
              ),
          ],
        ),
      );
    },
  );

  Future<void> _createQuiz() async {
    final values = await showDialog<_QuizValues>(
      context: context,
      builder: (_) => const _QuizFormDialog(),
    );
    if (values == null) return;
    await _run(() async {
      await widget.repository.createQuiz(
        moduleId: widget.moduleId,
        title: values.title,
        description: values.description,
        passingScore: values.passingScore,
      );
    }, 'Quiz saved as unpublished.');
  }

  Future<void> _manage(ManagedQuiz quiz, {required bool editor}) async {
    try {
      final details = await widget.repository.loadQuizDetails(quiz.id);
      if (!mounted) return;
      if (details == null) {
        _message('Quiz is no longer available.', error: true);
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (_) => _QuizManagerDialog(
          quiz: details.quiz,
          questions: details.questions,
          editor: editor,
          repository: widget.repository,
          onSaved: () {
            if (mounted) _refresh();
          },
        ),
      );
      if (mounted) _refresh();
    } catch (error) {
      if (mounted) _message(_error(error), error: true);
    }
  }

  Future<void> _publication(ManagedQuiz quiz) async {
    final publish = !quiz.isPublished;
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(publish ? 'Publish quiz?' : 'Unpublish quiz?'),
            content: Text(
              publish
                  ? 'Students can take this quiz when its module is published. The database will validate its questions and answer options.'
                  : 'Students will no longer be able to start this quiz. Saved attempts and answers will remain.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(publish ? 'Publish quiz' : 'Unpublish quiz'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    await _run(
      () =>
          widget.repository.setPublished(quizId: quiz.id, isPublished: publish),
      publish ? 'Quiz published.' : 'Quiz unpublished.',
    );
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      _refresh();
      _message(success);
    } catch (error) {
      if (mounted) _message(_error(error), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String value, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value),
          backgroundColor: error ? TeatroColors.error : null,
        ),
      );
  String _error(Object error) => error
      .toString()
      .replaceFirst('Exception: ', '')
      .replaceFirst('PostgrestException(message: ', '')
      .replaceAll(RegExp(r', code:.*$'), '');
}

class _QuizManagementData {
  const _QuizManagementData({required this.editor, required this.quizzes});
  final bool editor;
  final List<ManagedQuiz> quizzes;
}

class _QuizRow extends StatelessWidget {
  const _QuizRow({
    required this.quiz,
    required this.editor,
    required this.onManage,
    required this.onPublish,
  });
  final ManagedQuiz quiz;
  final bool editor;
  final VoidCallback onManage;
  final VoidCallback onPublish;
  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: TeatroColors.line)),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        final summary = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(quiz.title, style: Theme.of(context).textTheme.titleMedium),
            if (quiz.description.isNotEmpty)
              Text(
                quiz.description,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: TeatroColors.muted),
              ),
            const SizedBox(height: 4),
            Text(
              'Passing score: ${quiz.passingScore}%',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: 5),
            _StatusPill(published: quiz.isPublished),
          ],
        );
        final actions = Wrap(
          spacing: 5,
          children: [
            TextButton.icon(
              onPressed: onManage,
              icon: const Icon(Icons.visibility_outlined, size: 17),
              label: Text(editor ? 'Manage' : 'View'),
            ),
            if (editor)
              TextButton.icon(
                onPressed: onPublish,
                icon: Icon(
                  quiz.isPublished
                      ? Icons.visibility_off_outlined
                      : Icons.publish_outlined,
                  size: 17,
                ),
                label: Text(quiz.isPublished ? 'Unpublish' : 'Publish'),
              ),
          ],
        );
        return compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [summary, const SizedBox(height: 8), actions],
              )
            : Row(
                children: [
                  Expanded(child: summary),
                  actions,
                ],
              );
      },
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.published});
  final bool published;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: published ? const Color(0xFFE7EEE3) : const Color(0xFFF3E8D5),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      published ? 'Published' : 'Unpublished',
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: published ? TeatroColors.success : TeatroColors.rust,
      ),
    ),
  );
}

class _QuizValues {
  const _QuizValues(this.title, this.description, this.passingScore);
  final String title;
  final String description;
  final int passingScore;
}

class _QuizFormDialog extends StatefulWidget {
  const _QuizFormDialog({this.quiz});
  final ManagedQuiz? quiz;
  @override
  State<_QuizFormDialog> createState() => _QuizFormDialogState();
}

class _QuizFormDialogState extends State<_QuizFormDialog> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _title, _description, _score;
  @override
  void initState() {
    super.initState();
    final quiz = widget.quiz;
    _title = TextEditingController(text: quiz?.title);
    _description = TextEditingController(text: quiz?.description);
    _score = TextEditingController(text: '${quiz?.passingScore ?? 70}');
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _score.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.quiz == null ? 'Create quiz' : 'Edit quiz'),
    content: SizedBox(
      width: 440,
      child: Form(
        key: _key,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Quiz title'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                decoration: const InputDecoration(labelText: 'Description'),
                minLines: 2,
                maxLines: 4,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _score,
                decoration: const InputDecoration(
                  labelText: 'Passing score (0–100)',
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  return n == null || n < 0 || n > 100
                      ? 'Enter a score from 0 to 100.'
                      : null;
                },
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (!_key.currentState!.validate()) return;
          Navigator.pop(
            context,
            _QuizValues(
              _title.text.trim(),
              _description.text.trim(),
              int.parse(_score.text),
            ),
          );
        },
        child: Text(widget.quiz == null ? 'Save quiz' : 'Save changes'),
      ),
    ],
  );
  String? _required(String? value) =>
      value?.trim().isEmpty ?? true ? 'This field is required.' : null;
}

class _QuizManagerDialog extends StatefulWidget {
  const _QuizManagerDialog({
    required this.quiz,
    required this.questions,
    required this.editor,
    required this.repository,
    required this.onSaved,
  });
  final ManagedQuiz quiz;
  final List<ManagedQuizQuestion> questions;
  final bool editor;
  final QuizManagementRepository repository;
  final VoidCallback onSaved;
  @override
  State<_QuizManagerDialog> createState() => _QuizManagerDialogState();
}

class _QuizManagerDialogState extends State<_QuizManagerDialog> {
  late ManagedQuiz _quiz;
  late List<ManagedQuizQuestion> _questions;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _quiz = widget.quiz;
    _questions = List.of(widget.questions);
  }

  bool get _editable => widget.editor && !_quiz.isPublished;
  Future<void> _editQuiz() async {
    final values = await showDialog<_QuizValues>(
      context: context,
      builder: (_) => _QuizFormDialog(quiz: _quiz),
    );
    if (values == null) return;
    await _action(() async {
      await widget.repository.updateQuiz(
        quizId: _quiz.id,
        title: values.title,
        description: values.description,
        passingScore: values.passingScore,
      );
      _quiz = ManagedQuiz(
        id: _quiz.id,
        moduleId: _quiz.moduleId,
        title: values.title,
        description: values.description,
        passingScore: values.passingScore,
        isPublished: _quiz.isPublished,
      );
    });
  }

  Future<void> _previewAsStudent() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('${_quiz.title} · Preview'),
      content: SizedBox(
        width: 620,
        height: MediaQuery.sizeOf(context).height * .65,
        child: ListView(
          children: [
            if (_quiz.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_quiz.description),
              ),
            for (var i = 0; i < _questions.length; i++) ...[
              Text(
                '${i + 1}. ${_questions[i].text}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              for (final option in _questions[i].options)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.radio_button_unchecked, size: 18),
                  title: Text(option.text),
                ),
              const Divider(),
            ],
            if (_questions.isEmpty)
              const Text('Add questions to preview this quiz.'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close preview'),
        ),
      ],
    ),
  );

  Future<void> _editQuestion([ManagedQuizQuestion? question]) async {
    final values = await showDialog<_QuestionValues>(
      context: context,
      builder: (_) => _QuestionFormDialog(question: question),
    );
    if (values == null) return;
    await _action(() async {
      final qid = question == null
          ? await widget.repository.createQuestion(
              quizId: _quiz.id,
              text: values.text,
              explanation: values.explanation,
            )
          : question.id;
      if (question != null) {
        await widget.repository.updateQuestion(
          questionId: qid,
          text: values.text,
          explanation: values.explanation,
        );
      }
      for (final option in values.options) {
        if (option.id == null) {
          await widget.repository.createOption(
            questionId: qid,
            text: option.text,
            isCorrect: option.correct,
          );
        } else {
          await widget.repository.updateOption(
            optionId: option.id!,
            text: option.text,
            isCorrect: option.correct,
          );
        }
      }
      await _reload();
    });
  }

  Future<void> _reload() async {
    final details = await widget.repository.loadQuizDetails(_quiz.id);
    if (details != null) {
      _quiz = details.quiz;
      _questions = List.of(details.questions);
    }
  }

  Future<void> _move(int index, int direction) async {
    final target = index + direction;
    if (target < 0 || target >= _questions.length) return;
    final ids = _questions.map((q) => q.id).toList();
    final item = ids.removeAt(index);
    ids.insert(target, item);
    await _action(() async {
      await widget.repository.reorderQuestions(
        quizId: _quiz.id,
        questionIds: ids,
      );
      await _reload();
    });
  }

  Future<void> _action(Future<void> Function() fn) async {
    setState(() => _busy = true);
    try {
      await fn();
      if (mounted) {
        widget.onSaved();
        setState(() {});
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Quiz changes saved.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            backgroundColor: TeatroColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Row(
      children: [
        Expanded(child: Text(_quiz.title)),
        _StatusPill(published: _quiz.isPublished),
      ],
    ),
    content: SizedBox(
      width: 700,
      height: MediaQuery.sizeOf(context).height * .7,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_busy) const LinearProgressIndicator(),
          Text(
            _quiz.description.isEmpty
                ? 'No description provided.'
                : _quiz.description,
          ),
          Text('Passing score: ${_quiz.passingScore}%'),
          const Divider(),
          if (widget.editor)
            Text(
              _quiz.isPublished
                  ? 'Unpublish this quiz before editing. After an attempt, its content and scoring are locked.'
                  : 'Draft content. Publishing validates question count, option count, and one correct answer per question.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: TeatroColors.muted),
            ),
          const SizedBox(height: 8),
          if (widget.editor)
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _previewAsStudent,
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Preview quiz'),
                ),
                OutlinedButton.icon(
                  onPressed: _editable && !_busy ? _editQuiz : null,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit quiz details'),
                ),
                FilledButton.tonalIcon(
                  onPressed: _editable && !_busy ? () => _editQuestion() : null,
                  icon: const Icon(Icons.add),
                  label: const Text('Add question'),
                ),
              ],
            ),
          const SizedBox(height: 8),
          Expanded(
            child: _questions.isEmpty
                ? Center(
                    child: Text(
                      widget.editor
                          ? 'No questions yet.'
                          : 'Question preview is not available.',
                    ),
                  )
                : ListView.builder(
                    itemCount: _questions.length,
                    itemBuilder: (context, index) {
                      final q = _questions[index];
                      return Card(
                        color: TeatroColors.paper,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${index + 1}. ${q.text}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleSmall,
                                    ),
                                  ),
                                  if (_editable)
                                    IconButton(
                                      tooltip: 'Move question up',
                                      onPressed: index == 0 || _busy
                                          ? null
                                          : () => _move(index, -1),
                                      icon: const Icon(
                                        Icons.arrow_upward,
                                        size: 18,
                                      ),
                                    ),
                                  if (_editable)
                                    IconButton(
                                      tooltip: 'Move question down',
                                      onPressed:
                                          index == _questions.length - 1 ||
                                              _busy
                                          ? null
                                          : () => _move(index, 1),
                                      icon: const Icon(
                                        Icons.arrow_downward,
                                        size: 18,
                                      ),
                                    ),
                                  if (_editable)
                                    IconButton(
                                      tooltip: 'Edit question',
                                      onPressed: _busy
                                          ? null
                                          : () => _editQuestion(q),
                                      icon: const Icon(Icons.edit_outlined),
                                    ),
                                ],
                              ),
                              for (final option in q.options)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 8,
                                    top: 3,
                                  ),
                                  child: Text(
                                    '${option.isCorrect == true ? '✓ ' : '○ '}${option.text}',
                                  ),
                                ),
                              if (q.explanation.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    'Explanation: ${q.explanation}',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: TeatroColors.muted),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (!widget.editor && _questions.isNotEmpty)
            const Text(
              'Correct answers and explanations are hidden.',
              style: TextStyle(fontSize: 12, color: TeatroColors.muted),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
    ],
  );
}

class _QuestionValues {
  const _QuestionValues(this.text, this.explanation, this.options);
  final String text;
  final String explanation;
  final List<_OptionValue> options;
}

class _OptionValue {
  const _OptionValue({this.id, required this.text, required this.correct});
  final String? id;
  final String text;
  final bool correct;
}

class _QuestionFormDialog extends StatefulWidget {
  const _QuestionFormDialog({this.question});
  final ManagedQuizQuestion? question;
  @override
  State<_QuestionFormDialog> createState() => _QuestionFormDialogState();
}

class _QuestionFormDialogState extends State<_QuestionFormDialog> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _text, _explanation;
  late List<_OptionEditor> _options;
  int _correct = 0;
  @override
  void initState() {
    super.initState();
    final q = widget.question;
    _text = TextEditingController(text: q?.text);
    _explanation = TextEditingController(text: q?.explanation);
    _options = q == null || q.options.isEmpty
        ? [_OptionEditor(), _OptionEditor()]
        : q.options.map((o) => _OptionEditor(id: o.id, text: o.text)).toList();
    final selected = q?.options.indexWhere((o) => o.isCorrect == true) ?? -1;
    if (selected >= 0) _correct = selected;
  }

  @override
  void dispose() {
    _text.dispose();
    _explanation.dispose();
    for (final o in _options) {
      o.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => StatefulBuilder(
    builder: (context, refresh) => AlertDialog(
      title: Text(widget.question == null ? 'Add question' : 'Edit question'),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _key,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _text,
                  decoration: const InputDecoration(labelText: 'Question'),
                  minLines: 2,
                  maxLines: 4,
                  validator: _required,
                ),
                TextFormField(
                  controller: _explanation,
                  decoration: const InputDecoration(
                    labelText: 'Explanation (shown after submission)',
                  ),
                  minLines: 2,
                  maxLines: 4,
                ),
                const SizedBox(height: 8),
                RadioGroup<int>(
                  groupValue: _correct,
                  onChanged: (value) => setState(() => _correct = value!),
                  child: Column(
                    children: [
                      for (var i = 0; i < _options.length; i++)
                        Row(
                          children: [
                            Radio<int>(value: i),
                            Expanded(
                              child: TextFormField(
                                controller: _options[i].controller,
                                decoration: InputDecoration(
                                  labelText: 'Option ${i + 1}',
                                ),
                                validator: _required,
                              ),
                            ),
                            if (_options.length > 2 && _options[i].id == null)
                              IconButton(
                                tooltip: 'Remove unsaved option',
                                onPressed: () {
                                  setState(() {
                                    _options.removeAt(i).controller.dispose();
                                    if (_correct >= _options.length) {
                                      _correct = _options.length - 1;
                                    }
                                  });
                                  refresh(() {});
                                },
                                icon: const Icon(Icons.remove_circle_outline),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() => _options.add(_OptionEditor()));
                      refresh(() {});
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add option'),
                  ),
                ),
                const Text(
                  'Select exactly one correct option. Saved options cannot be deleted; existing options can be edited.',
                  style: TextStyle(fontSize: 12, color: TeatroColors.muted),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_key.currentState!.validate()) return;
            Navigator.pop(
              context,
              _QuestionValues(_text.text.trim(), _explanation.text.trim(), [
                for (var i = 0; i < _options.length; i++)
                  _OptionValue(
                    id: _options[i].id,
                    text: _options[i].controller.text.trim(),
                    correct: i == _correct,
                  ),
              ]),
            );
          },
          child: const Text('Save question'),
        ),
      ],
    ),
  );
  String? _required(String? v) =>
      v?.trim().isEmpty ?? true ? 'Required.' : null;
}

class _OptionEditor {
  _OptionEditor({this.id, String? text})
    : controller = TextEditingController(text: text);
  final String? id;
  final TextEditingController controller;
}
