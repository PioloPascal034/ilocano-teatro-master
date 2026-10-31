import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../../app/app_theme.dart';
import '../../core/widgets/teatro_widgets.dart';
import 'demo_content.dart';
import 'prototype_widgets.dart';

class ThemeBuilderScreen extends StatefulWidget {
  const ThemeBuilderScreen({
    this.initialInspiration,
    this.initialDraft,
    super.key,
  });

  final String? initialInspiration;
  final DemoDraft? initialDraft;

  @override
  State<ThemeBuilderScreen> createState() => _ThemeBuilderScreenState();
}

class _ThemeBuilderScreenState extends State<ThemeBuilderScreen> {
  static const _steps = [
    'Inspiration',
    'Central Message',
    'Dramatic Conflict',
    'Characters & Audience',
    'Stage Presentation',
    'Review & Save',
  ];

  final _messageController = TextEditingController(
    text: 'Courage grows when a community chooses to help one another.',
  );
  final _conflictController = TextEditingController(
    text:
        'A young leader must ask for help after pride puts their community at risk.',
  );
  final _charactersController = TextEditingController(
    text: 'A young leader, an elder, and their neighbors',
  );
  final _audienceController = TextEditingController(
    text: 'Students and families',
  );
  final _stageController = TextEditingController(
    text: 'A flexible plaza stage with woven textures and live percussion.',
  );
  int _step = 0;
  late String _inspiration;
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    final draft = widget.initialDraft;
    _inspiration =
        widget.initialInspiration ?? draft?.inspiration ?? 'Biag ni Lam-ang';
    if (draft != null) {
      _messageController.text = draft.centralMessage;
      _conflictController.text = draft.conflict;
      _stageController.text = draft.stageConcept;
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _conflictController.dispose();
    _charactersController.dispose();
    _audienceController.dispose();
    _stageController.dispose();
    super.dispose();
  }

  bool _validateStep() {
    final missing = switch (_step) {
      0 => _inspiration.trim().isEmpty,
      1 => _messageController.text.trim().isEmpty,
      2 => _conflictController.text.trim().isEmpty,
      3 =>
        _charactersController.text.trim().isEmpty ||
            _audienceController.text.trim().isEmpty,
      4 => _stageController.text.trim().isEmpty,
      _ => false,
    };
    setState(
      () => _validationMessage = missing
          ? 'Complete this section before continuing.'
          : null,
    );
    return !missing;
  }

