import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/app_routes.dart';
import '../../app/app_theme.dart';
import 'auth_screen.dart';
import '../shell/app_shell.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final StreamSubscription<AuthState> _authSubscription;
  AppRole? _role;
  Object? _error;
  bool _loading = true;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (state) => _loadRole(state.session?.user),
    );
    _loadRole(Supabase.instance.client.auth.currentUser);
  }

  Future<void> _loadRole(User? user) async {
    final generation = ++_generation;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _role = null;
        _error = null;
      });
      return;
    }

    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();
      if (!mounted || generation != _generation) return;
      final role = profile?['role'];
      if (role != 'student' && role != 'teacher') {
        throw const FormatException(
          'Your account profile does not have a valid role.',
        );
      }
      setState(() {
        _role = role == 'teacher' ? AppRole.teacher : AppRole.student;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: TeatroColors.cream,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/branding/applogo.png',
                width: 88,
                height: 88,
                fit: BoxFit.contain,
                semanticLabel: 'Ilocano Teatro Master logo',
              ),
              const SizedBox(height: 20),
              const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ],
          ),
        ),
      );
    }
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/branding/applogo.png',
                    width: 64,
                    height: 64,
                    fit: BoxFit.contain,
                    semanticLabel: 'Ilocano Teatro Master logo',
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'We could not load your account profile.',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Check your connection or ask your school administrator to verify your account role.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  TextButton(
                    onPressed: _signOut,
                    child: const Text('Sign out'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    if (_role case final role?) return AppShell(role: role);
    return const AuthScreen();
  }
}
