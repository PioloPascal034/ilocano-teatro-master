import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/app_routes.dart';
import '../../app/app_theme.dart';
import '../../core/widgets/teatro_widgets.dart';
import '../prototype/prototype_widgets.dart';
import 'data/theme_draft_repository.dart';

class ThemeBuilderScreen extends StatefulWidget {
  const ThemeBuilderScreen({
    required this.repository,
    this.initialDraftId,
    this.initialInspiration,
    this.onSubmitted,
    super.key,
  });

  final ThemeDraftRepository repository;
  final String? initialDraftId;
  final String? initialInspiration;
  final VoidCallback? onSubmitted;

  @override
  State<ThemeBuilderScreen> createState() => _ThemeBuilderScreenState();
}

class _ThemeBuilderScreenState extends State<ThemeBuilderScreen> {
  static const _steps = [
    'Cultural inspiration',
    'Central message',
    'Dramatic conflict',
    'Characters and audience',
    'Stage presentation',
    'Review and save',
  ];

  final _title = TextEditingController();
  final _message = TextEditingController();
  final _conflict = TextEditingController();
  final _characters = TextEditingController();
  final _audience = TextEditingController();
  final _stage = TextEditingController();
  final _acknowledgment = TextEditingController();
  late Future<List<CulturalInspiration>> _inspirations;
  String? _storyId;
  String? _draftId;
  String? _error;
  bool _loading = false;
  bool _saving = false;
  int _step = 0;

  @override
  void initState() {
    super.initState();
    _draftId = widget.initialDraftId;
    _inspirations = widget.repository.listInspirations();
    if (_draftId != null) _restoreDraft();
    if (widget.initialInspiration != null) {
      _inspirations.then((stories) {
        if (!mounted) return;
        final found = stories.where((s) => s.title == widget.initialInspiration);
        if (found.isNotEmpty) setState(() => _storyId = found.first.id);
      });
    }
  }

