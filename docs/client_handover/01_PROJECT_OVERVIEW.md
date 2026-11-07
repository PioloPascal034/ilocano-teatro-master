# Project Overview

## Purpose

Ilocano Teatro Master is a learning and cultural-content application for Ilocano language and theatre education. It gives students a guided space for lessons, quizzes, cultural stories, and creative theme submissions, while giving teachers tools to author curriculum, review student work, and monitor progress.

## Intended users

- Students learning through assigned lessons, quizzes, stories, and creative tasks.
- Teachers who manage assigned students, review submissions, and—when authorized as curriculum editors—manage learning content.
- Project owners/administrators who provision teacher accounts and maintain Supabase configuration.

## Roles

Student accounts see student learning, Story Vault, Theme Builder, drafts, progress, notifications, and profile features. Teacher accounts see the teacher dashboard, assigned students, Review Queue, progress, notifications, and profile features. Curriculum-editor permission enables curriculum and Story Vault authoring; ordinary teachers are read-only for curriculum management.

## Core features

- Email/password authentication and session restoration.
- Role-based navigation for students and teachers.
- Student dashboard, profile, avatar handling, class-code joining, and progress.
- Published learning modules, structured or legacy lessons, reading progress, quizzes, and results.
- Story Vault stories, chapters, covers, illustrations, and reading progress.
- Six-step Theme Builder, draft persistence, submissions, feedback, revisions, and review decisions.
- Teacher curriculum, quiz, and Story Vault authoring for authorized editors.
- Review Queue with rubric scores, feedback, revision requests, and approvals.
- Notifications and private media delivery.

## Android and Web architecture

The client is a single Flutter application with shared Dart feature code. Flutter renders Android and Web interfaces; repositories isolate Supabase access; Supabase Auth, Postgres/RLS, Storage, RPCs, and the `get-private-media` Edge Function provide the backend.

```mermaid
flowchart LR
  UI[Flutter screens and widgets] --> Repo[Feature repositories]
  Repo --> Auth[Supabase Auth]
  Repo --> DB[(Postgres tables and RLS)]
  Repo --> RPC[Security-sensitive RPCs]
  Repo --> Media[get-private-media Edge Function]
  Media --> Storage[(Private Storage buckets)]
```

## Scope and limitations

The documented product is the functionality present in the repository and verified evidence. Content quality, teacher provisioning, Supabase administration, signing, hosting, and Play Store policy work remain operational responsibilities. Lesson illustrations are not implemented in the current lesson editor/schema. The AI Writing Coach is excluded from this release scope and is not presented as an available feature.

## Evidence basis

This handover uses the existing client-readiness report dated 3 November 2026, repository tests, and the final checks recorded in [Testing & Acceptance Report](./06_TESTING_ACCEPTANCE_REPORT.md). Evidence is labelled as automated, live repository, live Web, Android device, or not verified.
