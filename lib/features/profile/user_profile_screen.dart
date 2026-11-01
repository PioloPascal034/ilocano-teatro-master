import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../../app/app_theme.dart';
import '../../core/widgets/teatro_widgets.dart';
import '../../core/widgets/teatro_design_widgets.dart';
import 'user_profile.dart';
import 'user_profile_repository.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({
    required this.role,
    required this.repository,
    required this.onProfileUpdated,
    this.onSignOut,
    this.initialProfile,
    super.key,
  });

  final AppRole role;
  final UserProfileRepository repository;
  final ValueChanged<UserProfile> onProfileUpdated;
  final Future<void> Function()? onSignOut;
  final UserProfile? initialProfile;

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _school = TextEditingController();
  final _year = TextEditingController();
  final _section = TextEditingController();
  final _department = TextEditingController();
  late Future<UserProfile> _future;
  bool _editing = false;
  bool _saving = false;
  String? _error;
  String? _hydratedId;

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You will need to sign in again to use your account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (confirmed != true || widget.onSignOut == null) return;
    try {
      await widget.onSignOut!();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not sign out. Please try again.')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _future = widget.initialProfile == null
        ? widget.repository.loadCurrentProfile()
        : Future.value(widget.initialProfile);
  }

  @override
  void dispose() {
    _name.dispose();
    _school.dispose();
    _year.dispose();
    _section.dispose();
    _department.dispose();
    super.dispose();
  }

  void _hydrate(UserProfile profile) {
    if (_hydratedId == profile.id) return;
    _hydratedId = profile.id;
    _name.text = profile.fullName;
    _school.text = profile.school ?? '';
    _year.text = profile.yearLevel ?? '';
    _section.text = profile.section ?? '';
    _department.text = profile.department ?? '';
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final profile = await widget.repository.updateCurrentProfile(
        fullName: _name.text,
        school: _school.text,
        yearLevel: _year.text,
        section: _section.text,
        department: _department.text,
      );
      if (!mounted) return;
      _hydratedId = null;
      _hydrate(profile);
      widget.onProfileUpdated(profile);
      setState(() {
        _future = Future.value(profile);
        _saving = false;
        _editing = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile changes saved.')));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _message(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<UserProfile>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return TeatroCard(
          child: Column(
            children: [
              Text(
                'Profile unavailable',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(_message(snapshot.error!)),
              TextButton.icon(
                onPressed: () => setState(
                  () => _future = widget.repository.loadCurrentProfile(),
                ),
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ),
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final profile = snapshot.data!;
      _hydrate(profile);
      final student = widget.role == AppRole.student;
      final role = student ? 'Student' : 'Teacher / Reviewer';
      final compact = MediaQuery.sizeOf(context).width < 600;
      return TeatroPageBody(
        eyebrow: student ? 'STUDENT PROFILE' : 'TEACHER / REVIEWER PROFILE',
        title: 'Profile',
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(compact ? 15 : 24),
              decoration: BoxDecoration(
                color: TeatroColors.dark,
                borderRadius: BorderRadius.circular(12),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final identity = Row(
                    children: [
                      CircleAvatar(
                        radius: compact ? 27 : 33,
                        backgroundColor: const Color(0xFFDCA77D),
                        child: Text(
                          profile.initials,
                          style: const TextStyle(
                            color: Color(0xFF69371F),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TeatroEyebrow(
                              role.toUpperCase(),
                              color: const Color(0xFFD4D9D1),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _display(profile.fullName),
                              style:
                                  (compact
                                          ? Theme.of(
                                              context,
                                            ).textTheme.titleLarge
                                          : Theme.of(
                                              context,
                                            ).textTheme.headlineMedium)
                                      ?.copyWith(color: Colors.white),
                            ),
                            Text(
                              _display(profile.email),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: const Color(0xFFD4DCD4)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                  final controls = Wrap(
                    spacing: 8,
                    children: [
                      if (_editing)
                        TeatroActionButton(
                          label: 'Cancel',
                          icon: Icons.close,
                          onPressed: _saving
                              ? null
                              : () {
                                  _hydratedId = null;
                                  _hydrate(profile);
                                  setState(() {
                                    _editing = false;
                                    _error = null;
                                  });
                                },
                        ),
                      TeatroActionButton(
                        label: _editing ? 'Save profile' : 'Edit profile',
                        icon: _editing
                            ? Icons.save_outlined
                            : Icons.edit_outlined,
                        onPressed: _saving
                            ? null
                            : _editing
                            ? _save
                            : () => setState(() => _editing = true),
                      ),
                      OutlinedButton.icon(
                        onPressed: _saving ? null : _confirmSignOut,
                        icon: const Icon(Icons.logout, size: 17),
                        label: const Text('Sign Out'),
                      ),
                    ],
                  );
                  return constraints.maxWidth < 600
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            identity,
                            const SizedBox(height: 14),
                            controls,
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(child: identity),
                            controls,
                          ],
                        );
                },
              ),
            ),
            SizedBox(height: compact ? 10 : 14),
            TeatroCard(
              padding: EdgeInsets.all(compact ? 15 : 22),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const TeatroEyebrow('PERSONAL INFORMATION'),
                    const SizedBox(height: 5),
                    Text(
                      student ? 'Student information' : 'Teacher information',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 12),
                    _field('Full name', _name, required: true),
                    _value('Email', profile.email),
                    _value('Role', role),
                    if (student) ...[
                      _field('Year level', _year),
                      _field('Section', _section),
                      _field('School', _school),
                    ] else ...[
                      _field('Department', _department),
                      _field('Year level', _year),
                      _field('Section', _section),
                      _field('School', _school),
                    ],
                    if (_saving) const LinearProgressIndicator(),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Could not save: $_error',
                          style: TextStyle(color: TeatroColors.error),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            TeatroCard(
              padding: EdgeInsets.all(compact ? 13 : 17),
              child: Row(
                children: [
                  Image.asset(
                    'assets/branding/applogo.png',
                    width: 42,
                    height: 42,
                    fit: BoxFit.contain,
                    semanticLabel: 'Ilocano Teatro Master logo',
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ilocano Teatro Master',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          'Version 1.0.0',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );

  Widget _field(
    String label,
    TextEditingController controller, {
    bool required = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: _editing
        ? TextFormField(
            controller: controller,
            decoration: InputDecoration(
              labelText: label,
              hintText: 'Not provided',
              isDense: true,
            ),
            validator: required
                ? (value) => value == null || value.trim().isEmpty
                      ? 'Enter your name.'
                      : null
                : null,
          )
        : _value(label, controller.text),
  );

  Widget _value(String label, String? value) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 105, child: TeatroEyebrow(label)),
        Expanded(
          child: Text(
            _display(value),
            style: const TextStyle(fontSize: 14, color: TeatroColors.ink),
          ),
        ),
      ],
    ),
  );

  String _display(String? value) =>
      value == null || value.trim().isEmpty ? 'Not provided' : value.trim();
  String _message(Object error) => error is StateError
      ? error.message
      : 'Please check your connection and try again.';
}