  Future<void> _confirmDemoAction(String action) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$action in demo mode?'),
        content: const Text(
          'This prototype does not save drafts or submissions to Supabase.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Continue'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      showDemoMessage(context, '$action was previewed only');
    }
  }

  @override
  Widget build(BuildContext context) => DemoPageBody(
    eyebrow: 'THEME-BUILDING GUIDE',
    title: 'Shape your story’s heart.',
    description:
        'You can explore the six steps here. This prototype does not save your work.',
    child: LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth <= 700;
        return compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _StepGrid(
                    steps: _steps,
                    current: _step,
                    onSelect: (step) => setState(() {
                      _step = step;
                      _validationMessage = null;
                    }),
                  ),
                  const SizedBox(height: 12),
                  _stepCard(context),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 245,
                    child: _StepList(
                      steps: _steps,
                      current: _step,
                      onSelect: (step) => setState(() {
                        _step = step;
                        _validationMessage = null;
                      }),
                    ),
                  ),
                  const SizedBox(width: 17),
                  Expanded(child: _stepCard(context)),
                ],
              );
      },
    ),
  );

  Widget _stepCard(BuildContext context) => TeatroCard(
    padding: const EdgeInsets.all(25),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TeatroEyebrow('STEP ${_step + 1} OF 6'),
        const SizedBox(height: 7),
        Text(_steps[_step], style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 20),
        _stepContent(context),
        if (_validationMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            _validationMessage!,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: TeatroColors.error),
          ),
        ],
        const SizedBox(height: 23),
        const Divider(),
        const SizedBox(height: 13),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 9,
          runSpacing: 9,
          children: [
            DemoActionButton(
              label: 'Save draft',
              icon: Icons.save_outlined,
              onPressed: () => _confirmDemoAction('Save this draft'),
            ),
            Wrap(
              spacing: 8,
              children: [
                if (_step > 0)
                  DemoActionButton(
                    label: 'Previous',
                    icon: Icons.arrow_back,
                    onPressed: () => setState(() {
                      _step--;
                      _validationMessage = null;
                    }),
                  ),
                if (_step < _steps.length - 1)
                  DemoPrimaryButton(
                    label: 'Next',
                    onPressed: () {
                      if (_validateStep()) setState(() => _step++);
                    },
                  )
                else
                  DemoPrimaryButton(
                    label: 'Submit for review',
                    icon: Icons.send_outlined,
                    onPressed: () => _confirmDemoAction('Submit this concept'),
                  ),
              ],
            ),
          ],
        ),
      ],
    ),
  );

  Widget _stepContent(BuildContext context) => switch (_step) {
    0 => _inspirationFields(context),
    1 => _textField(
      'Your central message',
      _messageController,
      'What should the audience carry with them?',
    ),
    2 => _textField(
      'The dramatic conflict',
      _conflictController,
      'What challenge puts the central message to the test?',
    ),
    3 => Column(
      children: [
        _textField(
          'Main characters',
          _charactersController,
          'Who carries the story?',
        ),
        const SizedBox(height: 15),
        TextFormField(
          controller: _audienceController,
          decoration: const InputDecoration(
            labelText: 'Target audience',
            hintText: 'Who is this play for?',
          ),
          minLines: 1,
          maxLines: 2,
        ),
      ],
    ),
    4 => _textField(
      'How will this look and feel on stage?',
      _stageController,
      'Describe the setting, props, and staging approach.',
    ),
    _ => _review(context),
  };

  Widget _inspirationFields(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      DropdownButtonFormField<String>(
        initialValue: _inspiration,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Choose a source of inspiration',
        ),
        items: const [
          DropdownMenuItem(
            value: 'Biag ni Lam-ang',
            child: Text('Biag ni Lam-ang'),
          ),
          DropdownMenuItem(value: 'Angalo', child: Text('Angalo')),
          DropdownMenuItem(
            value: 'My own community story',
            child: Text('My own community story'),
          ),
        ],
        onChanged: (value) =>
            setState(() => _inspiration = value ?? _inspiration),
      ),
      const SizedBox(height: 9),
      Text(
        'Select a verified source, or use an original idea. Cultural stories should be adapted with context and respect.',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: TeatroColors.muted),
      ),
    ],
  );

  Widget _textField(
    String label,
    TextEditingController controller,
    String hint,
  ) => TextFormField(
    controller: controller,
    decoration: InputDecoration(labelText: label, hintText: hint),
    minLines: 3,
    maxLines: 6,
  );

  Widget _review(BuildContext context) => TeatroCard(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your theater concept',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        _ReviewItem('Inspiration', _inspiration),
        _ReviewItem('Central message', _messageController.text),
        _ReviewItem('Dramatic conflict', _conflictController.text),
        _ReviewItem('Characters', _charactersController.text),
        _ReviewItem('Target audience', _audienceController.text),
        _ReviewItem('Stage presentation', _stageController.text),
        const DemoStatus(status: 'Draft · demo'),
      ],
    ),
  );
}

class _StepList extends StatelessWidget {
  const _StepList({
    required this.steps,
    required this.current,
    required this.onSelect,
  });
  final List<String> steps;
  final int current;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => TeatroCard(
    padding: const EdgeInsets.all(11),
    child: Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          Material(
            color: Colors.transparent,
            child: ListTile(
              dense: true,
              selected: current == i,
              selectedTileColor: const Color(0xFFF4E9E1),
              leading: CircleAvatar(
                radius: 14,
                backgroundColor: i < current
                    ? const Color(0xFFE8EFE1)
                    : Colors.transparent,
                child: i < current
                    ? const Icon(
                        Icons.check,
                        color: TeatroColors.success,
                        size: 16,
                      )
                    : Text(
                        '${i + 1}'.padLeft(2, '0'),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
              ),
              title: Text(
                steps[i],
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: current == i ? TeatroColors.rust : TeatroColors.ink,
                ),
              ),
              onTap: () => onSelect(i),
            ),
          ),
      ],
    ),
  );
}

class _StepGrid extends StatelessWidget {
  const _StepGrid({
    required this.steps,
    required this.current,
    required this.onSelect,
  });
  final List<String> steps;
  final int current;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 7,
    runSpacing: 7,
    children: [
      for (var i = 0; i < steps.length; i++)
        ActionChip(
          avatar: Text(
            '${i + 1}'.padLeft(2, '0'),
            style: Theme.of(context).textTheme.labelSmall,
          ),
          label: Text(steps[i]),
          onPressed: () => onSelect(i),
          backgroundColor: current == i
              ? const Color(0xFFF4E9E1)
              : TeatroColors.paper,
          side: BorderSide(
            color: current == i ? const Color(0xFFE6CDBD) : TeatroColors.line,
          ),
        ),
    ],
  );
}