  Future<void> _restoreDraft() async {
    setState(() => _loading = true);
    try {
      final draft = await widget.repository.getDraft(_draftId!);
      if (!mounted) return;
      _title.text = draft.title;
      _storyId = draft.storyId;
      _message.text = draft.centralMessage ?? '';
      _conflict.text = draft.dramaticConflict ?? '';
      _characters.text = draft.characters ?? '';
      _audience.text = draft.targetAudience ?? '';
      _stage.text = draft.stageConcept ?? '';
      _acknowledgment.text = draft.sourceAcknowledgment ?? '';
    } catch (error) {
      _error = _friendlyError(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    _conflict.dispose();
    _characters.dispose();
    _audience.dispose();
    _stage.dispose();
    _acknowledgment.dispose();
    super.dispose();
  }

  bool _validateStep() {
    final valid = switch (_step) {
      0 => _title.text.trim().isNotEmpty,
      1 => _message.text.trim().isNotEmpty,
      2 => _conflict.text.trim().isNotEmpty,
      3 => _characters.text.trim().isNotEmpty && _audience.text.trim().isNotEmpty,
      4 => _stage.text.trim().isNotEmpty,
      _ => true,
    };
    setState(() => _error = valid ? null : 'Complete the required fields to continue.');
    return valid;
  }

  ThemeDraft _currentDraft() => ThemeDraft(
    id: _draftId ?? '',
    title: _title.text,
    status: 'draft',
    updatedAt: DateTime.now(),
    storyId: _storyId,
    centralMessage: _message.text,
    dramaticConflict: _conflict.text,
    characters: _characters.text,
    targetAudience: _audience.text,
    stageConcept: _stage.text,
    sourceAcknowledgment: _acknowledgment.text,
  );

  Future<ThemeDraft?> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await widget.repository.saveDraft(_currentDraft());
      _draftId = saved.id;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Draft saved.')),
        );
      }
      return saved;
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
      return null;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _submit() async {
    if (!_validateStep()) return;
    final saved = await _save();
    if (saved == null || !mounted) return;
    try {
      await widget.repository.submitDraft(saved.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Theme submitted for review.')),
      );
      widget.onSubmitted?.call();
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const DemoPageIntro(
        eyebrow: 'THEME-BUILDING GUIDE',
        title: 'Shape your story’s heart.',
        description: 'Build your theater concept one step at a time. Your work stays in this form if a save fails.',
      ),
      if (_error != null) _ErrorNotice(message: _error!, onRetry: _draftId == null ? null : _restoreDraft),
      if (_loading)
        const Center(child: Padding(padding: EdgeInsets.all(36), child: CircularProgressIndicator()))
      else
        LayoutBuilder(builder: (context, constraints) {
          final compact = constraints.maxWidth <= 700;
          final steps = compact
              ? _StepChips(steps: _steps, current: _step, onSelect: (i) => setState(() => _step = i))
              : SizedBox(width: 245, child: _StepList(steps: _steps, current: _step, onSelect: (i) => setState(() => _step = i)));
          final card = _stepCard(context);
          return compact
              ? Column(children: [steps, const SizedBox(height: 12), card])
              : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [steps, const SizedBox(width: 17), Expanded(child: card)]);
        }),
    ],
  );

  Widget _stepCard(BuildContext context) => TeatroCard(
    padding: const EdgeInsets.all(25),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TeatroEyebrow('STEP ${_step + 1} OF 6'),
      const SizedBox(height: 7),
      Text(_steps[_step], style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 20),
      switch (_step) {
        0 => _inspirationFields(),
        1 => _field('Your central message', _message, 'What should the audience carry with them?'),
        2 => _field('The dramatic conflict', _conflict, 'What challenge puts the message to the test?'),
        3 => Column(children: [_field('Main characters', _characters, 'Who carries the story?'), const SizedBox(height: 15), _field('Target audience', _audience, 'Who is this play for?')]),
        4 => _field('How will this look and feel on stage?', _stage, 'Describe the setting, props, and staging.'),
        _ => _review(context),
      },
      const SizedBox(height: 23),
      const Divider(),
      const SizedBox(height: 13),
      Wrap(alignment: WrapAlignment.spaceBetween, spacing: 9, runSpacing: 9, children: [
        OutlinedButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.save_outlined), label: Text(_saving ? 'Saving…' : 'Save draft')),
        Wrap(spacing: 8, children: [
          if (_step > 0) TextButton.icon(onPressed: () => setState(() => _step--), icon: const Icon(Icons.arrow_back), label: const Text('Previous')),
          if (_step < 5) FilledButton(onPressed: () { if (_validateStep()) setState(() => _step++); }, child: const Text('Next'))
          else FilledButton.icon(onPressed: _saving ? null : _submit, icon: const Icon(Icons.send_outlined), label: const Text('Submit for review')),
        ]),
      ]),
    ]),
  );

  Widget _inspirationFields() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    TextField(controller: _title, decoration: const InputDecoration(labelText: 'Theme title', hintText: 'Name your theater concept')),
    const SizedBox(height: 15),
    FutureBuilder<List<CulturalInspiration>>(
      future: _inspirations,
      builder: (context, snapshot) {
        if (snapshot.hasError) return _ErrorNotice(message: 'Published cultural inspirations could not be loaded.');
        if (!snapshot.hasData) return const LinearProgressIndicator();
        final stories = snapshot.data!;
        return DropdownButtonFormField<String?>(
          initialValue: _storyId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Choose a cultural inspiration'),
          items: [const DropdownMenuItem<String?>(value: null, child: Text('My own community story')), ...stories.map((story) => DropdownMenuItem<String?>(value: story.id, child: Text(story.title)))],
          onChanged: (value) => setState(() { _storyId = value; if (value == null) _acknowledgment.clear(); }),
        );
      },
    ),
    const SizedBox(height: 15),
    _field('Source acknowledgment', _acknowledgment, 'Optional attribution or adaptation notes'),
    const SizedBox(height: 8),
    Text('Choose a published source or use an original community story.', style: TextStyle(color: TeatroColors.muted)),
  ]);

  Widget _field(String label, TextEditingController controller, String hint) => TextField(
    controller: controller,
    decoration: InputDecoration(labelText: label, hintText: hint),
    minLines: 3,
    maxLines: 6,
  );

  Widget _review(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    _ReviewItem('Theme title', _title.text),
    _ReviewItem('Central message', _message.text),
    _ReviewItem('Dramatic conflict', _conflict.text),
    _ReviewItem('Characters', _characters.text),
    _ReviewItem('Target audience', _audience.text),
    _ReviewItem('Stage presentation', _stage.text),
    if (_acknowledgment.text.trim().isNotEmpty) _ReviewItem('Source acknowledgment', _acknowledgment.text),
  ]);
}

