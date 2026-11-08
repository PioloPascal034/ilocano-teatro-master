# Deployment & Maintenance Guide

## Android builds

From the project root, use the approved non-secret configuration:

```powershell
flutter pub get
flutter build apk --release --dart-define-from-file=supabase.local.json
flutter build appbundle --release --dart-define-from-file=supabase.local.json
```

The release build type uses the dedicated upload-keystore configuration. The local keystore and signing properties must exist before these commands can succeed; the build fails safely when they are missing. Verify application ID `com.mrbisacstudios.ilocanoteatromaster`, version code/name, signing certificate, and secure keystore backup. Do not commit any signing secrets.

## Google Play preparation

Before upload, the owner must verify production signing, Play App Signing, privacy policy URL, Data Safety declarations, content rating, target SDK, app access instructions, screenshots, store listing, permission declarations, and release notes. No Play upload or publication is performed by this handover.

## Flutter Web build and Firebase Hosting preparation

```powershell
flutter build web --release --dart-define-from-file=supabase.local.json
```

Host the contents of `build/web` on the client-approved host. For Firebase Hosting, initialize/link the intended Firebase project, configure `build/web` as the public directory, enable SPA fallback to `/index.html`, verify HTTPS and cache headers, and run a preview or staging deployment first. No Firebase Hosting deployment has been verified or performed in this handover.

## Supabase configuration

The Edge Function source is under `supabase/functions/get-private-media`. Deployment has not been performed from this environment. Keep JWT verification enabled and set function secrets only in Supabase's protected environment. Deploy only the named function after reviewing the linked project and source. Do not put service-role/secret keys in Flutter, Web, Git, or client artifacts.

## Database migrations

Review migration order and the remote ledger before applying changes. Use Supabase CLI or the approved dashboard workflow, record the migration identifier, and test against a backup/staging project first. Never edit production RLS or delete records as part of a routine client release without approval.

## Backup and recovery

Maintain scheduled database backups and verify restoration periodically. Preserve Storage objects separately from database backups when required. Keep a release record containing artifact hashes, version code, migration IDs, and rollback notes. For an incident, stop rollout, preserve logs, restore the last known-good build/configuration, and follow the project owner's recovery procedure.

## Updating and maintenance

Run static analysis, the final regression suite, targeted tests for changed features, and Android/Web release builds. Review dependency updates separately. Validate Auth, RLS, private media, and browser deep links after backend changes. Keep client content and teacher account provisioning outside code changes.

## Teacher account provisioning

Create Teacher accounts through the approved owner/admin process. The client has not yet designated its Curriculum Editor. After designation, grant the additional `curriculum_editors` authorization deliberately and document who owns curriculum review and transfer. Teachers can create/revoke their class codes through the application. Do not distribute credentials through source files or documentation.

## Google Play Console preparation

The account owner must configure the Google Play Console application under MR Bisac Studios, verify Play App Signing and upload-key ownership, complete privacy policy and Data Safety declarations, content rating, app access instructions, screenshots, store listing, target SDK requirements, and release notes. Upload the signed AAB manually only after client approval. No Play Console upload or publication has occurred.

