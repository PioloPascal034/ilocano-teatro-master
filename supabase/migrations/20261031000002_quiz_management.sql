-- Phase 4D: Curriculum Editor quiz authoring with attempt-history protection.
-- Requires the base setup and the curriculum-editor migration to be applied.
-- This migration does not delete or rewrite quiz, attempt, or answer rows.

begin;

-- Preserve safe student reads. Never expose is_correct directly through a
-- client table SELECT; editors retrieve answer keys only through a gated RPC.
grant select on public.quizzes, public.quiz_questions to authenticated;
-- Question explanations can disclose the correct answer. Students only need
-- prompt/order fields; Curriculum Editors retrieve explanations through the
-- editor-gated details RPC below.
revoke select on public.quiz_questions from public, anon, authenticated;
grant select (question_id, quiz_id, question_text, question_order)
  on public.quiz_questions to authenticated;
revoke select on public.question_options from public, anon, authenticated;
revoke select (is_correct) on public.question_options
  from public, anon, authenticated;
grant select (option_id, question_id, option_text, display_order)
  on public.question_options to authenticated;

-- Keep quiz-writing columns limited and leave trusted service_role privileges
-- untouched. No client permanent-delete privileges are provided.
revoke insert, update, delete on public.quizzes from public, anon, authenticated;
revoke insert, update, delete on public.quiz_questions from public, anon, authenticated;
revoke insert, update, delete on public.question_options from public, anon, authenticated;

grant insert (module_id, title, description, passing_score, is_published)
  on public.quizzes to authenticated;
grant update (title, description, passing_score, is_published)
  on public.quizzes to authenticated;
grant insert (quiz_id, question_text, explanation, question_order)
  on public.quiz_questions to authenticated;
grant update (question_text, explanation)
  on public.quiz_questions to authenticated;
grant insert (question_id, option_text, is_correct, display_order)
  on public.question_options to authenticated;
grant update (option_text, is_correct)
  on public.question_options to authenticated;

-- Attempts and answer snapshots are written only by the server-side submit RPC.
-- Preserve trusted service_role permissions by not revoking them here.
revoke insert, update, delete on public.quiz_attempts, public.quiz_answers
  from public, anon, authenticated;

-- Existing published-only policies remain. These policies add visibility and
-- writes only for designated Curriculum Editors.
drop policy if exists quizzes_curriculum_editor_read on public.quizzes;
create policy quizzes_curriculum_editor_read on public.quizzes
  for select to authenticated
  using ((select public.is_curriculum_editor()));

drop policy if exists quizzes_curriculum_editor_insert on public.quizzes;
create policy quizzes_curriculum_editor_insert on public.quizzes
  for insert to authenticated
  with check ((select public.is_curriculum_editor()));

drop policy if exists quizzes_curriculum_editor_update on public.quizzes;
create policy quizzes_curriculum_editor_update on public.quizzes
  for update to authenticated
  using ((select public.is_curriculum_editor()))
  with check ((select public.is_curriculum_editor()));

drop policy if exists questions_curriculum_editor_read on public.quiz_questions;
create policy questions_curriculum_editor_read on public.quiz_questions
  for select to authenticated
  using ((select public.is_curriculum_editor()));

drop policy if exists questions_curriculum_editor_insert on public.quiz_questions;
create policy questions_curriculum_editor_insert on public.quiz_questions
  for insert to authenticated
  with check (
    (select public.is_curriculum_editor())
    and exists (
      select 1 from public.quizzes q
      where q.quiz_id = quiz_questions.quiz_id
    )
  );

drop policy if exists questions_curriculum_editor_update on public.quiz_questions;
create policy questions_curriculum_editor_update on public.quiz_questions
  for update to authenticated
  using (
    (select public.is_curriculum_editor())
    and exists (
      select 1 from public.quizzes q
      where q.quiz_id = quiz_questions.quiz_id
    )
  )
  with check (
    (select public.is_curriculum_editor())
    and exists (
      select 1 from public.quizzes q
      where q.quiz_id = quiz_questions.quiz_id
    )
  );

