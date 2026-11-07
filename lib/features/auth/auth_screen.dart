import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/app_theme.dart';
import '../../core/widgets/teatro_widgets.dart';

enum _AuthMode { welcome, signIn, signUp, forgotPassword }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  _AuthMode _mode = _AuthMode.welcome;
  bool _busy = false;
  bool _showPassword = false;
  String? _error;
  String? _message;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _setMode(_AuthMode mode) {
    setState(() {
      _mode = mode;
      _error = null;
      _message = null;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    final auth = Supabase.instance.client.auth;
    try {
      switch (_mode) {
        case _AuthMode.signIn:
          await auth.signInWithPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
        case _AuthMode.signUp:
          final result = await auth.signUp(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            data: {'full_name': _nameController.text.trim()},
          );
          if (result.session == null) {
            _message = 'Check your email to confirm your student account.';
          }
        case _AuthMode.forgotPassword:
          await auth.resetPasswordForEmail(_emailController.text.trim());
          _message =
              'If an account exists for this email, a reset link is on its way.';
        case _AuthMode.welcome:
          return;
      }
    } on AuthException catch (error) {
      _error = error.message;
    } catch (_) {
      _error = 'Something went wrong. Please try again.';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 700;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 22 : 32,
              vertical: compact ? 20 : 36,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 980),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Brand(),
                    SizedBox(height: compact ? 30 : 58),
                    if (_mode == _AuthMode.welcome)
                      _welcome(compact)
                    else
                      _form(compact),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _welcome(bool compact) => TeatroCard(
    padding: EdgeInsets.all(compact ? 24 : 48),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TeatroEyebrow('Learn · Create · Share', color: TeatroColors.rust),
        const SizedBox(height: 16),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'Every story deserves\n'),
              TextSpan(
                text: 'a stage.',
                style: const TextStyle(
                  color: TeatroColors.rust,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          style: Theme.of(
            context,
          ).textTheme.displayLarge?.copyWith(fontSize: compact ? 36 : 54),
        ),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Text(
            'Explore theater, honor cultural stories, and shape a play that is truly yours.',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: TeatroColors.muted),
          ),
        ),
        const SizedBox(height: 28),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: () => _setMode(_AuthMode.signIn),
              icon: const Icon(Icons.login, size: 18),
              label: const Text('Sign in'),
            ),
            OutlinedButton.icon(
              onPressed: () => _setMode(_AuthMode.signUp),
              icon: const Icon(Icons.person_add_alt_1, size: 18),
              label: const Text('Sign up'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Student accounts can be created here. Teacher and reviewer roles are assigned by your school.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: TeatroColors.muted),
        ),
      ],
    ),
  );

  Widget _form(bool compact) {
    final title = switch (_mode) {
      _AuthMode.signIn => 'Welcome back.',
      _AuthMode.signUp => 'Begin your theater journey.',
      _AuthMode.forgotPassword => 'Reset your password.',
      _AuthMode.welcome => '',
    };
    final description = switch (_mode) {
      _AuthMode.signIn =>
        'Use the same sign-in for students, teachers, and reviewers. Your role is assigned to your account.',
      _AuthMode.signUp => 'Create a student account to begin learning.',
      _AuthMode.forgotPassword =>
        'Enter your account email and we’ll send a reset link.',
      _AuthMode.welcome => '',
    };
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: TeatroCard(
          padding: EdgeInsets.all(compact ? 22 : 38),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextButton.icon(
                  onPressed: () => _setMode(_AuthMode.welcome),
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text('Back'),
                ),
                const SizedBox(height: 16),
                const TeatroEyebrow(
                  'Ilocano Teatro Master',
                  color: TeatroColors.rust,
                ),
                const SizedBox(height: 8),
                Text(title, style: Theme.of(context).textTheme.headlineLarge),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: TeatroColors.muted),
                ),
                if (_mode == _AuthMode.signUp) ...[
                  const SizedBox(height: 22),
                  TeatroFormField(
                    controller: _nameController,
                    label: 'Full name',
                    hintText: 'Enter your full name',
                    textInputAction: TextInputAction.next,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter your name.'
                        : null,
                  ),
                ],
                const SizedBox(height: 16),
                TeatroFormField(
                  controller: _emailController,
                  label: 'Email address',
                  hintText: 'you@example.com',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: _mode == _AuthMode.forgotPassword
                      ? TextInputAction.done
                      : TextInputAction.next,
                  validator: (value) => value == null || !value.contains('@')
                      ? 'Enter a valid email address.'
                      : null,
                  onFieldSubmitted: (_) =>
                      _mode == _AuthMode.forgotPassword ? _submit() : null,
                ),
                if (_mode != _AuthMode.forgotPassword) ...[
                  const SizedBox(height: 16),
                  TeatroFormField(
                    controller: _passwordController,
                    label: 'Password',
                    hintText: 'At least 8 characters',
                    obscureText: !_showPassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    validator: (value) {
                      if (value == null || value.length < 8) {
                        return 'Use at least 8 characters.';
                      }
                      return null;
                    },
                    suffix: IconButton(
                      tooltip: _showPassword
                          ? 'Hide password'
                          : 'Show password',
                      onPressed: () =>
                          setState(() => _showPassword = !_showPassword),
                      icon: Icon(
                        _showPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 13),
                  Text(
                    _error!,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: TeatroColors.error),
                  ),
                ],
                if (_message != null) ...[
                  const SizedBox(height: 13),
                  Text(
                    _message!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: TeatroColors.success,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                TeatroPrimaryButton(
                  label: switch (_mode) {
                    _AuthMode.signIn => 'Sign in',
                    _AuthMode.signUp => 'Create account',
                    _AuthMode.forgotPassword => 'Send reset link',
                    _AuthMode.welcome => '',
                  },
                  icon: Icons.arrow_forward,
                  busy: _busy,
                  onPressed: _submit,
                ),
                if (_mode == _AuthMode.signIn) ...[
                  Center(
                    child: TextButton(
                      onPressed: () => _setMode(_AuthMode.forgotPassword),
                      child: const Text('Forgot password?'),
                    ),
                  ),
                  Center(
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text('New to Ilocano Teatro? '),
                        TextButton(
                          onPressed: () => _setMode(_AuthMode.signUp),
                          child: const Text('Sign up'),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_mode == _AuthMode.signUp)
                  Center(
                    child: TextButton(
                      onPressed: () => _setMode(_AuthMode.signIn),
                      child: const Text('Already have an account? Sign in'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Image.asset(
        'assets/branding/applogo.png',
        width: 58,
        height: 58,
        fit: BoxFit.contain,
        semanticLabel: 'Ilocano Teatro Master logo',
      ),
      const SizedBox(height: 8),
      Text.rich(
        TextSpan(
          children: [
            const TextSpan(text: 'Ilocano\n'),
            TextSpan(
              text: 'Teatro',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.05),
      ),
    ],
  );
}
