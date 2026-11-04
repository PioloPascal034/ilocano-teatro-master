import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/app_routes.dart';
import '../../app/app_theme.dart';
import '../../core/widgets/teatro_design_widgets.dart';
import '../../core/widgets/teatro_widgets.dart';
import 'class_assignment.dart';
import 'user_profile_repository.dart';

class ClassAssignmentPanel extends StatefulWidget {
  const ClassAssignmentPanel({
    required this.role,
    required this.repository,
    super.key,
  });

  final AppRole role;
  final UserProfileRepository repository;

  @override
  State<ClassAssignmentPanel> createState() => _ClassAssignmentPanelState();
}

class _ClassAssignmentPanelState extends State<ClassAssignmentPanel> {
  final _codeController = TextEditingController();
  TeacherConnection? _connection;
  ActiveClassCode? _activeCode;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String? _message;

  bool get _student => widget.role == AppRole.student;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
      _message = null;
    });
    try {
      if (_student) {
        _connection = await widget.repository.loadTeacherConnection();
      } else {
        _activeCode = await widget.repository.loadActiveClassCode();
      }
    } catch (error) {
      _error = _messageFor(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _generateCode() async {
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      _activeCode = await widget.repository.generateClassCode();
      _message = 'New class code generated. Existing students remain assigned.';
    } catch (error) {
      _error = _messageFor(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _revokeCode() async {
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      await widget.repository.revokeClassCode();
      _activeCode = null;
      _message = 'The class code was revoked.';
    } catch (error) {
      _error = _messageFor(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _join() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Enter the class code your teacher provided.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      _connection = await widget.repository.joinClassCode(code);
      _codeController.clear();
      _message = 'You are now connected to ${_connection!.teacherName}.';
    } catch (error) {
      _error = _messageFor(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copyCode() async {
    final code = _activeCode?.code;
    if (code == null) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (mounted) setState(() => _message = 'Class code copied.');
  }

  String _messageFor(Object error) {
    if (error is PostgrestException &&
        (error.code == 'PGRST202' || error.code == '42883')) {
      return 'Class connections are not enabled yet. Ask the app owner to apply the class-code migration.';
    }
    if (error is StateError) return error.message;
    return 'The class connection could not be updated. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final title = _student ? 'Class connection' : 'Your class code';
    return TeatroCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TeatroEyebrow('CLASS CONNECTION'),
          const SizedBox(height: 5),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          if (_loading)
            const LinearProgressIndicator()
          else if (_student)
            _studentBody(context)
          else
            _teacherBody(context),
          if (_message != null) ...[
            const SizedBox(height: 9),
            Text(
              _message!,
              style: const TextStyle(color: TeatroColors.success),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 9),
            Text(_error!, style: TextStyle(color: TeatroColors.error)),
          ],
        ],
      ),
    );
  }

  Widget _studentBody(BuildContext context) {
    final connection = _connection;
    if (connection != null) {
      return Row(
        children: [
          const Icon(Icons.school_outlined),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              connection.teacherName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          TeatroActionButton(
            label: 'Refresh',
            icon: Icons.refresh,
            onPressed: _busy ? null : _refresh,
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Unassigned — enter a class code to connect with a teacher.',
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _codeController,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Class code',
            hintText: 'IT-…',
          ),
          onSubmitted: (_) => _join(),
        ),
        const SizedBox(height: 10),
        TeatroActionButton(
          label: _busy ? 'Joining…' : 'Join class',
          icon: Icons.group_add_outlined,
          onPressed: _busy ? null : _join,
        ),
      ],
    );
  }

  Widget _teacherBody(BuildContext context) {
    final code = _activeCode;
    if (code == null) {
      return TeatroActionButton(
        label: _busy ? 'Generating…' : 'Generate class code',
        icon: Icons.key_outlined,
        onPressed: _busy ? null : _generateCode,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(
          code.code,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            letterSpacing: 1.4,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text('Expires ${code.expiresAt.toLocal().toString().split('.').first}'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            TeatroActionButton(
              label: 'Copy code',
              icon: Icons.copy_outlined,
              onPressed: _busy ? null : _copyCode,
            ),
            TeatroActionButton(
              label: 'Regenerate',
              icon: Icons.autorenew,
              onPressed: _busy ? null : _generateCode,
            ),
            TeatroActionButton(
              label: 'Revoke',
              icon: Icons.block_outlined,
              onPressed: _busy ? null : _revokeCode,
            ),
          ],
        ),
      ],
    );
  }
}
