# Client testing readiness — 3 November 2026

**Status: NOT READY for an unrestricted content demonstration.** Dedicated student and curriculum-editor accounts passed a live repository-level end-to-end run, and the teacher Web UI was exercised with isolated unpublished QA records. Approved learning and cultural content and Android runtime testing remain outstanding. A controlled technical demonstration is possible with the dedicated accounts.

## Release blockers, in priority order

1. **P1 content gate — Published learning content is insufficient.** The student Web session showed six published modules but only two available lessons, both under a module titled `m1`. The other five modules showed no lessons. The only visible quiz was titled `dw` with test-like copy. Story Vault showed no published stories. The synthetic QA records were unpublished after testing. Do not present them as approved educational or cultural content.
2. **P1 UI/device gate — Android runtime remains unverified.** Teacher Web UI interactions passed for the available screens using isolated unpublished QA records. `flutter devices` listed Windows and Chrome only; `adb devices` listed no phone.
3. **P1 permission coverage — Two-account restrictions passed, broader isolation remains unverified.** The dedicated teacher is assigned to the dedicated student. A student edit of the isolated lesson was denied; the student is not a curriculum editor. Cross-student and unassigned-teacher privacy require additional accounts.
4. **P1 assignment administration — No in-app assignment editor exists.** The application reads `teacher_students` but has no assignment write path. The dedicated pair was already assigned; no live assignment change was made.

## Verification matrix

Legend: **Live repository** = the application repository called live Supabase using dedicated accounts; **Live Web** = screen observed in a browser; **Automated** = local unit/widget tests with fakes. PASS means the stated evidence passed, not every possible UI or permission variant.

| Area | Feature | Evidence | Result / remaining check |
| --- | --- | --- | --- |
| Authentication | Student and teacher password login, roles | Live repository | **PASS**: both authenticated; profile roles and editor RPC matched expectations. Login forms remain unverified. |
| Authentication | Student role navigation and session persistence | Live Web | **PASS**: student shell loaded and survived reload. |
| Authentication | Teacher role navigation and logout | Live Web | **PASS**: teacher shell loaded with teacher-only navigation; logout confirmation returned to the welcome screen. |
| Profile | View and edit | Live Web, Automated | **PARTIAL**: teacher profile loaded with role and identity; live edit persistence unverified. |
| Profile | Photo upload, replacement, display, removal | Live Web, Automated | **PARTIAL**: existing photo displayed; live upload and replacement unverified. |
| Student | Dashboard | Live Web, Automated | **PASS**: saved lesson and quiz totals loaded. |
| Student | Modules and lessons | Live Web, Live repository | **PASS** technically; approved content remains insufficient. |
| Student | Structured and legacy reading | Live repository, Automated | **PARTIAL**: a structured QA lesson with overview and reading time persisted and was visible to the student repository; on-screen rendering of that record was not tested. Legacy renderer tests pass. |
| Student | Lesson progress | Live repository | **PASS**: in-progress and completed state persisted after reload. |
| Student | Quizzes, results, history | Live repository, Live Web | **PASS**: QA quiz publication, 100% scoring, and saved attempt; existing quiz history visible on Web. |
| Student | Story Vault, chapters, reading progress | Live repository | **PASS** with isolated synthetic record; no approved published story remains. |
| Student | Six-step Theme Builder | Live Web, Automated | **PARTIAL**: builder navigation visible; repository draft flow passed, but six-step UI completion was not tested live. |
| Student | Draft save, submission, resubmission | Live repository | **PASS** with isolated record and two versions. |
| Student | Feedback and revision history | Live repository | **PASS**: revision request, feedback, resubmission, and approval persisted. |
| Student | Notifications | Live repository | **PASS**: review notifications and mark-read state persisted. |
| Teacher | Dashboard | Live Web | **PASS**: dashboard showed assigned student, pending submissions, completed reviews, revision requests, and student activity. |
| Teacher | Curriculum module management | Live Web, Live repository | **PASS**: editor created an isolated module, saved it unpublished, and returned to its module detail screen. |
| Teacher | Lesson create, edit, draft, preview, publish, unpublish | Live Web, Live repository, Automated | **PASS for create/edit/draft/preview**; publish confirmation was opened and canceled, so live UI publication/unpublication remains **NOT VERIFIED**. Repository publication passed. |
| Teacher | Overview, reading time, sections | Live Web, Live repository | **PASS**: structured fields were entered, previewed, saved, reopened, edited, and previewed again; live repository values also persisted. |
| Teacher | Quiz management | Live Web, Live repository | **PASS for draft/question/option/preview**: isolated quiz and question saved and previewed. UI publish/unpublish remains **NOT VERIFIED**; repository publication passed. |
| Teacher | Story and media management | Live Web, Live repository | **PASS for story/chapter draft UI**: story and chapter forms saved and chapter preview rendered. UI file upload and image rendering remain **NOT VERIFIED**; repository media upload/download passed. |
| Teacher | Review Queue, rubric, decisions | Live Web, Live repository | **PASS for queue and review UI display**: assigned submission and rubric controls rendered. Live UI submit action was not performed; repository review transaction passed. |
| Teacher | Student progress and assigned-student visibility | Live Web, Live repository | **PASS for assigned student**: progress card showed 2/2 lessons, quiz 100%, Complete, and detail dialog. Unassigned-teacher isolation remains unverified. |
| Teacher | Assigned-student management | Code | **NOT IMPLEMENTED** in app; administrator provisioning required. |
| Teacher | Notifications | Live Web, Live repository | **PASS**: notification feed rendered five notifications including new submission notices; repository delivery also passed. |
| Security | Student editor and lesson-write restriction | Live repository | **PASS** for dedicated student against isolated lesson; broader RLS matrix unverified. |
| Platform | Android runtime | Build | **NOT VERIFIED**: debug APK builds; no phone attached. |
| Platform | Web runtime | Live Web, Build | **PASS**: release Web build opened and student screens navigated. |