drop policy if exists options_curriculum_editor_read on public.question_options;
create policy options_curriculum_editor_read on public.question_options
  for select to authenticated
  using ((select public.is_curriculum_editor()));

drop policy if exists options_curriculum_editor_insert on public.question_options;
create policy options_curriculum_editor_insert on public.question_options
  for insert to authenticated
  with check (
    (select public.is_curriculum_editor())
    and exists (
      select 1
      from public.quiz_questions qq
      join public.quizzes q on q.quiz_id = qq.quiz_id
      where qq.question_id = question_options.question_id
    )
  );

drop policy if exists options_curriculum_editor_update on public.question_options;
create policy options_curriculum_editor_update on public.question_options
  for update to authenticated
  using (
    (select public.is_curriculum_editor())
    and exists (
      select 1
      from public.quiz_questions qq
      join public.quizzes q on q.quiz_id = qq.quiz_id
      where qq.question_id = question_options.question_id
    )
  )
  with check (
    (select public.is_curriculum_editor())
    and exists (
      select 1
      from public.quiz_questions qq
      join public.quizzes q on q.quiz_id = qq.quiz_id
      where qq.question_id = question_options.question_id
    )
  );

-- A quiz cannot be published without at least one question, at least two
-- options per question, and exactly one correct option per question.
-- The installed default is is_published=true; Flutter must explicitly create
-- quizzes as unpublished.
create or replace function public.validate_published_quiz()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  question_count integer;
begin
  if (select auth.uid()) is not null
     and not (select public.is_curriculum_editor()) then
    raise exception 'Curriculum editor permission required'
      using errcode = '42501';
  end if;
  if new.is_published then
    select count(*)::integer into question_count
    from public.quiz_questions q
    where q.quiz_id = new.quiz_id;

    if question_count = 0 then
      raise exception 'A quiz needs at least one question before publishing'
        using errcode = '23514';
    end if;

    if exists (
      select 1
      from public.quiz_questions q
      where q.quiz_id = new.quiz_id
        and (
          (select count(*) from public.question_options o
           where o.question_id = q.question_id) < 2
          or
          (select count(*) from public.question_options o
           where o.question_id = q.question_id and o.is_correct) <> 1
        )
    ) then
      raise exception 'Each question needs at least two options and exactly one correct option'
        using errcode = '23514';
    end if;
  end if;
  return new;
end;
$$;

alter function public.validate_published_quiz() owner to postgres;
revoke all on function public.validate_published_quiz()
  from public, anon, authenticated;
drop trigger if exists quizzes_validate_publish on public.quizzes;
create trigger quizzes_validate_publish
  before insert or update on public.quizzes
  for each row execute function public.validate_published_quiz();

-- Published content must be unpublished before editing. After the first
-- attempt, metadata/scoring and question/option content are immutable. The
-- submit_quiz row lock below serializes submissions against edits.
create or replace function public.guard_quiz_history()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  has_attempts boolean;
  content_changed boolean;
begin
  if (select auth.uid()) is not null
     and not (select public.is_curriculum_editor()) then
    raise exception 'Curriculum editor permission required'
      using errcode = '42501';
  end if;
  content_changed := row(new.module_id, new.title, new.description, new.passing_score)
    is distinct from row(old.module_id, old.title, old.description, old.passing_score);

  if old.is_published and new.is_published and content_changed then
    raise exception 'Unpublish the quiz before editing its content or settings'
      using errcode = '55000';
  end if;

  select exists (
    select 1 from public.quiz_attempts a where a.quiz_id = old.quiz_id
  ) into has_attempts;
  if has_attempts and content_changed then
    raise exception 'Quiz content and scoring settings are locked after the first attempt'
      using errcode = '55000';
  end if;
  return new;
end;
$$;

alter function public.guard_quiz_history() owner to postgres;
revoke all on function public.guard_quiz_history()
  from public, anon, authenticated;
drop trigger if exists quizzes_guard_history on public.quizzes;
create trigger quizzes_guard_history
  before update on public.quizzes
  for each row execute function public.guard_quiz_history();

-- Child-content changes lock the parent quiz. submit_quiz takes a conflicting
-- share lock before reading questions so score calculation cannot race an edit.
create or replace function public.guard_quiz_question_history()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_quiz_id uuid;
  quiz_published boolean;
  has_attempts boolean;
