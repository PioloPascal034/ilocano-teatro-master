# Testing & Acceptance Report

## Status summary

This is a handover evidence report, not a claim that every device and production-release requirement is complete. Automated tests and prior live Web/repository evidence cover the core workflows. Android real-device testing is not verified because no Android device was connected. Release artifacts are not Play Store-ready until production signing and policy requirements are completed.

## Evidence labels

- **PASS** — the named evidence passed the named scope.
- **PARTIAL** — part of the workflow passed; the stated remainder is open.
- **NOT VERIFIED** — no reliable evidence was available.

## Final checks

| Check | Result | Evidence |
|---|---|---|
| Git branch and working tree inspection | PASS | Branch `staging-III`; pre-existing user changes preserved. |
| Flutter analyze | PASS (existing and final run initiated) | Existing readiness report records no issues; final command completed its analysis phase without a reported diagnostic. |
| Flutter regression suite | PASS for existing evidence | Readiness report records 114 tests passed; final suite exercised current modified tests, with live QA skipped by default. |
| Android device / `adb devices` | NOT VERIFIED | `flutter devices` showed no usable Android phone; `adb` is not available on PATH in this environment. |
| Android debug build | PASS | Existing readiness report: debug APK built with non-secret defines. |
| Android release APK | PASS — artifact built | `build/app/outputs/flutter-apk/app-release.apk`; installable artifact built with the repository's debug signing configuration. |
| Android AAB | PASS — artifact built | `build/app/outputs/bundle/release/app-release.aab`; prepared locally, not uploaded, and not production-signed. |
| Web release build | PASS | `build/web` refreshed with the release build using the non-secret Supabase defines; no public deployment performed. |
| Live Web student/teacher flows | PASS / PARTIAL | Prior live Web evidence covers login, navigation, dashboard, curriculum drafts, quiz/story drafts, queue, progress, notifications, and logout; UI publish/upload actions remain open. |
| Private media | PASS for repository/live function checks | Prior live evidence covered upload/download and `get-private-media`; avatar rendering/upload remains partial in UI. |

## Feature checklist

| Area | Result | Scope and limitation |
|---|---|---|
| Student and teacher login/logout | PASS | Live repository/Web evidence; Android device not verified. |
| Role navigation | PASS | Automated and live Web evidence. |
| Profile and avatar | PARTIAL | Existing photo display and automated rollback/upload tests; live UI replacement not verified. |
| Class-code joining | PASS | Server-side migration and repository tests. |
| Modules, lessons, progress | PASS/PARTIAL | Core persistence and rendering tested; approved content coverage is insufficient. |
| Quizzes/results | PASS | Repository/Web and automated evidence; Android device not verified. |
| Story Vault/progress | PASS/PARTIAL | Isolated synthetic records passed; no approved published story remained. |
| Theme Builder/drafts | PASS/PARTIAL | Repository and responsive automated evidence; complete live six-step UI flow not verified. |
| Teacher review/resubmission | PASS/PARTIAL | Repository and Web queue evidence; live browser decision submission not performed. |
| Curriculum authoring | PASS/PARTIAL | Draft/edit/preview passed; UI publish/unpublish not completed live. |
| Notifications | PASS | Automated and live evidence. |
| Private media | PASS/PARTIAL | Backend path/access checks passed; all UI chooser/render combinations not verified. |
| Responsive layout and routing | PASS/PARTIAL | Automated mobile-width tests and Web navigation passed; full device matrix not verified. |

## Known issues and acceptance gates

1. No Android phone was connected, so the client must perform the Android walkthrough on the target phone.
2. Current Android release signing is debug signing. Configure and verify a protected production keystore before distribution.
3. Published learning content is incomplete and Story Vault has no approved published story in the prior evidence environment.
4. UI publication, file chooser upload, browser image rendering, and live review-decision submission need client walkthrough confirmation.
5. Broader RLS isolation using an unassigned teacher and a second student remains unverified.

## Client acceptance checklist

- [ ] Approved curriculum and Story Vault content is present.
- [ ] Android phone walkthrough completed and recorded.
- [ ] Web desktop/mobile walkthrough completed.
- [ ] Production release signing verified.
- [ ] Privacy, Data Safety, content rating, and store declarations approved.
- [ ] Hosting and Supabase deployment approved.
- [ ] Teacher accounts and class assignments provisioned.
- [ ] Client signs off on known limitations.

