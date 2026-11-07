# Deployment & Maintenance Guide

## Android builds

From the project root, use the approved non-secret configuration:

```powershell
flutter pub get
flutter build apk --release --dart-define-from-file=supabase.local.json
flutter build appbundle --release --dart-define-from-file=supabase.local.json
```

The current repository release build type points to the Android debug signing config. These commands therefore produce build artifacts but do not establish production signing or Google Play readiness. Before distribution, configure a protected release keystore through `key.properties`/CI secrets, verify the application ID, version code/name, signing certificate, and backup of the keystore. Do not commit any of these secrets.

## Google Play preparation

Before upload, the owner must verify production signing, Play App Signing, privacy policy URL, Data Safety declarations, content rating, target SDK, app access instructions, screenshots, store listing, permission declarations, and release notes. No Play upload or publication is performed by this handover.

## Flutter Web build and hosting

```powershell
flutter build web --release --dart-define-from-file=supabase.local.json
```

Host the contents of `build/web` on the approved static host. Configure SPA fallback so deep links return `index.html`, enable HTTPS, and set cache headers appropriate for hashed assets. Confirm the Supabase URL and publishable key are the intended non-secret production values. Do not deploy publicly without owner approval.

## Supabase configuration

The Edge Function source is under `supabase/functions/get-private-media`. Deployment has not been performed from this environment. Keep JWT verification enabled and set function secrets only in Supabase's protected environment. Deploy only the named function after reviewing the linked project and source. Do not put service-role/secret keys in Flutter, Web, Git, or client artifacts.

## Database migrations

Review migration order and the remote ledger before applying changes. Use Supabase CLI or the approved dashboard workflow, record the migration identifier, and test against a backup/staging project first. Never edit production RLS or delete records as part of a routine client release without approval.

## Backup and recovery

Maintain scheduled database backups and verify restoration periodically. Preserve Storage objects separately from database backups when required. Keep a release record containing artifact hashes, version code, migration IDs, and rollback notes. For an incident, stop rollout, preserve logs, restore the last known-good build/configuration, and follow the project owner's recovery procedure.

## Updating and maintenance

Run static analysis, the final regression suite, targeted tests for changed features, and Android/Web release builds. Review dependency updates separately. Validate Auth, RLS, private media, and browser deep links after backend changes. Keep client content and teacher account provisioning outside code changes.

## Teacher account provisioning

Create teacher accounts through the approved owner/admin process, assign the role and curriculum-editor permission deliberately, and create/revoke class codes through the server-side workflow. Do not distribute credentials through source files or documentation.

