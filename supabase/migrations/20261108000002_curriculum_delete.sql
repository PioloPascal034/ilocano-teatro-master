-- Curriculum-editor-only deletion for testing curriculum content.
-- Review and apply manually after the curriculum and quiz tables/policies.
-- This migration is not applied by the Flutter client.

begin;

create or replace function public.delete_curriculum_lesson(p_lesson_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  lesson_published boolean;
begin
  if not (select public.is_curriculum_editor()) then
    raise exception 'Curriculum editor permission required'
      using errcode = '42501';
  end if;

  select l.is_published
    into lesson_published
  from public.lessons as l
  where l.lesson_id = p_lesson_id
  for update;

  if not found then
    raise exception 'Lesson not found' using errcode = 'P0002';
  end if;

  if lesson_published then
    raise exception 'Unpublish the lesson before deleting it'
      using errcode = '55000';
  end if;

  if exists (
    select 1
    from public.lesson_progress as lp
    where lp.lesson_id = p_lesson_id
  ) then
    raise exception 'Lesson has student progress and cannot be deleted'
      using errcode = '55000';
  end if;

  -- lesson_progress has ON DELETE CASCADE, but the explicit guard above keeps
  -- student learning history from being silently destroyed.
  delete from public.lessons
  where lesson_id = p_lesson_id;
end;
$$;

alter function public.delete_curriculum_lesson(uuid) owner to postgres;
revoke all on function public.delete_curriculum_lesson(uuid)
  from public, anon, service_role;
grant execute on function public.delete_curriculum_lesson(uuid)
  to authenticated;

create or replace function public.delete_curriculum_module(p_module_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  module_locked uuid;
begin
  if not (select public.is_curriculum_editor()) then
    raise exception 'Curriculum editor permission required'
      using errcode = '42501';
  end if;

  select m.module_id
    into module_locked
  from public.learning_modules as m
  where m.module_id = p_module_id
  for update;

  if not found then
    raise exception 'Module not found' using errcode = 'P0002';
  end if;

  -- Lock every dependent parent row before checking publication, progress,
  -- and attempts. Concurrent publish/insert operations then wait and cannot
  -- race this deletion decision.
  perform 1
  from public.lessons as l
  where l.module_id = module_locked
  for update;
  perform 1
  from public.quizzes as q
  where q.module_id = module_locked
  for update;

  if exists (
    select 1
    from public.learning_modules as m
    where m.module_id = module_locked and m.is_published
  ) or exists (
    select 1
    from public.lessons as l
    where l.module_id = module_locked and l.is_published
  ) or exists (
    select 1
    from public.quizzes as q
    where q.module_id = module_locked and q.is_published
  ) then
    raise exception 'Unpublish the module, lessons, and quizzes before deleting it'
      using errcode = '55000';
  end if;

  if exists (
    select 1
    from public.lesson_progress as lp
    join public.lessons as l on l.lesson_id = lp.lesson_id
    where l.module_id = module_locked
  ) then
    raise exception 'Module lessons have student progress and cannot be deleted'
      using errcode = '55000';
  end if;

  if exists (
    select 1
    from public.quiz_attempts as qa
    join public.quizzes as q on q.quiz_id = qa.quiz_id
    where q.module_id = module_locked
  ) then
    raise exception 'Module quizzes have student attempts and cannot be deleted'
      using errcode = '55000';
  end if;

  -- The remaining dependent rows are unpublished and have no attempts. The
  -- existing FK cascade removes lessons, quizzes, questions, and options.
  delete from public.learning_modules
  where module_id = module_locked;
end;
$$;

alter function public.delete_curriculum_module(uuid) owner to postgres;
revoke all on function public.delete_curriculum_module(uuid)
  from public, anon, service_role;
grant execute on function public.delete_curriculum_module(uuid)
  to authenticated;

create or replace function public.delete_curriculum_quiz(p_quiz_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  quiz_published boolean;
begin
  if not (select public.is_curriculum_editor()) then
    raise exception 'Curriculum editor permission required'
      using errcode = '42501';
  end if;

  select q.is_published
    into quiz_published
  from public.quizzes as q
  where q.quiz_id = p_quiz_id
  for update;

  if not found then
    raise exception 'Quiz not found' using errcode = 'P0002';
  end if;

  if quiz_published then
    raise exception 'Unpublish the quiz before deleting it'
      using errcode = '55000';
  end if;

  if exists (
    select 1
    from public.quiz_attempts as qa
    where qa.quiz_id = p_quiz_id
  ) then
    raise exception 'Quiz has student attempts and cannot be deleted'
      using errcode = '55000';
  end if;

  -- Questions and answer options cascade from the quiz. With no attempts,
  -- quiz_answers cannot remain to block those dependent deletes.
  delete from public.quizzes
  where quiz_id = p_quiz_id;
end;
$$;

alter function public.delete_curriculum_quiz(uuid) owner to postgres;
revoke all on function public.delete_curriculum_quiz(uuid)
  from public, anon, service_role;
grant execute on function public.delete_curriculum_quiz(uuid)
  to authenticated;

commit;