begin
  if (select auth.uid()) is not null
     and not (select public.is_curriculum_editor()) then
    raise exception 'Curriculum editor permission required'
      using errcode = '42501';
  end if;
  if tg_op = 'UPDATE' then
    if new.quiz_id is distinct from old.quiz_id then
      raise exception 'A question cannot be moved to another quiz'
        using errcode = '55000';
    end if;
  end if;
  if tg_op = 'DELETE' then
    target_quiz_id := old.quiz_id;
  else
    target_quiz_id := new.quiz_id;
  end if;

  select q.is_published into quiz_published
  from public.quizzes q
  where q.quiz_id = target_quiz_id
  for update;
  if not found then
    raise exception 'Quiz not found' using errcode = 'P0002';
  end if;
  if quiz_published then
    raise exception 'Unpublish the quiz before changing its questions'
      using errcode = '55000';
  end if;

  select exists (
    select 1 from public.quiz_attempts a where a.quiz_id = target_quiz_id
  ) into has_attempts;
  if has_attempts then
    raise exception 'Quiz questions are locked after the first attempt'
      using errcode = '55000';
  end if;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

alter function public.guard_quiz_question_history() owner to postgres;
revoke all on function public.guard_quiz_question_history()
  from public, anon, authenticated;
drop trigger if exists quiz_questions_guard_history on public.quiz_questions;
create trigger quiz_questions_guard_history
  before insert or update or delete on public.quiz_questions
  for each row execute function public.guard_quiz_question_history();

create or replace function public.guard_quiz_option_history()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_question_id uuid;
  target_quiz_id uuid;
  quiz_published boolean;
  has_attempts boolean;
begin
  if (select auth.uid()) is not null
     and not (select public.is_curriculum_editor()) then
    raise exception 'Curriculum editor permission required'
      using errcode = '42501';
  end if;
  if tg_op = 'UPDATE' then
    if new.question_id is distinct from old.question_id then
      raise exception 'An answer option cannot be moved to another question'
        using errcode = '55000';
    end if;
  end if;
  if tg_op = 'DELETE' then
    target_question_id := old.question_id;
  else
    target_question_id := new.question_id;
  end if;

  select q.quiz_id, q.is_published into target_quiz_id, quiz_published
  from public.quiz_questions qq
  join public.quizzes q on q.quiz_id = qq.quiz_id
  where qq.question_id = target_question_id
  for update of q;
  if not found then
    raise exception 'Quiz question not found' using errcode = 'P0002';
  end if;
  if quiz_published then
    raise exception 'Unpublish the quiz before changing its answer options'
      using errcode = '55000';
  end if;

  select exists (
    select 1 from public.quiz_attempts a where a.quiz_id = target_quiz_id
  ) into has_attempts;
  if has_attempts then
    raise exception 'Answer options are locked after the first attempt'
      using errcode = '55000';
  end if;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

alter function public.guard_quiz_option_history() owner to postgres;
revoke all on function public.guard_quiz_option_history()
  from public, anon, authenticated;
drop trigger if exists question_options_guard_history on public.question_options;
create trigger question_options_guard_history
  before insert or update or delete on public.question_options
  for each row execute function public.guard_quiz_option_history();

-- Editors retrieve explanations and correct flags through this role-checked
-- RPC. Authenticated clients never receive direct SELECT on either field.
create or replace function public.get_quiz_editor_question_details(p_quiz_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  result jsonb;
begin
  if not (select public.is_curriculum_editor()) then
    raise exception 'Curriculum editor permission required'
      using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.quizzes q where q.quiz_id = p_quiz_id
  ) then
    raise exception 'Quiz not found' using errcode = 'P0002';
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'question_id', q.question_id,
        'explanation', q.explanation,
        'options', coalesce((
          select jsonb_agg(
            jsonb_build_object('option_id', o.option_id, 'is_correct', o.is_correct)
            order by o.display_order
          )
          from public.question_options o
          where o.question_id = q.question_id
        ), '[]'::jsonb)
      ) order by q.question_order
    ),
    '[]'::jsonb
  ) into result
  from public.quiz_questions q
  where q.quiz_id = p_quiz_id;
  return result;
