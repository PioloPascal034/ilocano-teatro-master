import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../../app/app_theme.dart';
import '../../core/widgets/teatro_widgets.dart';
import '../../core/widgets/teatro_design_widgets.dart';
import 'profile_avatar.dart';
import 'profile_avatar_validator.dart';
import 'user_profile.dart';
import 'user_profile_repository.dart';

typedef ProfileAvatarPicker = Future<Uint8List?> Function();

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({
    required this.role,
    required this.repository,
    required this.onProfileUpdated,
    this.onSignOut,
    this.avatarPicker,
    this.initialProfile,
    super.key,
  });

  final AppRole role;
  final UserProfileRepository repository;
  final ValueChanged<UserProfile> onProfileUpdated;
  final Future<void> Function()? onSignOut;
  final ProfileAvatarPicker? avatarPicker;
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
  bool _photoBusy = false;
  Uint8List? _pendingAvatar;
  String? _error;
  String? _photoError;
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

  Future<void> _chooseAvatar() async {
    try {
      final injectedPicker = widget.avatarPicker;
      Uint8List bytes;
      if (injectedPicker != null) {
        final selected = await injectedPicker();
        if (selected == null) return;
        bytes = selected;
      } else {
        final file = await FilePicker.pickFile(type: FileType.image);
        if (file == null) return;
        final fileLength = await file.length();
        if (fileLength != null &&
            fileLength > ProfileAvatarValidator.maxBytes) {
          throw const FormatException('Images must be 5 MiB or smaller.');
        }
        bytes = await file.readAsBytes();
      }
      ProfileAvatarValidator.validate(bytes);
      if (!mounted) return;
      setState(() {
        _pendingAvatar = bytes;
        _photoError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _photoError = _message(error));
    }
  }

  Future<void> _retryAvatarDownload() async {
    if (_photoBusy) return;
    setState(() {
      _photoBusy = true;
      _photoError = null;
    });
    try {
      final refreshed = await widget.repository.loadCurrentProfile();
      if (!mounted) return;
      _publishProfile(refreshed);
      setState(() {
        _photoError = refreshed.avatarLoadError;
        _photoBusy = false;
      });
      if (refreshed.avatarLoadError == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile photo loaded.')));
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _photoError = _message(error);
        _photoBusy = false;
      });
    }
  }

  Future<void> _uploadAvatar(UserProfile profile) async {
    final bytes = _pendingAvatar;
    if (bytes == null || _photoBusy) return;
    setState(() {
      _photoBusy = true;
      _photoError = null;
    });

    String? newPath;
    var pathPersisted = false;
    var rollbackFailed = false;
    var cleanupFailed = false;
    var cleanupUnconfirmed = false;
    try {
      newPath = await widget.repository.uploadAvatar(bytes);
      await widget.repository.saveAvatarStoragePath(newPath);
      pathPersisted = true;

      final refreshed = await widget.repository.loadCurrentProfile();
      if (kDebugMode) {
        debugPrint(
          'Profile avatar replacement verification: expected_path="$newPath", saved_path="${refreshed.avatarStoragePath ?? '(null)'}", has_downloaded_bytes=${refreshed.avatarBytes != null}, download_message="${refreshed.avatarLoadError ?? '(none)'}".',
        );
      }
      if (refreshed.avatarStoragePath != newPath) {
        pathPersisted = false;
        throw StateError('The saved profile photo could not be confirmed.');
      }
      if (refreshed.avatarLoadError != null || refreshed.avatarBytes == null) {
        // A successful row update is not enough: do not retire the old object
        // until the newly referenced private image can actually be downloaded.
        UserProfile restored;
        try {
          await widget.repository.saveAvatarStoragePath(
            profile.avatarStoragePath,
          );
          restored = await widget.repository.loadCurrentProfile();
          if (restored.avatarStoragePath != profile.avatarStoragePath) {
            throw StateError(
              'The previous profile photo could not be restored.',
            );
          }
        } catch (rollbackError, stackTrace) {
          rollbackFailed = true;
          if (kDebugMode) {
            debugPrint(
              'Profile photo reference rollback failed: $rollbackError',
            );
            debugPrintStack(stackTrace: stackTrace);
          }
          throw StateError(
            'The new photo could not be downloaded and the previous saved reference could not be restored. The previous image file was retained; retry after checking your connection.',
          );
        }
        pathPersisted = false;
        _publishProfile(restored);
        throw StateError(
          'The new photo could not be downloaded. Your previous photo was restored.',
        );
      }
      if (!mounted) return;
      _publishProfile(refreshed);

      final previousPath = profile.avatarStoragePath;
      if (previousPath != null && previousPath != newPath) {
        try {
          await widget.repository.deleteAvatar(previousPath);
        } catch (_) {
          cleanupFailed = true;
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            cleanupFailed
                ? 'Profile photo updated. The previous image could not be cleaned up.'
                : 'Profile photo updated.',
          ),
        ),
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          'Profile avatar replacement outcome: user_id=${profile.id}, new_path="${newPath ?? '(not uploaded)'}", database_reference_confirmed=$pathPersisted, rollback_failed=$rollbackFailed, cleanup_failed=$cleanupFailed, cleanup_unconfirmed=$cleanupUnconfirmed, error=$error.',
        );
      }
      if (!pathPersisted && newPath != null && !rollbackFailed) {
        try {
          final savedAfterError = await widget.repository.loadCurrentProfile();
          if (savedAfterError.avatarStoragePath == newPath) {
            // The update may have committed even if its response was lost.
            // Confirm persisted state before deciding whether cleanup is safe.
            pathPersisted = true;
            if (mounted) {
              _publishProfile(savedAfterError);
              final previousPath = profile.avatarStoragePath;
              var cleanupFailed = false;
              if (previousPath != null && previousPath != newPath) {
                try {
                  await widget.repository.deleteAvatar(previousPath);
                } catch (_) {
                  cleanupFailed = true;
                }
              }
              if (!mounted) return;
              setState(() {
                _pendingAvatar = null;
                _photoBusy = false;
                _photoError = null;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    cleanupFailed
                        ? 'Photo updated. The previous image could not be cleaned up.'
                        : 'Profile photo updated.',
                  ),
                ),
              );
              return;
            }
          } else {
            try {
              await widget.repository.deleteAvatar(newPath);
            } catch (_) {
              cleanupFailed = true;
            }
          }
        } catch (_) {
          // If the commit state cannot be read, keep both objects so the
          // previous avatar cannot be lost or the new reference broken.
          cleanupUnconfirmed = true;
        }
      }
      if (!mounted) return;
      if (rollbackFailed) {
        _publishProfile(profile);
        setState(() {
          _photoError = _message(error);
          _photoBusy = false;
        });
      } else if (pathPersisted && newPath != null) {
        // Persistence succeeded but refresh failed. Keep the current device and
        // header consistent with the path already stored in Supabase.
        _publishProfile(profile.withAvatar(storagePath: newPath, bytes: bytes));
        setState(() {
          _photoError =
              'Photo saved, but the profile could not refresh. The old image was kept.';
          _pendingAvatar = null;
          _photoBusy = false;
        });
      } else {
        setState(() {
          final cleanupMessage = cleanupUnconfirmed
              ? ' The upload cleanup could not be confirmed; both files were kept to protect your saved photo.'
              : cleanupFailed
              ? ' The unused upload could not be removed; retry after checking your connection.'
              : '';
          _photoError = '${_message(error)}$cleanupMessage';
          _photoBusy = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _pendingAvatar = null;
        _photoBusy = false;
        _photoError = null;
      });
    }
  }

  Future<void> _removeAvatar(UserProfile profile) async {
    final oldPath = profile.avatarStoragePath;
    if (oldPath == null || _photoBusy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove profile photo?'),
        content: const Text('Your initials will be shown instead.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove photo'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _photoBusy = true;
      _photoError = null;
    });
    var pathPersisted = false;
    try {
      await widget.repository.saveAvatarStoragePath(null);
      pathPersisted = true;
      final refreshed = await widget.repository.loadCurrentProfile();
      if (refreshed.avatarStoragePath != null) {
        throw StateError('The profile photo removal could not be confirmed.');
      }
      if (!mounted) return;
      _publishProfile(refreshed);
      await widget.repository.deleteAvatar(oldPath);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile photo removed.')));
    } catch (error) {
      if (!mounted) return;
      if (pathPersisted) {
        _publishProfile(profile.withAvatar(storagePath: null, bytes: null));
        setState(() {
          _photoError =
              'Photo removed from your profile, but the old file could not be cleaned up.';
          _photoBusy = false;
        });
      } else {
        setState(() {
          _photoError = _message(error);
          _photoBusy = false;
        });
      }
      return;
    }
    if (mounted) setState(() => _photoBusy = false);
  }

  void _publishProfile(UserProfile profile) {
    widget.onProfileUpdated(profile);
    setState(() {
      _future = Future.value(profile);
    });
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
      final displayedProfile = _pendingAvatar == null || _photoError != null
          ? profile
          : profile.withAvatar(
              storagePath: profile.avatarStoragePath,
              bytes: _pendingAvatar,
            );
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
                      ProfileAvatar(
                        profile: displayedProfile,
                        size: compact ? 54 : 66,
                        backgroundColor: const Color(0xFFDCA77D),
                        foregroundColor: const Color(0xFF69371F),
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
                            Wrap(
                              spacing: 3,
                              runSpacing: 0,
                              children: [
                                TextButton.icon(
                                  onPressed: _photoBusy ? null : _chooseAvatar,
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFFFFD6C2),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  icon: const Icon(
                                    Icons.photo_camera_outlined,
                                    size: 16,
                                  ),
                                  label: Text('Change Photo'),
                                ),
                                if (profile.avatarStoragePath != null &&
                                    _pendingAvatar == null)
                                  TextButton.icon(
                                    onPressed: _photoBusy
                                        ? null
                                        : () => _removeAvatar(profile),
                                    style: TextButton.styleFrom(
                                      foregroundColor: const Color(0xFFFFD6C2),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 16,
                                    ),
                                    label: const Text('Remove Photo'),
                                  ),
                              ],
                            ),
                            if (profile.avatarLoadError != null &&
                                _photoError == null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Wrap(
                                  spacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    const Text(
                                      'Your saved photo is unavailable.',
                                      style: TextStyle(
                                        color: Color(0xFFFFD6C2),
                                        fontSize: 12,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: _photoBusy
                                          ? null
                                          : _retryAvatarDownload,
                                      style: TextButton.styleFrom(
                                        foregroundColor: const Color(
                                          0xFFFFD6C2,
                                        ),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      child: const Text('Retry'),
                                    ),
                                  ],
                                ),
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
                        onPressed: _saving || _photoBusy
                            ? null
                            : _confirmSignOut,
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
            if (_pendingAvatar != null || _photoError != null || _photoBusy)
              TeatroCard(
                padding: EdgeInsets.all(compact ? 13 : 17),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_photoBusy) ...[
                      const LinearProgressIndicator(),
                      const SizedBox(height: 9),
                      const Text('Saving profile photo…'),
                    ],
                    if (_pendingAvatar != null && !_photoBusy) ...[
                      const Text('Preview your photo before uploading.'),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: ClipOval(
                          child: Image.memory(
                            _pendingAvatar!,
                            width: 76,
                            height: 76,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                ProfileAvatar(profile: profile, size: 76),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: () =>
                                setState(() => _pendingAvatar = null),
                            child: const Text('Cancel'),
                          ),
                          FilledButton.icon(
                            onPressed: () => _uploadAvatar(profile),
                            icon: const Icon(Icons.cloud_upload_outlined),
                            label: Text(
                              _photoError == null
                                  ? 'Upload Photo'
                                  : 'Retry Upload',
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (_photoError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _photoError!,
                          style: TextStyle(color: TeatroColors.error),
                        ),
                      ),
                  ],
                ),
              ),
            if (_pendingAvatar != null || _photoError != null || _photoBusy)
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
      : error is FormatException
      ? error.message.toString()
      : 'Please check your connection and try again.';
}
