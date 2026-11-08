# Teacher User Manual

## Regular Teacher access and class codes

Teacher accounts are provisioned by the project owner. Sign in with the supplied credentials. A regular Teacher can generate, view, copy, and revoke an active class code from Profile. Students use that code to connect to the teacher; generating a replacement does not remove existing assignments.

## Dashboard and assigned students

The teacher dashboard summarizes assigned students, pending submissions, completed reviews, revision requests, and recent activity. Open a student to view the available progress detail. Access is assignment-scoped by the backend policies and review checks.

## Curriculum modules and lessons

Curriculum management is available to an authorized curriculum editor. Create or open a module, add lesson metadata and structured sections, save as draft/unpublished, reopen, edit, and preview. Publish only client-approved content. Ordinary teachers retain read-only curriculum access.

## Structured lesson creation

Use the structured lesson editor for overview, objectives, introduction, discussion, summary, and reading-time estimate. Save and preview before publication. Protect important text by saving before leaving; on Web, the editor includes an unload/unsaved-change guard where supported.

## Publishing

Publication makes content available to the relevant student queries. Verify title, text, lesson order, and media before confirming. Unpublish when content must be withdrawn. The existing evidence verified repository publication and UI draft/preview flows; UI completion of every publish/unpublish action remains a client walkthrough item.

## Quiz management

Create a quiz, add questions and options, identify exactly one correct option where required, save, preview, and publish approved content. Review question order and student-facing wording before publishing.

## Story Vault management

Create story metadata, add chapters, enter chapter text, save, preview, and manage cover/illustration media. Keep cultural content unpublished until reviewed. Private media is served through the authenticated media function rather than exposing storage paths directly.

## Review Queue and rubric scoring

Open Review Queue, filter/search as needed, select an assigned student submission, inspect the draft/version, and score the rubric criteria. Add feedback, then choose the appropriate decision such as approval or revision request. The student receives the decision/feedback through drafts and notifications.

## Student progress and notifications

Use the student progress view for lesson completion, quiz results, and activity. Notifications surface new submissions and review events. Confirm the selected student is assigned before reviewing or sharing information.

## Regular Teacher permissions

Regular Teachers can:

- Generate, view, copy, and revoke class codes.
- View assigned students and monitor learning progress.
- Review submitted work and provide feedback and rubric scores.
- Manage their own profile and avatar.

Regular Teachers cannot create, edit, publish, unpublish, or delete official curriculum modules, lessons, quizzes, stories, or chapters. Those controls are hidden and enforced by Supabase authorization.

## Curriculum Editor permissions

A Curriculum Editor is a Teacher account with an additional owner-provisioned permission. Curriculum Editors can create, edit, preview, publish, and manage modules, structured lessons, quizzes, Story Vault stories, and chapters. They can delete eligible unpublished modules, lessons, quizzes, stories, and chapters.

Deletion is permanent and restricted. Published content must be unpublished first; lessons and chapters with student progress cannot be deleted; quizzes with student attempts cannot be deleted; and module deletion may remove dependent unpublished lessons, quizzes, questions, and options after all protections pass. Story/chapter deletion can affect reading progress and private media, so the server checks dependencies and media references.

Curriculum management is separate from regular teaching duties. A Curriculum Editor still reviews assigned student work as a Teacher, but the additional permission should be granted only to the client-designated content owner.