end;
$$;

alter function public.get_quiz_editor_question_details(uuid) owner to postgres;
revoke all on function public.get_quiz_editor_question_details(uuid)
  from public, anon;
grant execute on function public.get_quiz_editor_question_details(uuid)
  to authenticated, service_role;

-- Atomic reorder for the installed UNIQUE(quiz_id, question_order) constraint.
create or replace function public.reorder_quiz_questions(
  p_quiz_id uuid,
  p_question_ids uuid[]
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  question_count integer;
  distinct_id_count integer;
  min_order integer;
  temp_base bigint;
  quiz_published boolean;
begin
  if not (select public.is_curriculum_editor()) then
    raise exception 'Curriculum editor permission required'
      using errcode = '42501';
  end if;
  if p_quiz_id is null or p_question_ids is null then
    raise exception 'A quiz and complete question order are required'
      using errcode = '22004';
  end if;

  select q.is_published into quiz_published
  from public.quizzes q
  where q.quiz_id = p_quiz_id
  for update;
  if not found then
    raise exception 'Quiz not found' using errcode = 'P0002';
  end if;
  if quiz_published then
    raise exception 'Unpublish the quiz before reordering questions'
      using errcode = '55000';
  end if;
  if exists (
    select 1 from public.quiz_attempts a where a.quiz_id = p_quiz_id
  ) then
    raise exception 'Questions cannot be reordered after the first attempt'
      using errcode = '55000';
  end if;

  select count(*)::integer, coalesce(min(q.question_order), 0)
    into question_count, min_order
  from public.quiz_questions q
  where q.quiz_id = p_quiz_id;
  if cardinality(p_question_ids) <> question_count then
    raise exception 'Provide every quiz question exactly once'
      using errcode = '22023';
  end if;
  select count(distinct requested.question_id)::integer
    into distinct_id_count
  from unnest(p_question_ids) as requested(question_id);
  if distinct_id_count <> question_count then
    raise exception 'Question identifiers must be unique and non-null'
      using errcode = '22023';
  end if;
  if exists (
    select 1
    from unnest(p_question_ids) as requested(question_id)
    left join public.quiz_questions q
      on q.question_id = requested.question_id
     and q.quiz_id = p_quiz_id
    where q.question_id is null
  ) then
    raise exception 'Every question must belong to the requested quiz'
      using errcode = '22023';
  end if;
  if question_count = 0 then return; end if;

  temp_base := min_order::bigint - question_count::bigint;
  if temp_base < -2147483648 then
    raise exception 'Question ordering range is exhausted; no order was changed'
      using errcode = '22003';
  end if;
  update public.quiz_questions q
  set question_order = (temp_base + requested.ordinality - 1)::integer
  from unnest(p_question_ids) with ordinality
    as requested(question_id, ordinality)
  where q.question_id = requested.question_id and q.quiz_id = p_quiz_id;
  update public.quiz_questions q
  set question_order = requested.ordinality::integer
  from unnest(p_question_ids) with ordinality
    as requested(question_id, ordinality)
  where q.question_id = requested.question_id and q.quiz_id = p_quiz_id;
end;
$$;

alter function public.reorder_quiz_questions(uuid, uuid[]) owner to postgres;
revoke all on function public.reorder_quiz_questions(uuid, uuid[])
  from public, anon;
grant execute on function public.reorder_quiz_questions(uuid, uuid[])
  to authenticated, service_role;

-- Lock the quiz/module while computing. This serializes scoring against content
-- edits; scores and answer rows are still written only by trusted server logic.
create or replace function public.submit_quiz(
  p_quiz_id uuid,
  p_answers jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_module_id uuid;
  total_questions integer;
  correct_answers integer;
  percent_score numeric(5,2);
  attempt uuid;
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication required';
  end if;
  if not exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid()) and p.role = 'student'
  ) then
    raise exception 'Only student accounts may submit quizzes'
      using errcode = '42501';
  end if;

  select q.module_id into target_module_id
  from public.quizzes q
  where q.quiz_id = p_quiz_id and q.is_published
  for share;
  if not found then raise exception 'Quiz unavailable'; end if;

  perform 1 from public.learning_modules m
  where m.module_id = target_module_id and m.is_published
  for share;
  if not found then raise exception 'Quiz unavailable'; end if;

  if jsonb_typeof(p_answers) is distinct from 'object' then
    raise exception 'Answers must be an object';
  end if;
  select count(*)::integer into total_questions
  from public.quiz_questions q where q.quiz_id = p_quiz_id;
  if total_questions = 0 then raise exception 'Quiz has no questions'; end if;
  if (select count(*) from jsonb_each_text(p_answers)) <> total_questions then
    raise exception 'Answer every question exactly once';
  end if;
  if exists (
    select 1
    from jsonb_each_text(p_answers) j
    left join public.quiz_questions q
      on q.question_id::text = j.key and q.quiz_id = p_quiz_id
    left join public.question_options o
      on o.option_id::text = j.value and o.question_id = q.question_id
    where o.option_id is null
  ) then
    raise exception 'Invalid answer option';
  end if;

  select count(*)::integer into correct_answers
  from public.quiz_questions q
  join public.question_options o on o.question_id = q.question_id
  where q.quiz_id = p_quiz_id
    and o.is_correct
    and p_answers ->> q.question_id::text = o.option_id::text;
  percent_score := round((correct_answers::numeric / total_questions) * 100, 2);

  insert into public.quiz_attempts(quiz_id, student_id, score, completed_at)
  values (p_quiz_id, (select auth.uid()), percent_score, now())
  returning attempt_id into attempt;
  insert into public.quiz_answers(attempt_id, question_id, selected_option_id)
  select attempt, q.question_id, (p_answers ->> q.question_id::text)::uuid
  from public.quiz_questions q where q.quiz_id = p_quiz_id;

  return jsonb_build_object(
    'attempt_id', attempt,
    'score', percent_score,
    'correct', correct_answers,
    'total', total_questions
  );
