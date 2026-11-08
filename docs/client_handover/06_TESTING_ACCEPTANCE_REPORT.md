# Testing & Acceptance Report

## Status summary

This is a handover evidence report, not a claim that every device and production-release requirement is complete. Previously completed automated QA and prior live Web/repository evidence cover the core workflows. Android real-device and final client Web acceptance remain pending. No deployment or publication is claimed.

## Evidence labels

- **PASS** — the named evidence passed the named scope.
- **PARTIAL** — part of the workflow passed; the stated remainder is open.
- **NOT VERIFIED** — no reliable evidence was available.

## Final checks

| Targeted final check | Result | Evidence |
|---|---|---|
| Curriculum tests | PASS | 19 tests passed. |
| Quiz-management tests | PASS | 10 tests passed. |
| Story Vault tests | PASS | 24 tests passed. |
| Targeted Flutter analysis | PASS | Changed quiz and Story Vault files reported no issues. |
| Android Internet permission | PASS | Android main manifest contains `android.permission.INTERNET`; the release permission fix is present. |
| Database cleanup | PASS for reported scope | Prior readiness evidence recorded cleanup/unpublication of QA records; no new live cleanup was performed during this documentation update. |

| Check | Result | Evidence |
|---|---|---|
| Git branch and working tree inspection | PASS | Current branch is `Final-checking`; pre-existing user changes were preserved. |
| Previously completed Flutter QA | PASS | Existing readiness report records 114 tests passed; live QA was opt-in and skipped by default. |
| Targeted Flutter analysis | PASS | Current targeted analysis reported no issues. |
| Targeted Flutter tests | PASS | 19 curriculum, 10 quiz-management, and 24 Story Vault tests passed. |
| Android device / `adb devices` | NOT VERIFIED | `flutter devices` showed no usable Android phone; `adb` is not available on PATH in this environment. |
| Android debug build | PASS | Existing readiness report: debug APK built with non-secret defines. |
| Android release APK | NOT VERIFIED for current production signing | Release commands are prepared; current client acceptance and final signature verification remain pending. |
| Android AAB | NOT VERIFIED for current production signing | AAB upload has not occurred. |
| Web release build | PASS | `build/web` refreshed with the release build using the non-secret Supabase defines; no public deployment performed. |
| Live Web student/teacher flows | PASS / PARTIAL | Prior live Web evidence covers login, navigation, dashboard, curriculum drafts, quiz/story drafts, queue, progress, notifications, and logout; final client acceptance and some UI publish/upload actions remain open. |
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
2. Verify the upload keystore, certificate, APK/AAB signatures, and secure backup before distribution.
3. Published learning content is incomplete and Story Vault has no approved published story in the prior evidence environment.
4. UI publication, file chooser upload, browser image rendering, and live review-decision submission need client walkthrough confirmation.
5. Broader RLS isolation using an unassigned teacher and a second student remains unverified.
6. The client has not yet designated a Curriculum Editor.

## Client acceptance checklist

- [ ] Approved curriculum and Story Vault content is present.
- [ ] Android phone walkthrough completed and recorded.
- [ ] Web desktop/mobile walkthrough completed.
- [ ] Production release signing verified.
- [ ] Privacy, Data Safety, content rating, and store declarations approved.
- [ ] Hosting and Supabase deployment approved.
- [ ] Teacher accounts and class assignments provisioned.
- [ ] Client-designated Curriculum Editor account provisioned and authorized.
- [ ] Curriculum content ownership and review responsibility assigned.
- [ ] Supabase administration responsibility assigned.
- [ ] Google Play developer account ownership confirmed.
- [ ] Web hosting/Firebase ownership and maintenance responsibility confirmed.
- [ ] Client signs off on known limitations.

