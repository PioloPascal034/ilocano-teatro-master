// Opt-in live QA. Run only with dedicated accounts and --dart-define=LIVE_QA=true.
// Credentials are read from local ignored files and are never printed.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ilocano_teatro_master/core/storage/private_media_repository.dart';
import 'package:ilocano_teatro_master/features/drafts/data/theme_draft_repository.dart';
import 'package:ilocano_teatro_master/features/learning/data/student_learning_repository.dart';
import 'package:ilocano_teatro_master/features/notifications/data/notification_repository.dart';
import 'package:ilocano_teatro_master/features/quiz/data/quiz_management_repository.dart';
import 'package:ilocano_teatro_master/features/quiz/data/quiz_repository.dart';
import 'package:ilocano_teatro_master/features/story_vault/data/story_vault_repository.dart';
import 'package:ilocano_teatro_master/features/story_vault/models/story_models.dart';
import 'package:ilocano_teatro_master/features/teacher/data/curriculum_repository.dart';
import 'package:ilocano_teatro_master/features/teacher/data/teacher_review_repository.dart';
import 'package:ilocano_teatro_master/features/teacher/models/teacher_review_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  const enabled = bool.fromEnvironment('LIVE_QA');
  test('isolated Supabase client readiness workflows', () async {
    final config =
        jsonDecode(File('supabase.local.json').readAsStringSync())
            as Map<String, dynamic>;
    final accounts =
        jsonDecode(File('.qa-test-accounts.local.json').readAsStringSync())
            as Map<String, dynamic>;
    final studentAccount = accounts['student'] as Map<String, dynamic>;
    final teacherAccount = accounts['teacher'] as Map<String, dynamic>;
    final url = config['SUPABASE_URL'] as String;
    final key = config['SUPABASE_PUBLISHABLE_KEY'] as String;
    final student = SupabaseClient(url, key);
    final teacher = SupabaseClient(url, key);
    final checks = <String, String>{};
    final suffix = DateTime.now().toUtc().microsecondsSinceEpoch;
    final label = 'QA ONLY $suffix';
    String? moduleId;
    String? lessonId;
    String? quizId;
    String? storyId;
    String? draftId;
    String? firstSubmissionId;
    String? secondSubmissionId;
    String? questionId;
    String? correctOptionId;
    String? coverPath;
    String? illustrationPath;

    Future<bool> check(String name, Future<void> Function() action) async {
      try {
        await action();
        checks[name] = 'PASS';
        // Names and statuses only. Never print credentials, tokens, or row data.
        // ignore: avoid_print
        print('LIVE_QA $name PASS');
        return true;
      } catch (error) {
        checks[name] = 'FAIL';
        final code = error is PostgrestException
            ? error.code ?? 'postgrest'
            : error is AuthException
            ? error.statusCode ?? 'auth'
            : error.runtimeType.toString();
        // ignore: avoid_print
        print('LIVE_QA $name FAIL $code');
        return false;
      }
    }

    try {
      final logins = await check('account_login_roles', () async {
        final studentSession = await student.auth.signInWithPassword(
          email: studentAccount['email'] as String,
          password: studentAccount['password'] as String,
        );
        final teacherSession = await teacher.auth.signInWithPassword(
          email: teacherAccount['email'] as String,
          password: teacherAccount['password'] as String,
        );
        if (studentSession.user == null || teacherSession.user == null) {
          throw StateError('account session missing');
        }
        final studentProfile = await student
            .from('profiles')
            .select('role')
            .eq('id', student.auth.currentUser!.id)
            .single();
        final teacherProfile = await teacher
            .from('profiles')
            .select('role')
            .eq('id', teacher.auth.currentUser!.id)
            .single();
        if (studentProfile['role'] != 'student' ||
            teacherProfile['role'] != 'teacher') {
          throw StateError('role mismatch');
        }
        final studentEditor = await student.rpc('is_curriculum_editor');
        final teacherEditor = await teacher.rpc('is_curriculum_editor');
        if (studentEditor != false || teacherEditor != true) {
          throw StateError('editor permission mismatch');
        }
        final assignment = await teacher
            .from('teacher_students')
            .select('student_id')
            .eq('teacher_id', teacher.auth.currentUser!.id)
            .eq('student_id', student.auth.currentUser!.id);
        if (assignment.isEmpty) throw StateError('test assignment missing');
      });
      if (!logins) throw StateError('Dedicated account login failed');

      final curriculum = SupabaseCurriculumRepository(client: teacher);
      final studentCurriculum = SupabaseStudentLearningRepository(
        client: student,
      );
      final quizEditor = SupabaseQuizManagementRepository(client: teacher);
      final quizStudent = SupabaseQuizRepository(client: student);
      final teacherStory = SupabaseStoryVaultRepository(client: teacher);
      final studentStory = SupabaseStoryVaultRepository(client: student);
      final studentDrafts = SupabaseThemeDraftRepository(client: student);
      final teacherReviews = SupabaseTeacherReviewRepository(client: teacher);
      final teacherNotifications = SupabaseNotificationRepository(teacher);
      final studentNotifications = SupabaseNotificationRepository(student);

      await check('role_restrictions', () async {
        final studentRepository = SupabaseCurriculumRepository(client: student);
        if (await studentRepository.isCurriculumEditor()) {
          throw StateError('student is editor');
        }
        try {
          await studentRepository.createModule(
            title: '$label forbidden',
            description: 'Must not be created',
          );
          throw StateError('student created module');
        } on StateError catch (error) {
          if (error.message == 'student created module') rethrow;
        }
        final studentStoryRepository = SupabaseStoryVaultRepository(
          client: student,
        );
        if (await studentStoryRepository.isCurriculumEditor()) {
          throw StateError('student can edit stories');
        }
      });

      final lessonReady = await check('lesson_publish_read_progress', () async {
        await curriculum.loadModules();
        final module = await curriculum.createModule(
          title: '$label module',
          description: 'Isolated automated client-readiness test record.',
        );
        moduleId = module.id;
        final lesson = await curriculum.createLesson(
          moduleId: module.id,
          title: '$label structured lesson',
          objectives: 'Verify isolated test content rendering.',
          content: 'Synthetic QA lesson, not educational material.',
          sections: {
            'introduction': 'Synthetic introduction for QA.',
            'discussion': 'Synthetic discussion for QA.',
            'examples': 'Synthetic example for QA.',
            'activities': 'Synthetic activity for QA.',
            'summary': 'Synthetic summary for QA.',
          },
          overview: 'Synthetic overview for QA.',
          estimatedReadingMinutes: 2,
        );
        lessonId = lesson.id;
        final drafts = await curriculum.loadModules();
        final saved = drafts
            .firstWhere((item) => item.id == module.id)
            .lessons
            .firstWhere((item) => item.id == lesson.id);
        if (saved.overview != 'Synthetic overview for QA.' ||
            saved.estimatedReadingMinutes != 2 ||
            saved.sections['summary'] != 'Synthetic summary for QA.') {
          throw StateError('lesson metadata did not persist');
        }
        await curriculum.setLessonPublished(
          lessonId: lesson.id,
          isPublished: true,
        );
        await curriculum.setModulePublished(
          moduleId: module.id,
          isPublished: true,
        );
        final visible = await studentCurriculum.loadLesson(
          moduleId: module.id,
          lessonId: lesson.id,
        );
        if (visible == null || visible.overview != saved.overview) {
          throw StateError('student lesson visibility failed');
        }
        await studentCurriculum.markLessonInProgress(lesson.id);
        await studentCurriculum.markLessonCompleted(lesson.id);
        final persisted = await studentCurriculum.loadLesson(
          moduleId: module.id,
          lessonId: lesson.id,
        );
        if (persisted?.isCompleted != true) {
          throw StateError('lesson progress did not persist');
        }
      });

      if (lessonReady && moduleId != null) {
        await check('quiz_publish_answer_result', () async {
          final quiz = await quizEditor.createQuiz(
            moduleId: moduleId!,
            title: '$label quiz',
            description: 'Synthetic QA question, not educational content.',
            passingScore: 70,
          );
          quizId = quiz.id;
          questionId = await quizEditor.createQuestion(
            quizId: quiz.id,
            text: 'Which option is the isolated QA correct answer?',
            explanation: 'Synthetic QA explanation.',
          );
          correctOptionId = await quizEditor.createOption(
            questionId: questionId!,
            text: 'QA correct',
            isCorrect: true,
          );
          await quizEditor.createOption(
            questionId: questionId!,
            text: 'QA incorrect',
            isCorrect: false,
          );
          await quizEditor.setPublished(quizId: quiz.id, isPublished: true);
          final loaded = await quizStudent.loadQuiz(quiz.id);
          if (loaded == null || loaded.questions.length != 1) {
            throw StateError('student quiz visibility failed');
          }
          final result = await quizStudent.submitAnswers(
            quizId: quiz.id,
            answersByQuestion: {questionId!: correctOptionId!},
          );
          if (result.score != 100) throw StateError('quiz score mismatch');
          final attempts = await quizStudent.loadMyAttempts();
          if (!attempts.any((attempt) => attempt.quizId == quiz.id)) {
            throw StateError('quiz attempt did not persist');
          }
        });
      } else {
        checks['quiz_publish_answer_result'] = 'NOT VERIFIED';
      }

      final draftSaved = await check('draft_save_submit', () async {
        final saved = await studentDrafts.saveDraft(
          ThemeDraft(
            id: '',
            title: '$label concept',
            status: 'draft',
            updatedAt: DateTime.now(),
            centralMessage: 'Synthetic QA message.',
            dramaticConflict: 'Synthetic QA conflict.',
            characters: 'Synthetic QA characters.',
            targetAudience: 'Synthetic QA audience.',
            stageConcept: 'Synthetic QA stage.',
            sourceAcknowledgment: 'Isolated system test; no cultural source.',
          ),
        );
        draftId = saved.id;
        if (!saved.complete) throw StateError('draft completeness failed');
        firstSubmissionId = await studentDrafts.submitDraft(saved.id);
        final persisted = await studentDrafts.getDraft(saved.id);
        if (!persisted.submissions.any(
          (submission) => submission.id == firstSubmissionId,
        )) {
          throw StateError('submission did not persist');
        }
      });

      if (draftSaved && firstSubmissionId != null) {
        await check('teacher_review_revision_resubmit', () async {
          final queue = await teacherReviews.loadQueue();
          if (!queue.any((item) => item.id == firstSubmissionId)) {
            throw StateError('assigned queue missing submission');
          }
          final review = await teacherReviews.loadReview(firstSubmissionId!);
          if (review.criteria.isEmpty) throw StateError('rubric missing');
          final scores = {for (final item in review.criteria) item.id: 3};
          await teacherReviews.completeReview(
            CompleteReviewRequest(
              submissionId: firstSubmissionId!,
              decision: 'revision_requested',
              comment: 'QA feedback: revise the synthetic stage concept.',
              scores: scores,
            ),
          );
          final revised = await studentDrafts.getDraft(draftId!);
          if (revised.status != 'revision_requested' ||
              revised.submissions.first.feedback == null) {
            throw StateError('feedback not visible to student');
          }
          await studentDrafts.saveDraft(
            ThemeDraft(
              id: revised.id,
              title: revised.title,
              status: revised.status,
              updatedAt: revised.updatedAt,
              centralMessage: revised.centralMessage,
              dramaticConflict: revised.dramaticConflict,
              characters: revised.characters,
              targetAudience: revised.targetAudience,
              stageConcept: 'Synthetic QA stage, revised.',
              sourceAcknowledgment: revised.sourceAcknowledgment,
            ),
          );
          secondSubmissionId = await studentDrafts.submitDraft(revised.id);
          final resubmitted = await studentDrafts.getDraft(revised.id);
          if (resubmitted.submissions.length != 2 ||
              resubmitted.submissions.first.version != 2) {
            throw StateError('revision history did not persist');
          }
          await teacherReviews.completeReview(
            CompleteReviewRequest(
              submissionId: secondSubmissionId!,
              decision: 'approved',
              comment: 'QA approval of revised synthetic concept.',
              scores: scores,
            ),
          );
          final approved = await studentDrafts.getDraft(revised.id);
          if (approved.status != 'approved') {
            throw StateError('approval did not persist');
          }
        });
      } else {
        checks['teacher_review_revision_resubmit'] = 'NOT VERIFIED';
      }

      await check('role_notifications', () async {
        if (firstSubmissionId == null || secondSubmissionId == null) {
          throw StateError('review flow unavailable');
        }
        final teacherItems = await teacherNotifications.loadNotifications();
        final studentItems = await studentNotifications.loadNotifications();
        if (!teacherItems.any(
              (item) => item.relatedSubmissionId == firstSubmissionId,
            ) ||
            !studentItems.any(
              (item) => item.relatedSubmissionId == firstSubmissionId,
            ) ||
            !studentItems.any(
              (item) => item.relatedSubmissionId == secondSubmissionId,
            )) {
          throw StateError('role notification missing');
        }
        final studentNotice = studentItems.firstWhere(
          (item) => item.relatedSubmissionId == secondSubmissionId,
        );
        await studentNotifications.markRead(studentNotice.id, true);
        final refreshed = await studentNotifications.loadNotifications();
        if (!refreshed
            .firstWhere((item) => item.id == studentNotice.id)
            .isRead) {
          throw StateError('notification read state did not persist');
        }
      });

      await check('story_publish_read_progress_media', () async {
        final story = await teacherStory.saveStory(
          StoryMetadataInput(
            title: '$label story',
            summary: 'Synthetic QA story only; no cultural content.',
            sourceTitle: 'Isolated system test',
            isPublished: false,
          ),
        );
        storyId = story.id;
        final chapter = await teacherStory.saveChapter(
          StoryChapterInput(
            storyId: story.id,
            title: '$label chapter',
            content: 'Synthetic QA chapter text, not educational material.',
            order: 1,
            isPublished: false,
          ),
        );
        final bytes = await File('assets/branding/applogo.png').readAsBytes();
        coverPath = await teacherStory.uploadImage(
          storyId: story.id,
          bytes: bytes,
        );
        illustrationPath = await teacherStory.uploadImage(
          storyId: story.id,
          chapterId: chapter.id,
          bytes: bytes,
        );
        await teacherStory.saveChapter(
          StoryChapterInput(
            id: chapter.id,
            storyId: story.id,
            title: chapter.title,
            content: chapter.content,
            order: chapter.order,
            isPublished: true,
            illustrationStoragePath: illustrationPath,
            illustrationAltText: 'QA test image',
          ),
        );
        await teacherStory.saveStory(
          StoryMetadataInput(
            id: story.id,
            title: story.title,
            summary: story.summary,
            sourceTitle: story.sourceTitle,
            coverStoragePath: coverPath,
            coverAltText: 'QA test image',
            isPublished: true,
          ),
        );
        final visible = await studentStory.loadStory(story.id);
        if (visible == null ||
            !visible.isPublished ||
            visible.publishedChapters.length != 1 ||
            visible.coverStoragePath != coverPath) {
          throw StateError('student story visibility failed');
        }
        final cover = await studentStory.downloadImage(
          type: PrivateMediaType.storyCover,
          recordId: story.id,
          cacheVersion: coverPath!,
        );
        final illustration = await studentStory.downloadImage(
          type: PrivateMediaType.chapterIllustration,
          recordId: chapter.id,
          cacheVersion: illustrationPath!,
        );
        if (cover.isEmpty || illustration.isEmpty) {
          throw StateError('private media did not load');
        }
        await studentStory.markChapterRead(chapter.id);
        final reread = await studentStory.loadStory(story.id);
        if (reread?.completion != 1) {
          throw StateError('story reading progress did not persist');
        }
      });

      await check('private_data_restrictions', () async {
        if (lessonId != null) {
          try {
            final changed = await student
                .from('lessons')
                .update({'title': '$label unauthorized'})
                .eq('lesson_id', lessonId!)
                .select('lesson_id');
            if (changed.isNotEmpty) {
              throw StateError('student changed editor lesson');
            }
          } on PostgrestException {
            // A permission error is the expected alternative to zero rows.
          }
        }
        if (draftId != null) {
          final other = await teacher
              .from('theme_drafts')
              .select('draft_id')
              .eq('draft_id', draftId!);
          if (other.isEmpty) {
            throw StateError('assigned teacher cannot see draft');
          }
        }
      });
    } finally {
      // Keep all QA records for evidence, but remove them from student-facing
      // publication. Never touch pre-existing records.
      if (teacher.auth.currentUser != null) {
        final cleanup = await check('qa_content_unpublished', () async {
          var failed = false;
          Future<void> attempt(Future<void> Function() action) async {
            try {
              await action();
            } catch (_) {
              failed = true;
            }
          }

          if (storyId != null) {
            await attempt(
              () => SupabaseStoryVaultRepository(client: teacher).saveStory(
                StoryMetadataInput(
                  id: storyId,
                  title: '$label story',
                  summary: 'Synthetic QA story only; no cultural content.',
                  sourceTitle: 'Isolated system test',
                  coverStoragePath: coverPath,
                  coverAltText: 'QA test image',
                  isPublished: false,
                ),
              ),
            );
          }
          if (quizId != null) {
            await attempt(
              () => SupabaseQuizManagementRepository(
                client: teacher,
              ).setPublished(quizId: quizId!, isPublished: false),
            );
          }
          if (lessonId != null) {
            await attempt(
              () => SupabaseCurriculumRepository(
                client: teacher,
              ).setLessonPublished(lessonId: lessonId!, isPublished: false),
            );
          }
          if (moduleId != null) {
            await attempt(
              () => SupabaseCurriculumRepository(
                client: teacher,
              ).setModulePublished(moduleId: moduleId!, isPublished: false),
            );
          }
          if (failed) throw StateError('QA publication cleanup failed');
          if (moduleId != null &&
              await SupabaseStudentLearningRepository(
                    client: student,
                  ).loadModule(moduleId!) !=
                  null) {
            throw StateError('QA module remains visible');
          }
          if (quizId != null &&
              await SupabaseQuizRepository(client: student).loadQuiz(quizId!) !=
                  null) {
            throw StateError('QA quiz remains visible');
          }
          if (storyId != null &&
              await SupabaseStoryVaultRepository(
                    client: student,
                  ).loadStory(storyId!) !=
                  null) {
            throw StateError('QA story remains visible');
          }
        });
        if (!cleanup) {
          // ignore: avoid_print
          print('LIVE_QA ACTION REQUIRED: manually unpublish QA ONLY records');
        }
      }
      await student.dispose();
      await teacher.dispose();
    }
    expect(
      checks.values.where((status) => status != 'PASS'),
      isEmpty,
      reason:
          'Live QA failures: ${checks.entries.where((e) => e.value != 'PASS').map((e) => e.key).join(', ')}',
    );
  }, skip: !enabled);
}