## Teacher Web UI verification

Observed with the dedicated teacher account in an isolated browser session:

- **PASS:** teacher login, role-based teacher shell, dashboard, assigned student summary, pending review count, review queue listing, submission detail, rubric criteria, student progress card/detail, notification feed, profile, and logout.
- **PASS:** Learning Content module creation; structured lesson editor; lesson overview, objectives, introduction, discussion, summary, reading-time estimate, save as unpublished, reopen, edit, student preview, and saved lesson preview.
- **PASS:** Quiz draft creation; quiz question editor; two options with exactly one correct option; saved question; student-style quiz preview.
- **PASS:** Story Vault draft creation; story metadata save; chapter creation; chapter text save; chapter preview.
- **NOT VERIFIED:** UI publish/unpublish completion for lesson, module, quiz, story, and chapter; UI file chooser upload; image rendering in the teacher browser; review decision submission from the browser; profile editing/photo replacement.

All UI-created `QA UI ONLY` modules, lessons, quizzes, stories, and chapters remained unpublished. A student-side read-only check returned zero visible unpublished UI QA lessons and stories.

## Security checks

- **PASS:** dedicated student profile role is `student`; `is_curriculum_editor` returned false; student curriculum mutation was denied.
- **PASS:** dedicated teacher profile role is `teacher`; `is_curriculum_editor` returned true; existing teacher-student assignment was visible.
- **PASS:** unpublished UI QA lessons and stories were not visible to the student account.
- **NOT VERIFIED:** an unassigned teacher reading another teacher’s assigned student, and one student reading another student’s private draft/submission/progress. The supplied file contains only one teacher and one student account, and no extra account was created.

## Requested live workflow verdicts

These verdicts refer to live repository and Supabase behavior unless a Web screen is explicitly named. The run used dedicated student and editor accounts and isolated `QA ONLY` records.

| Workflow | Verdict | Evidence and limit |
| --- | --- | --- |
| 1. Student and teacher login | **PASS** | Both authenticated with password and returned the expected profile roles. Login form interaction was not tested. |
| 2. Role access and curriculum-editor permission | **PASS** | Student editor RPC false, teacher editor RPC true, existing assignment present, student module creation rejected. Teacher UI navigation not tested. |
| 3. Lesson publication, reading, progress | **PASS** | Structured QA lesson, overview, and reading time persisted; student repository loaded it and completion persisted. Screen reading not tested. |
| 4. Quiz creation, completion, results | **PASS** | QA question/options published; student submitted a correct answer, received 100%, and attempt history persisted. |
| 5. Draft, review, revision, resubmission | **PASS** | Two versions, rubric review, feedback, revision request, and approval persisted. |
| 6. Story publication, reading, progress | **PASS** | QA chapter became visible and reading completion persisted. Approved cultural content is still absent. |
| 7. Notifications for both roles | **PASS** | Teacher received submission notice; student received review notices; read state persisted. |
| 8. Media uploads and image loading | **PASS** | QA cover and illustration uploaded, saved, and downloaded through `get-private-media`. Avatar replacement and actual widget image rendering remain unverified live. |
| 9. Unauthorized restrictions | **PASS** | Student editor check failed as expected and isolated lesson update was denied. Unassigned-teacher and second-student privacy are **NOT VERIFIED**. |

## Automated checks and fixes

- `flutter analyze`: passed with no issues.
- `flutter test`: 114 existing unit and widget tests passed; the opt-in live QA test was skipped in this default run. The opt-in `test/live_readiness_test.dart` ran separately against live Supabase **twice** and passed all ten named checks each time (including cleanup). It reads ignored local account/config files and never prints credentials or tokens.
- Repeat the isolated live run with `flutter test test/live_readiness_test.dart --dart-define-from-file=supabase.local.json --dart-define=LIVE_QA=true`. Each run creates fresh unpublished QA evidence records; use only the dedicated accounts.
- `flutter build apk --debug --dart-define-from-file=supabase.local.json`: passed; generated `build/app/outputs/flutter-apk/app-debug.apk`.
- `flutter build web --dart-define-from-file=supabase.local.json`: passed; generated `build/web`.
- **Issue fixed:** a temporary account-role lookup failure previously left a signed-in user on an error screen with only Sign out. The screen now offers Retry.
- Isolated QA records were created for the live test, then the QA module, lesson, quiz, and story were unpublished. A read-only follow-up query found **zero published `QA ONLY` modules, lessons, quizzes, or stories**. QA attempt, draft, review, notification, and unpublished media records remain for evidence. No pre-existing content was changed. No SQL migrations, RLS changes, or Edge Function deployments were performed.