class StudentDraftsScreen extends StatefulWidget {
  const StudentDraftsScreen({required this.repository, required this.onOpenBuilder, super.key});
  final ThemeDraftRepository repository;
  final ValueChanged<String> onOpenBuilder;

  @override
  State<StudentDraftsScreen> createState() => _StudentDraftsScreenState();
}

class _StudentDraftsScreenState extends State<StudentDraftsScreen> {
  late Future<List<ThemeDraft>> _future;
  @override
  void initState() { super.initState(); _future = widget.repository.listDrafts(); }
  void _reload() => setState(() => _future = widget.repository.listDrafts());

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    DemoPageIntro(eyebrow: 'YOUR CONCEPTS', title: 'My drafts & submissions', trailing: FilledButton.icon(onPressed: () => widget.onOpenBuilder(''), icon: const Icon(Icons.add), label: const Text('New theme'))),
    FutureBuilder<List<ThemeDraft>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) return _ErrorNotice(message: _friendlyError(snapshot.error!), onRetry: _reload);
        if (!snapshot.hasData) return const Center(child: Padding(padding: EdgeInsets.all(36), child: CircularProgressIndicator()));
        if (snapshot.data!.isEmpty) return TeatroCard(child: Column(children: [const Icon(Icons.auto_stories_outlined, size: 30, color: TeatroColors.muted), const SizedBox(height: 10), Text('No drafts yet', style: Theme.of(context).textTheme.titleMedium), const Text('Start a theme and your saved work will appear here.'), const SizedBox(height: 12), FilledButton(onPressed: () => widget.onOpenBuilder(''), child: const Text('Start a theme'))]));
        return Column(children: [for (final draft in snapshot.data!) Padding(padding: const EdgeInsets.only(bottom: 13), child: _DraftCard(repository: widget.repository, draft: draft, onEdit: () => widget.onOpenBuilder(draft.id), onRefresh: _reload))]);
      },
    ),
  ]);
}

class _DraftCard extends StatefulWidget {
  const _DraftCard({required this.repository, required this.draft, required this.onEdit, required this.onRefresh});
  final ThemeDraftRepository repository;
  final ThemeDraft draft;
  final VoidCallback onEdit;
  final VoidCallback onRefresh;
  @override
  State<_DraftCard> createState() => _DraftCardState();
}

