-- Corrective migration for the already-applied class-code migration.
-- The first deployed function used ON CONFLICT (teacher_id, student_id) inside
-- a RETURNS TABLE function whose output column was also named teacher_id.
-- PostgreSQL resolves that target as ambiguous (42702). Apply manually.
--
-- No assignments are changed by this migration.

begin;

create or replace function public.join_class_code(input_code text)
returns table (
  teacher_id uuid,
  teacher_name text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller uuid := (select auth.uid());
  normalized_code text := upper(
    regexp_replace(coalesce(input_code, ''), '\s+', '', 'g')
  );
  matched public.teacher_class_codes%rowtype;
  teacher_profile public.profiles%rowtype;
begin
  if caller is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  if not exists (
    select 1
    from public.profiles
    where id = caller and role = 'student'
  ) then
    raise exception 'Only student accounts may join a class'
      using errcode = '42501';
  end if;
  if normalized_code = '' then
    raise exception 'Enter a class code' using errcode = '22023';
  end if;

  select * into matched
  from public.teacher_class_codes
  where code_hash = extensions.digest(normalized_code, 'sha256')
    and revoked_at is null
    and expires_at > now()
  for update;

  if not found then
    raise exception 'That class code is invalid, expired, or revoked'
      using errcode = 'P0002';
  end if;

  if exists (
    select 1
    from public.teacher_students ts
    where ts.student_id = caller
      and ts.teacher_id <> matched.teacher_id
  ) then
    raise exception 'Your account is already connected to another teacher'
      using errcode = '23505';
  end if;

  begin
    insert into public.teacher_students (teacher_id, student_id)
    values (matched.teacher_id, caller)
    on conflict on constraint teacher_students_pkey do nothing;
  exception
    when unique_violation then
      raise exception 'Your account is already connected to another teacher'
        using errcode = '23505';
  end;

  select * into teacher_profile
  from public.profiles
  where id = matched.teacher_id and role = 'teacher';
  if not found then
    raise exception 'The teacher account is no longer available'
      using errcode = 'P0002';
  end if;

  return query select teacher_profile.id, teacher_profile.full_name;
end;
$$;

alter function public.join_class_code(text) owner to postgres;
revoke all on function public.join_class_code(text) from public, anon;
grant execute on function public.join_class_code(text) to authenticated, service_role;

commit;