class _ReviewItem extends StatelessWidget {
  const _ReviewItem(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TeatroEyebrow(label),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.bodyMedium),
      ],
    ),
  );
}

class DraftsScreen extends StatelessWidget {
  const DraftsScreen({
    required this.onNavigate,
    required this.onOpenSubmission,
    required this.onOpenBuilder,
    super.key,
  });
  final ValueChanged<AppDestination> onNavigate;
  final void Function(AppDestination, Object?) onOpenSubmission;
  final void Function(AppDestination, Object?) onOpenBuilder;

  @override
  Widget build(BuildContext context) => DemoPageBody(
    eyebrow: 'YOUR CONCEPTS',
    title: 'My drafts & submissions',
    child: Column(
      children: [
        for (final draft in demoDrafts)
          Padding(
            padding: const EdgeInsets.only(bottom: 13),
            child: _DraftCard(
              draft: draft,
              onEdit: () => onOpenBuilder(AppDestination.themeBuilder, draft),
              onDetails: () =>
                  onOpenSubmission(AppDestination.submissionReview, draft),
            ),
          ),
      ],
    ),
  );
}

class _DraftCard extends StatelessWidget {
  const _DraftCard({
    required this.draft,
    required this.onEdit,
    required this.onDetails,
  });
  final DemoDraft draft;
  final VoidCallback onEdit;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) => TeatroCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const TeatroEyebrow('THEATER CONCEPT'),
                  const SizedBox(height: 4),
                  Text(
                    draft.title,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Inspired by ${draft.inspiration} · ${draft.lastUpdated}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: TeatroColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            DemoStatus(status: draft.status),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          draft.centralMessage,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: TeatroColors.muted),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (draft.status == 'Draft' || draft.status == 'Revision Requested')
              DemoPrimaryButton(
                label: draft.status == 'Draft'
                    ? 'Edit draft'
                    : 'Revise & resubmit',
                icon: Icons.edit_outlined,
                onPressed: onEdit,
              ),
            DemoActionButton(
              label: 'View details',
              icon: Icons.visibility_outlined,
              onPressed: onDetails,
            ),
            if (draft.status == 'Draft')
              TextButton.icon(
                onPressed: () =>
                    showDemoMessage(context, 'submission was previewed only'),
                icon: const Icon(Icons.send_outlined, size: 15),
                label: const Text('Submit for review'),
              ),
          ],
        ),
      ],
    ),
  );
}

class StudentSubmissionDetailsScreen extends StatelessWidget {
  const StudentSubmissionDetailsScreen({
    required this.draft,
    required this.onBack,
    required this.onEdit,
    super.key,
  });
  final DemoDraft draft;
  final VoidCallback onBack;
  final void Function(AppDestination, Object?) onEdit;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 920),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DemoBackButton(label: 'My drafts', onPressed: onBack),
        const DemoDataNotice(),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TeatroEyebrow(
                    '${draft.student.toUpperCase()} · GRADE 10',
                    color: TeatroColors.rust,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    draft.title,
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                  Text(
                    '${draft.lastUpdated} · Inspired by ${draft.inspiration}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: TeatroColors.muted),
                  ),
                ],
              ),
            ),
            DemoStatus(status: draft.status),
          ],
        ),
        const SizedBox(height: 18),
        TeatroCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Student concept',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              _ConceptDetail(
                label: 'Central message',
                value: draft.centralMessage,
              ),
              _ConceptDetail(label: 'Dramatic conflict', value: draft.conflict),
              _ConceptDetail(
                label: 'Stage presentation',
                value: draft.stageConcept,
              ),
              const Divider(height: 27),
              Text(
                'Reviewer feedback',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'Sample feedback is shown for layout preview only. Real review feedback is not connected in this phase.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: TeatroColors.muted),
              ),
            ],
          ),
        ),
        if (draft.status == 'Revision Requested') ...[
          const SizedBox(height: 14),
          DemoPrimaryButton(
            label: 'Edit this concept',
            icon: Icons.edit_outlined,
            onPressed: () => onEdit(AppDestination.themeBuilder, draft),
          ),
        ],
      ],
    ),
  );
}

class _ConceptDetail extends StatelessWidget {
  const _ConceptDetail({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TeatroEyebrow(label),
        const SizedBox(height: 5),
        Text(value, style: Theme.of(context).textTheme.bodyMedium),
      ],
    ),
  );
}