class _DraftCardState extends State<_DraftCard> {
  bool _busy = false;
  String? _error;
  Future<void> _submit() async {
    setState(() { _busy = true; _error = null; });
    try {
      await widget.repository.submitDraft(widget.draft.id);
      widget.onRefresh();
    } catch (error) { setState(() => _error = _friendlyError(error)); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  @override
  Widget build(BuildContext context) => TeatroCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [Expanded(child: Text(widget.draft.title, style: Theme.of(context).textTheme.headlineMedium)), TeatroStatusIndicator(label: _status(widget.draft.status), tone: _tone(widget.draft.status))]),
    const SizedBox(height: 5),
    Text(widget.draft.inspiration == null ? 'Updated ${_date(widget.draft.updatedAt)}' : 'Inspired by ${widget.draft.inspiration} · Updated ${_date(widget.draft.updatedAt)}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: TeatroColors.muted)),
    if (widget.draft.centralMessage?.trim().isNotEmpty == true) ...[const SizedBox(height: 12), Text(widget.draft.centralMessage!)],
    ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: const Text('View full draft details'),
      children: [
        _ReviewItem('Dramatic conflict', widget.draft.dramaticConflict ?? ''),
        _ReviewItem('Characters', widget.draft.characters ?? ''),
        _ReviewItem('Target audience', widget.draft.targetAudience ?? ''),
        _ReviewItem('Stage presentation', widget.draft.stageConcept ?? ''),
        if (widget.draft.sourceAcknowledgment?.trim().isNotEmpty == true)
          _ReviewItem('Source acknowledgment', widget.draft.sourceAcknowledgment!),
      ],
    ),
    if (widget.draft.submissions.isNotEmpty) ...[
      const Divider(height: 24), Text('Submission history', style: Theme.of(context).textTheme.titleMedium),
      for (final submission in widget.draft.submissions) Padding(padding: const EdgeInsets.only(top: 9), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Version ${submission.version} · ${_status(submission.status)} · ${_date(submission.submittedAt)}'), if (submission.feedback?.isNotEmpty == true) Text('Teacher feedback: ${submission.feedback}')]))
    ],
    if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: TeatroColors.error))),
    const SizedBox(height: 12), Wrap(spacing: 8, children: [
      if (widget.draft.editable) OutlinedButton.icon(onPressed: widget.onEdit, icon: const Icon(Icons.edit_outlined), label: const Text('Continue editing')),
      if (widget.draft.status == 'draft') FilledButton.tonalIcon(onPressed: _busy ? null : _submit, icon: const Icon(Icons.send_outlined), label: Text(_busy ? 'Submitting…' : 'Submit for review')),
    ]),
  ]));
}

class _StepChips extends StatelessWidget {
  const _StepChips({required this.steps, required this.current, required this.onSelect});
  final List<String> steps;
  final int current;
  final ValueChanged<int> onSelect;
  @override
  Widget build(BuildContext context) => Wrap(spacing: 7, runSpacing: 7, children: [for (var i = 0; i < steps.length; i++) ActionChip(label: Text('${i + 1}. ${steps[i]}'), onPressed: () => onSelect(i), backgroundColor: current == i ? const Color(0xFFF4E9E1) : TeatroColors.paper)]);
}

class _StepList extends StatelessWidget {
  const _StepList({required this.steps, required this.current, required this.onSelect});
  final List<String> steps;
  final int current;
  final ValueChanged<int> onSelect;
  @override
  Widget build(BuildContext context) => TeatroCard(padding: const EdgeInsets.all(11), child: Column(children: [for (var i = 0; i < steps.length; i++) ListTile(dense: true, selected: i == current, title: Text('${i + 1}. ${steps[i]}'), onTap: () => onSelect(i))]));
}

class _ReviewItem extends StatelessWidget {
  const _ReviewItem(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [TeatroEyebrow(label), const SizedBox(height: 4), Text(value.isEmpty ? 'Not provided' : value)]));
}

class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice({required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => TeatroCard(child: Row(children: [const Icon(Icons.cloud_off_outlined, color: TeatroColors.rust), const SizedBox(width: 10), Expanded(child: Text(message)), if (onRetry != null) TextButton(onPressed: onRetry, child: const Text('Retry'))]));
}

String _friendlyError(Object error) {
  if (error is StateError) return error.message;
  if (error is PostgrestException) return error.message;
  if (error is AuthException) return 'Your session may have expired. Sign in again and retry.';
  return 'We could not complete that request. Your entered text is still here; please retry.';
}

String _status(String value) => switch (value) {
  'revision_requested' => 'Revision requested',
  'under_review' => 'Under review',
  'approved' => 'Approved',
  'submitted' => 'Submitted',
  _ => 'Draft',
};

TeatroStatusTone _tone(String status) => switch (status) {
  'approved' => TeatroStatusTone.approved,
    'revision_requested' => TeatroStatusTone.revision,
  'submitted' || 'under_review' => TeatroStatusTone.inProgress,
  _ => TeatroStatusTone.neutral,
};

String _date(DateTime date) => '${date.day} ${const ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][date.month - 1]} ${date.year}';