end;
$$;

alter function public.submit_quiz(uuid, jsonb) owner to postgres;
revoke all on function public.submit_quiz(uuid, jsonb) from public, anon;
grant execute on function public.submit_quiz(uuid, jsonb)
  to authenticated, service_role;

commit;

-- Apply in staging first, then verify:
-- * students see only published quiz/question/option rows and cannot read is_correct;
-- * ordinary teachers cannot write or call editor answer-key/reorder RPCs;
-- * Curriculum Editors can create, edit unpublished quizzes and read answer keys;
-- * publication fails unless each quiz has >=1 question and each question has
--   >=2 options with exactly one correct option;
-- * after the first attempt, content changes and question reorders fail while
--   unpublishing remains possible and attempts/answers remain intact.
--
-- Example student session (use a disposable student profile UUID):
-- begin;
-- set local role authenticated;
-- select set_config('request.jwt.claim.sub', '<STUDENT_UUID>', true);
-- select public.is_curriculum_editor(); -- false
-- select count(*) from public.quizzes where not is_published; -- 0
-- select count(*) from public.quiz_questions qq
--   join public.quizzes q on q.quiz_id=qq.quiz_id where not q.is_published; -- 0
-- select has_column_privilege('authenticated','public.question_options',
--   'is_correct','SELECT'); -- false
-- select has_table_privilege('authenticated','public.quiz_attempts','UPDATE'); -- false
-- select has_table_privilege('authenticated','public.quiz_answers','INSERT'); -- false
-- select count(*) from public.quiz_attempts where student_id <> auth.uid(); -- 0
-- rollback;
--
-- Ordinary-teacher session: repeat using a teacher UUID with no editor row;
-- helper=false, unpublished counts=0, and attempts are assignment-scoped.
-- Inserts/updates and editor-only RPCs must be denied.
--
-- Curriculum Editor session: repeat using an assigned teacher UUID; helper=true,
-- unpublished rows are visible, get_quiz_editor_question_details returns answer
-- keys, and direct SELECT is_correct remains denied. In a rollback-only test,
-- create an unpublished quiz with complete questions/options, reorder all
-- question UUIDs, publish it, then roll back.

