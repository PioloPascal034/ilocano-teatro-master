import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../core/widgets/teatro_widgets.dart';

enum PublicLegalPage { privacy, accountDeletion }

class PublicLegalScreen extends StatelessWidget {
  const PublicLegalScreen({required this.page, super.key});

  final PublicLegalPage page;

  @override
  Widget build(BuildContext context) {
    final deletion = page == PublicLegalPage.accountDeletion;
    return Scaffold(
      backgroundColor: TeatroColors.paper,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 56),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ilocano Teatro Master',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    'MR Bisac Studios',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: TeatroColors.muted),
                  ),
                  const SizedBox(height: 42),
                  Text(
                    deletion ? 'Account deletion' : 'Privacy policy',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: TeatroColors.rust,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    deletion
                        ? 'Request removal of your account.'
                        : 'Learning, creating, and sharing with care.',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    deletion
                        ? 'There is currently no in-app account-deletion request form. Email the developer so account ownership can be verified safely.'
                        : 'This policy explains the information handled by Ilocano Teatro Master for its student and teacher learning workflows.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: TeatroColors.muted),
                  ),
                  const SizedBox(height: 28),
                  TeatroCard(
                    child: deletion
                        ? const _DeletionContent()
                        : const _PrivacyContent(),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 12,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(
                          context,
                        ).pushNamed(deletion ? '/privacy' : '/delete-account'),
                        child: Text(
                          deletion ? 'Read Privacy Policy' : 'Account Deletion',
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        child: const Text('Back'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PrivacyContent extends StatelessWidget {
  const _PrivacyContent();

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _LegalHeading('Information handled'),
      Text(
        'Account email, full name, role, teacher/student connections, class-code records, and optional profile avatar. The service also handles lesson progress, quiz answers/results and attempts, Theme Builder drafts and submissions, teacher feedback and rubric scores, notifications, and Story Vault reading progress. Story covers and chapter illustrations may be private media.',
      ),
      _LegalHeading('Use and access'),
      Text(
        'Information is used to authenticate accounts, provide role-based learning and teaching features, save progress, deliver submissions and feedback, show notifications, and display authorized private media. Students access their own activity and assigned learning. Teachers access assigned-student workflows. Curriculum Editors are Teachers with additional content-management permission.',
      ),
      _LegalHeading('Services and security'),
      Text(
        'Supabase provides authentication, database, Row Level Security, private Storage, and server-side functions. The get-private-media Edge Function checks authorization before returning image bytes. The public app configuration contains only the Supabase URL and publishable client key. Service-role keys are not included in the app.',
      ),
      _LegalHeading('Retention and deletion'),
      Text(
        'Data is retained while needed for the application services. No fixed deletion timeline is promised here. Request account and associated-data deletion at marcronielbisac@gmail.com. Ownership verification may be required, and some information may be retained where required for security, legal obligations, dispute resolution, or reliable service records.',
      ),
      _LegalHeading('Scope'),
      Text(
        'The AI Writing Coach is excluded from the final scope. Questions and requests: marcronielbisac@gmail.com.',
      ),
    ],
  );
}

class _DeletionContent extends StatelessWidget {
  const _DeletionContent();

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _LegalHeading('How to request deletion'),
      Text(
        'Email marcronielbisac@gmail.com from the email address associated with your account. Use the subject “Ilocano Teatro Master account deletion request”. Do not send your password or access token.',
      ),
      _LegalHeading('What the request covers'),
      Text(
        'After ownership is verified, the request will be reviewed for deletion of the account and associated application data, including profile information, connections, learning progress, quiz activity, drafts, submissions, feedback, notifications, Story Vault reading progress, and private avatar media where supported by the data model and access controls.',
      ),
      _LegalHeading('Important limitations'),
      Text(
        'There is currently no in-app account-deletion request form. Some information may need to be retained for security, legal obligations, dispute resolution, or reliable service records. A fixed processing timeline has not been established and will be confirmed when the request is reviewed.',
      ),
      _LegalHeading('Before requesting'),
      Text(
        'Preserve any work you need first. Deletion may remove drafts, submissions, progress, quiz history, feedback, notifications, and private media associated with the account.',
      ),
    ],
  );
}

class _LegalHeading extends StatelessWidget {
  const _LegalHeading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 8),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}
