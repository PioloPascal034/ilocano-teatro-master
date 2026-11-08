# Technical Documentation

## Stack and architecture

- Flutter/Dart application with shared Android and Web UI.
- Feature-first code under `lib/features`, shared widgets/storage under `lib/core`, and app setup under `lib/app`.
- Repository classes isolate Supabase calls from screens and models.
- `supabase_flutter` supplies Auth and database/storage clients; `file_picker` supplies uploads; `http` and Web interop support platform behavior.

## Backend services

Supabase provides password authentication, Postgres, Row Level Security (RLS), private Storage buckets, and RPC functions. The app uses a publishable key and project URL from non-secret build defines. Secret/service keys never belong in Flutter or Web output.

Android application ID: `com.mrbisacstudios.ilocanoteatromaster`.

Android release Gradle configuration uses a dedicated upload-keystore configuration from ignored local properties or protected CI variables. Signing credentials and keystores are not stored in this repository.

## Main tables and relationships

Class-code enrollment uses the server-generated `teacher_class_codes` workflow. Teachers can create and revoke their own active codes; students submit a valid code to establish a teacher connection.

The implemented repositories reference:

- `profiles` — identity, role, editor permission, and avatar path.
- `teacher_students` — teacher/student assignments and class-code relationships.
- `learning_modules` → `lessons` → `lesson_progress`.
- `quizzes` → `quiz_questions` → `question_options` → `quiz_attempts`.
- `cultural_stories` → `story_chapters` → `story_reading_progress`.
- `theme_drafts` → `submissions` → `reviews` → `review_scores`.
- `rubric_criteria` — review scoring definitions.
- `notifications` — role/account event feed.

The exact column definitions and constraints are maintained in the SQL migrations and setup SQL; apply migrations through the approved Supabase process only.

## Roles and authorization

## RLS and RPC access

Supabase Auth identifies the user. `profiles.role` distinguishes Student and Teacher accounts. `curriculum_editors` grants the additional Curriculum Editor permission to selected Teacher accounts. Regular Teachers can manage their own class codes and assigned-student workflows but cannot mutate official curriculum. `is_curriculum_editor()` and related server-side checks are authoritative; Flutter navigation is not a security boundary.

RLS is the primary boundary. The application relies on server-side checks including `is_curriculum_editor()` and `can_review(uuid)`. Important RPCs referenced by the client include `reorder_module_lessons`, `get_quiz_editor_question_details`, `reorder_quiz_questions`, `submit_quiz`, `reorder_story_chapters`, `submit_theme`, `complete_review`, `delete_curriculum_module`, `delete_curriculum_lesson`, `delete_curriculum_quiz`, `delete_story`, and `delete_story_chapter`. Deletion RPCs are narrowly scoped, editor-checked, and do not grant broad table DELETE privileges. Curriculum and Story Vault deletion migrations are prepared for review and are not applied by the Flutter client.

## Storage and private media

The known buckets are `ilocano-profile-avatars` and `ilocano-story-media`. The `get-private-media` Edge Function authenticates the bearer token, resolves the requested record through the caller's RLS-scoped client, validates the stored path and image signature, and fetches bytes using a server-side key. It supports avatar, story-cover, and chapter-illustration requests. It rejects malformed requests, unauthorized records, unsupported media, and oversized media without exposing database details or object paths.

Lesson records do not currently implement lesson-image storage. Story covers and chapter illustrations use exact private Storage paths. Story/chapter deletion uses the Storage API and tombstone authorization so shared or still-referenced media is not removed.

```mermaid
sequenceDiagram
  participant Client as Flutter client
  participant Fn as get-private-media
  participant DB as Supabase DB/RLS
  participant Store as Private Storage
  Client->>Fn: authenticated type + recordId
  Fn->>DB: validate user and record access
  DB-->>Fn: authorized stored path
  Fn->>Store: fetch server-side object
  Store-->>Fn: image bytes
  Fn-->>Client: private image response
```

## Environment configuration

Use a local, ignored `--dart-define-from-file` containing only the project URL and publishable key, or equivalent CI secret injection. Android release signing reads ignored `android/key.properties` or protected CI variables. The checked-in `supabase.local.json` is a local configuration reference and must not be copied into a public deliverable. Never expose `.env`, service-role keys, signing passwords, test accounts, tokens, or keystores.

## Error handling and security

Repositories surface actionable errors to screens, preserve prior state on failed avatar replacement, and provide loading/empty/error UI in major flows. Keep production policies unchanged without approval. Review RLS, function JWT verification, storage policies, CORS, key rotation, and audit logs before release. Do not log credentials, bearer headers, private storage paths, or secret responses.

