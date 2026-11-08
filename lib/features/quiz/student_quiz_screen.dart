import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/app_routes.dart';
import '../../app/app_theme.dart';
import '../../core/widgets/teatro_widgets.dart';
import '../../core/widgets/teatro_design_widgets.dart';
import 'data/quiz_repository.dart';
import 'models/quiz_models.dart';

class StudentQuizScreen extends StatefulWidget {
  const StudentQuizScreen({
    required this.repository,
    required this.onNavigate,
    this.initialQuizId,
    super.key,
  });

  final QuizRepository repository;
  final ValueChanged<AppDestination> onNavigate;
  final String? initialQuizId;

  @override
  State<StudentQuizScreen> createState() => _StudentQuizScreenState();
}

class _StudentQuizScreenState extends State<StudentQuizScreen> {
  late Future<_QuizHomeData> _homeFuture;
  String? _selectedQuizId;
  Future<StudentQuiz?>? _quizFuture;
  final Map<String, String> _answers = {};
  int _questionIndex = 0;
  bool _reviewing = false;
  bool _submitting = false;
  QuizResult? _result;
  String? _submissionError;

  @override
  void initState() {
    super.initState();
    _homeFuture = _loadHome();
    final initialQuizId = widget.initialQuizId;
    if (initialQuizId != null) _openQuiz(initialQuizId);
  }

