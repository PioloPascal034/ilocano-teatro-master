-- Require a complete theme before creating an immutable submission version.
-- This is additive: it replaces only the existing submit_theme(uuid) body.
-- Apply manually after review; do not run from the Flutter client.

begin;

create or replace function public.submit_theme(p_draft_id uuid) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  d public.theme_drafts%rowtype;
  result_id uuid;
  next_version integer;
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;

  if not exists (
    select 1
    from public.profiles as profile
    where profile.id = (select auth.uid())
      and profile.role = 'student'
  ) then
    raise exception 'Only student accounts may submit themes'
      using errcode = '42501';
  end if;

  select * into d
  from public.theme_drafts
  where draft_id = p_draft_id
  for update;

  if not found or d.student_id <> (select auth.uid()) then
    raise exception 'Draft not found' using errcode = 'P0002';
  end if;

  if d.status not in ('draft', 'revision_requested') then
    raise exception 'Draft is not ready for submission' using errcode = '55000';
  end if;

  if nullif(trim(coalesce(d.title, '')), '') is null then
    raise exception 'Theme title is required before submission' using errcode = '22023';
  end if;
  if nullif(trim(coalesce(d.central_message, '')), '') is null then
    raise exception 'Central message is required before submission' using errcode = '22023';
  end if;
  if nullif(trim(coalesce(d.dramatic_conflict, '')), '') is null then
    raise exception 'Dramatic conflict is required before submission' using errcode = '22023';
  end if;
  if nullif(trim(coalesce(d.characters, '')), '') is null then
    raise exception 'Characters are required before submission' using errcode = '22023';
  end if;
  if nullif(trim(coalesce(d.target_audience, '')), '') is null then
    raise exception 'Target audience is required before submission' using errcode = '22023';
  end if;
  if nullif(trim(coalesce(d.stage_concept, '')), '') is null then
    raise exception 'Stage presentation is required before submission' using errcode = '22023';
  end if;

  select coalesce(max(version_number), 0) + 1 into next_version
  from public.submissions
  where draft_id = p_draft_id;

  insert into public.submissions(draft_id, version_number, submitted_content)
  values (
    p_draft_id,
    next_version,
    jsonb_build_object(
      'title', d.title,
      'story_id', d.story_id,
      'central_message', d.central_message,
      'dramatic_conflict', d.dramatic_conflict,
      'characters', d.characters,
      'target_audience', d.target_audience,
      'stage_concept', d.stage_concept,
      'source_acknowledgment', d.source_acknowledgment
    )
  )
  returning submission_id into result_id;

  update public.theme_drafts
  set status = 'submitted'
  where draft_id = p_draft_id;

  insert into public.notifications(
    user_id, title, message, notification_type, related_submission_id
  )
  select
    assignment.teacher_id,
    'New theme submission',
    d.title || ' is ready for review',
    'new_submission',
    result_id
  from public.teacher_students as assignment
  where assignment.student_id = d.student_id;

  return result_id;
end;
$$;

alter function public.submit_theme(uuid) owner to postgres;
revoke all on function public.submit_theme(uuid) from public, anon;
grant execute on function public.submit_theme(uuid) to authenticated;

commit;