## Database and deployment review

The application references profiles, teacher_students, curriculum_editors, learning_modules, lessons, lesson_progress, quizzes, quiz_questions, question_options, quiz_attempts, cultural_stories, story_chapters, story_reading_progress, theme_drafts, submissions, reviews, review_scores, rubric_criteria, and notifications. Repository code calls `is_curriculum_editor`, `reorder_module_lessons`, `get_quiz_editor_question_details`, `reorder_quiz_questions`, `submit_quiz`, `reorder_story_chapters`, `submit_theme`, and `complete_review`. Story reading progress is inserted directly. Media code uses `ilocano-profile-avatars` and `ilocano-story-media`.

Local migrations `20261102000004_structured_lessons.sql` and `20261102000005_lesson_authoring_metadata.sql` exist in the working tree. Their columns were present in an authorized student query, and the editor successfully saved structured sections and metadata. The actual migration ledger remains unverified. The live run also exercised quiz, story, submission, review, notification, story media storage, and `get-private-media`. Confirm remaining avatar policies and the full migration ledger in the Supabase dashboard. Do not apply or deploy anything without explicit approval.

Lesson images have no implementation in the lesson editor or lesson schema. This remains deferred for this client test; story covers, chapter illustrations, and profile photos use their separate existing media paths.

## Content and account input needed

- Approved lesson text for the five empty published modules, or agreement to demonstrate a narrower curriculum and hide or unpublish empty modules.
- Source-reviewed Story Vault story and chapter text, with publication approval. No story is currently visible to the student.
- Approved quiz questions and title to replace the visible test-like quiz.
- The dedicated editor and assigned student accounts are available in the ignored local test file. An additional **ordinary non-editor teacher** and **second student** account are needed for broader RLS isolation checks.
- Decide whether to retain the isolated unpublished QA records and their attempt/review/notification evidence. They remain separate from published content.
- An Android phone connected with USB debugging enabled for a real device run.

## Client walkthrough and expected results

Use designated test accounts and approved content. Record pass/fail and screenshots or timestamps for each step. Avoid changing published cultural material during the demonstration without editorial approval.

1. **Student sign-in and navigation:** Sign in, open Dashboard, My Learning, Story Vault, Theme Builder, My Drafts, My Progress, Notifications, and Profile. Expect the student sidebar, correct identity, no teacher management controls, and data to persist after reload. Sign out and sign in again.
2. **Learning:** Open a published approved module and structured lesson; review overview, reading time, sections, and legacy lesson formatting. Mark progress, reload, and expect saved completion on the dashboard and progress page.
3. **Quiz:** Open a published approved quiz, answer and submit. Expect result and attempt history to persist after reload; check that the answer key is not exposed before submission.
4. **Story Vault:** Open an approved published story and chapter, view cover and illustration, mark a chapter read, reload, and expect reading progress to persist. This step is blocked until approved content is published.
5. **Theme Builder:** Complete six steps, save a draft, leave and reopen it, then submit. Expect exactly one new submission/version in My Drafts and the teacher Review Queue.
6. **Teacher sign-in and curriculum:** Sign in as an authorized curriculum editor, create a test module and lesson draft, save, reopen, preview, publish, then verify it as the student. Test unpublish and unsaved-change protection. Repeat with a quiz. Confirm an ordinary teacher has read-only curriculum access.
7. **Review Queue:** As the assigned teacher, inspect the submission, score the rubric, request revision, and add feedback. As the student, inspect feedback and notification, revise, and resubmit. As the teacher, approve the new version. Expect version history and decision to persist on both sides; an unassigned teacher must not see the student.
8. **Media and notifications:** As editor, upload a story cover and chapter illustration, save, reload, and confirm images display. Test avatar replacement similarly with the owner account. Verify teacher submission notification and student review notification, including read state.
9. **Android:** Install and run the built debug APK on the connected phone. Repeat sign-in, lesson, quiz, draft, story, and image smoke checks at phone width. Compare saved records with Web.

## Next actions

First, obtain approved content and test Android runtime and the remaining UI publish/upload actions. Confirm the full migration ledger and remaining avatar policies without changing them. Use an unassigned teacher and a second student for the remaining privacy checks. The teacher-to-student repository workflow and core teacher Web screens passed live; the release remains **NOT READY for an unrestricted content demonstration** until client-approved learning and story material is available and the remaining UI/device checks pass.