  @override
  void didUpdateWidget(covariant StudentQuizScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      _homeFuture = _loadHome();
      final quizId = _selectedQuizId;
      _quizFuture = quizId == null ? null : _loadQuiz(quizId);
    }
  }

  Future<_QuizHomeData> _loadHome() async {
    final values = await Future.wait<Object>([
      widget.repository.loadAvailableQuizzes(),
      widget.repository.loadMyAttempts(),
    ]);
    return _QuizHomeData(
      quizzes: values[0] as List<AvailableQuiz>,
      attempts: values[1] as List<QuizAttempt>,
    );
  }

  void _retryHome() {
    setState(() {
      _homeFuture = _loadHome();
    });
  }

  void _openQuiz(String quizId) {
    setState(() {
      _selectedQuizId = quizId;
      _quizFuture = _loadQuiz(quizId);
      _answers.clear();
      _questionIndex = 0;
      _reviewing = false;
      _result = null;
      _submissionError = null;
    });
  }

  Future<StudentQuiz?> _loadQuiz(String quizId) {
    final future = widget.repository.loadQuiz(quizId);
    unawaited(
      future.then<void>(
        (_) {},
        onError: (Object error, StackTrace stackTrace) {},
      ),
    );
    return future;
  }

  void _backToQuizzes() => setState(() {
    _selectedQuizId = null;
    _quizFuture = null;
    _answers.clear();
    _questionIndex = 0;
    _reviewing = false;
    _result = null;
    _submissionError = null;
    _homeFuture = _loadHome();
  });

  Future<void> _submit(StudentQuiz quiz) async {
    if (_answers.length != quiz.questions.length) {
      setState(
        () => _submissionError = 'Answer every question before submitting.',
      );
      return;
    }
    setState(() {
      _submitting = true;
      _submissionError = null;
    });
    try {
      final result = await widget.repository.submitAnswers(
        quizId: quiz.quiz.id,
        answersByQuestion: Map.unmodifiable(_answers),
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _submitting = false;
        _homeFuture = _loadHome();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submissionError = _errorText(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_QuizHomeData>(
    future: _homeFuture,
    builder: (context, snapshot) {
      if (snapshot.hasError && _selectedQuizId == null) {
        return _PageState(
          title: 'Knowledge checks could not be loaded',
          message: _errorText(snapshot.error!),
          action: TextButton.icon(
            onPressed: _retryHome,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        );
      }
      if (_selectedQuizId != null) return _selectedQuizPage(context);
      if (!snapshot.hasData) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(40),
            child: CircularProgressIndicator(),
          ),
        );
      }
      return _quizListPage(context, snapshot.data!);
    },
  );

  Widget _quizListPage(BuildContext context, _QuizHomeData data) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TeatroPageIntro(
        eyebrow: 'KNOWLEDGE CHECKS',
        title: 'Test your understanding',
        description: 'Choose a published quiz from your learning modules.',
      ),
      if (data.quizzes.isEmpty)
        const TeatroCard(
          child: Column(
            children: [
              Icon(Icons.quiz_outlined, size: 30, color: TeatroColors.muted),
              SizedBox(height: 9),
              Text('Quiz content is not yet available'),
              SizedBox(height: 4),
              Text(
                'Published quizzes will appear here when your teacher adds them.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        )
      else
        for (final quiz in data.quizzes)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _QuizCard(
              quiz: quiz,
              attempts: data.attempts
                  .where((attempt) => attempt.quizId == quiz.id)
                  .toList(),
              onStart: () => _openQuiz(quiz.id),
            ),
          ),
      if (data.attempts.isNotEmpty) ...[
        const SizedBox(height: 17),
        const TeatroSectionTitle(
          eyebrow: 'SAVED RESULTS',
          title: 'Previous attempts',
        ),
        TeatroCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final attempt in data.attempts)
                ListTile(
                  leading: const Icon(
                    Icons.check_circle_outline,
                    color: TeatroColors.moss,
                  ),
                  title: Text('Quiz attempt ${attempt.id.substring(0, 8)}'),
                  subtitle: Text(_dateLabel(attempt.completedAt)),
                  trailing: Text('${attempt.score.toStringAsFixed(1)}%'),
                ),
            ],
          ),
        ),
      ],
    ],
  );

  Widget _selectedQuizPage(BuildContext context) => FutureBuilder<StudentQuiz?>(
    future: _quizFuture,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _PageState(
          title: 'Quiz could not be loaded',
          message: _errorText(snapshot.error!),
          action: TextButton.icon(
            onPressed: () => _openQuiz(_selectedQuizId!),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        );
      }
      if (!snapshot.hasData) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(40),
            child: CircularProgressIndicator(),
          ),
        );
      }
      final quiz = snapshot.data;
      if (quiz == null || quiz.questions.isEmpty) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TeatroBackButton(
              label: 'Knowledge checks',
              onPressed: _backToQuizzes,
            ),
            const TeatroEmptyState(
              title: 'Quiz content is not yet available',
              description:
                  'This published quiz has no available questions yet.',
              icon: Icons.quiz_outlined,
            ),
          ],
        );
      }
      if (_result case final result?) return _resultPage(context, quiz, result);
      if (_reviewing) return _reviewPage(context, quiz);
      return _questionPage(context, quiz);
    },
  );

  Widget _questionPage(BuildContext context, StudentQuiz quiz) {
    final question = quiz.questions[_questionIndex];
    final selected = _answers[question.id];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TeatroBackButton(
          label: 'All knowledge checks',
          onPressed: _backToQuizzes,
        ),
        TeatroPageIntro(
          eyebrow: 'KNOWLEDGE CHECK · ${quiz.quiz.moduleTitle.toUpperCase()}',
          title: quiz.quiz.title,
          description:
              'Question ${_questionIndex + 1} of ${quiz.questions.length}',
        ),
        LinearProgressIndicator(
          value: (_questionIndex + 1) / quiz.questions.length,
          color: TeatroColors.rust,
          backgroundColor: TeatroColors.line,
        ),
        const SizedBox(height: 18),
        TeatroCard(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TeatroEyebrow(
                'QUESTION ${(_questionIndex + 1).toString().padLeft(2, '0')}',
                color: TeatroColors.rust,
              ),
              const SizedBox(height: 8),
              Text(
                question.text,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 17),
              if (question.options.isEmpty)
                const Text('Quiz content is not yet available')
              else
                for (var index = 0; index < question.options.length; index++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _QuizOptionTile(
                      letter: String.fromCharCode(65 + index),
                      text: question.options[index].text,
                      selected: selected == question.options[index].id,
                      enabled: true,
                      onTap: () => setState(
                        () =>
                            _answers[question.id] = question.options[index].id,
                      ),
                    ),
                  ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  TeatroActionButton(
                    label: 'Previous',
                    icon: Icons.arrow_back,
                    onPressed: _questionIndex == 0
                        ? null
                        : () => setState(() => _questionIndex--),
                  ),
                  DesignPrimaryButton(
                    label: _questionIndex == quiz.questions.length - 1
                        ? 'Review answers'
                        : 'Next question',
                    icon: Icons.arrow_forward,
                    onPressed: question.options.isEmpty
                        ? null
                        : () => setState(() {
                            if (_questionIndex == quiz.questions.length - 1) {
                              _reviewing = true;
                            } else {
                              _questionIndex++;
                            }
                          }),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _reviewPage(BuildContext context, StudentQuiz quiz) {
    final unanswered = quiz.questions
        .where((question) => !_answers.containsKey(question.id))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TeatroBackButton(
          label: 'Back to questions',
          onPressed: () => setState(() {
            _reviewing = false;
            _questionIndex = unanswered.isEmpty
                ? quiz.questions.length - 1
                : quiz.questions.indexOf(unanswered.first);
          }),
        ),
        TeatroPageIntro(
          eyebrow: 'FINAL CHECK',
          title: 'Review your answers',
          description: quiz.quiz.title,
        ),
        TeatroCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var index = 0; index < quiz.questions.length; index++)
                ListTile(
                  leading: CircleAvatar(
                    radius: 15,
                    backgroundColor: unanswered.contains(quiz.questions[index])
                        ? const Color(0xFFF4EEE0)
                        : const Color(0xFFE9EFE7),
                    child: Text('${index + 1}'),
                  ),
                  title: Text(quiz.questions[index].text),
                  subtitle: Text(
                    _selectedOptionText(quiz.questions[index]) ??
                        'Not answered',
                  ),
                  trailing: TextButton(
                    onPressed: () => setState(() {
                      _reviewing = false;
                      _questionIndex = index;
                    }),
                    child: const Text('Change'),
                  ),
                ),
            ],
          ),
        ),
        if (unanswered.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              'Answer all ${unanswered.length} remaining question(s) before submitting.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: TeatroColors.rust),
            ),
          ),
        if (_submissionError != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              _submissionError!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: TeatroColors.error),
            ),
          ),
        if (_submitting) const LinearProgressIndicator(),
        const SizedBox(height: 12),
        DesignPrimaryButton(
          label: _submitting ? 'Submitting…' : 'Submit quiz',
          icon: Icons.check,
          onPressed: unanswered.isNotEmpty || _submitting
              ? null
              : () => _submit(quiz),
        ),
      ],
    );
  }

  Widget _resultPage(
    BuildContext context,
    StudentQuiz quiz,
    QuizResult result,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TeatroCard(
        child: Column(
          children: [
            const Icon(
              Icons.emoji_events_outlined,
              size: 40,
              color: TeatroColors.gold,
            ),
            const SizedBox(height: 10),
            const TeatroEyebrow('QUIZ RESULT'),
            const SizedBox(height: 5),
            Text(
              '${result.score.toStringAsFixed(1)}%',
              style: Theme.of(context).textTheme.displayLarge,
            ),
            Text(
              '${result.correctAnswers} of ${result.totalQuestions} correct',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 5),
            Text(
              'Passing score: ${quiz.quiz.passingScore}%',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: TeatroColors.muted),
            ),
            const SizedBox(height: 17),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TeatroActionButton(
                  label: 'Knowledge checks',
                  icon: Icons.quiz_outlined,
                  onPressed: _backToQuizzes,
                ),
                DesignPrimaryButton(
                  label: 'My progress',
                  icon: Icons.bar_chart,
                  onPressed: () => widget.onNavigate(AppDestination.progress),
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  );

  String? _selectedOptionText(QuizQuestion question) {
    final selectedId = _answers[question.id];
    if (selectedId == null) return null;
    for (final option in question.options) {
      if (option.id == selectedId) return option.text;
    }
    return null;
  }
}

class _QuizHomeData {
  const _QuizHomeData({required this.quizzes, required this.attempts});
  final List<AvailableQuiz> quizzes;
  final List<QuizAttempt> attempts;
}

class _QuizCard extends StatelessWidget {
  const _QuizCard({
    required this.quiz,
    required this.attempts,
    required this.onStart,
  });

  final AvailableQuiz quiz;
  final List<QuizAttempt> attempts;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) => TeatroCard(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final info = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TeatroEyebrow('MODULE · ${quiz.moduleTitle.toUpperCase()}'),
            const SizedBox(height: 4),
            Text(quiz.title, style: Theme.of(context).textTheme.titleLarge),
            if (quiz.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                quiz.description,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (attempts.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(
                '${attempts.length} saved attempt(s) · Latest ${attempts.first.score.toStringAsFixed(1)}%',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: TeatroColors.muted),
              ),
            ],
          ],
        );
        final button = DesignPrimaryButton(
          label: attempts.isEmpty ? 'Start quiz' : 'Try again',
          icon: Icons.arrow_forward,
          onPressed: onStart,
        );
        return constraints.maxWidth < 560
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [info, const SizedBox(height: 10), button],
              )
            : Row(
                children: [
                  Expanded(child: info),
                  const SizedBox(width: 12),
                  button,
                ],
              );
      },
    ),
  );
}

class _QuizOptionTile extends StatelessWidget {
  const _QuizOptionTile({
    required this.letter,
    required this.text,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String letter;
  final String text;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? TeatroColors.rust : TeatroColors.line;
    return Material(
      color: selected ? const Color(0xFFFFF9F4) : TeatroColors.paper,
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(7),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: color),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: color.withValues(alpha: .13),
                child: Text(
                  letter,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageState extends StatelessWidget {
  const _PageState({required this.title, required this.message, this.action});
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => TeatroCard(
    child: Column(
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(message, textAlign: TextAlign.center),
        ?action,
      ],
    ),
  );
}

String _dateLabel(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '$month/$day/${local.year}';
}

String _errorText(Object error) {
  if (error is StateError) return error.message;
  if (error is PostgrestException) return error.message;
  if (error is ArgumentError) {
    return error.message?.toString() ?? 'Check your answers.';
  }
  return 'Please check your connection and try again.';
}
