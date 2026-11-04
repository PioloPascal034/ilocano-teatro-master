-- Class join codes for owner-provisioned teachers.
-- Review and apply manually in Supabase SQL Editor. Do not run from Flutter.
--
-- Existing teacher_students rows are preserved. The join RPC does not create a
-- second teacher relationship for a student who already has another teacher.
-- Redeeming the same teacher's code is idempotent.

begin;

-- Deployment preflight: fail before any DDL if the expected existing schema or
-- pgcrypto functions are unavailable.
do $$
begin
  if not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'teacher_students'
      and column_name = 'assigned_at'
  ) then
    raise exception 'teacher_students.assigned_at is required';
  end if;
  if not exists (
    select 1
    from pg_index i
    where i.indrelid = 'public.teacher_students'::regclass
      and i.indisunique
      and (
        select array_agg(a.attname::text order by keys.ordinality)
        from unnest(i.indkey) with ordinality keys(attnum, ordinality)
        join pg_attribute a
          on a.attrelid = i.indrelid and a.attnum = keys.attnum
      ) = array['teacher_id', 'student_id']
  ) then
    raise exception
      'teacher_students must have a unique (teacher_id, student_id) key';
  end if;
  if not exists (
    select 1
    from pg_constraint c
    where c.conrelid = 'public.teacher_students'::regclass
      and c.conname = 'teacher_students_pkey'
      and c.contype = 'p'
  ) then
    raise exception 'teacher_students_pkey is required for idempotent joins';
  end if;
  if not exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'extensions' and p.proname = 'digest'
  ) then
    raise exception 'extensions.digest is required';
  end if;
  if not exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'extensions' and p.proname = 'gen_random_bytes'
  ) then
    raise exception 'extensions.gen_random_bytes is required';
  end if;
end;
$$;

-- Preflight: do not auto-change existing assignments. If this raises, review
-- every duplicate student before rerunning the migration.
do $$
declare
  duplicate_students text;
begin
  select string_agg(student_id::text, ', ' order by student_id)
    into duplicate_students
  from (
    select student_id
    from public.teacher_students
    group by student_id
    having count(*) > 1
  ) duplicates;
  if duplicate_students is not null then
    raise exception 'Multiple teacher assignments require review: %',
      duplicate_students
      using errcode = '23505';
  end if;
end;
$$;
-- The existing composite primary key (teacher_id, student_id) satisfies
-- ON CONFLICT (teacher_id, student_id). This additional index enforces the
-- one-teacher-per-student rule needed to serialize concurrent joins.
create unique index if not exists teacher_students_one_teacher_per_student_idx
  on public.teacher_students (student_id);

create table if not exists public.teacher_class_codes (
  class_code_id uuid primary key default gen_random_uuid(),
  teacher_id uuid not null references public.profiles(id) on delete cascade,
  code_hash bytea not null,
  -- Needed to re-display/copy the active code. The table has no client table
  -- grants; redemption and matching use code_hash.
  code_value text not null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '30 days'),
  revoked_at timestamptz
);

create unique index if not exists teacher_class_codes_one_active_per_teacher
  on public.teacher_class_codes (teacher_id)
  where revoked_at is null;

create unique index if not exists teacher_class_codes_hash_unique
  on public.teacher_class_codes (code_hash);

alter table public.teacher_class_codes enable row level security;
revoke all on public.teacher_class_codes from public, anon, authenticated;

create or replace function public.create_class_join_code()
returns table (
  class_code_id uuid,
  code text,
  expires_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller uuid := (select auth.uid());
  generated_code text;
  created_row public.teacher_class_codes%rowtype;
begin
  if caller is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  if not public.is_teacher() then
    raise exception 'Only teachers may create class codes'
      using errcode = '42501';
  end if;

  update public.teacher_class_codes
  set revoked_at = now()
  where teacher_id = caller and revoked_at is null;

  generated_code := 'IT-' || upper(encode(extensions.gen_random_bytes(16), 'hex'));
  insert into public.teacher_class_codes (
    teacher_id, code_hash, code_value
  )
  values (
    caller,
    extensions.digest(generated_code, 'sha256'),
    generated_code
  )
  returning * into created_row;

  return query
  select created_row.class_code_id, created_row.code_value,
         created_row.expires_at;
end;
$$;

create or replace function public.get_active_class_join_code()
returns table (
  class_code_id uuid,
  code text,
  expires_at timestamptz
)
language sql
security definer
set search_path = ''
as $$
  select c.class_code_id, c.code_value, c.expires_at
  from public.teacher_class_codes c
  where c.teacher_id = (select auth.uid())
    and c.revoked_at is null
    and c.expires_at > now()
    and public.is_teacher();
$$;

create or replace function public.revoke_class_join_code()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_teacher() then
    raise exception 'Only teachers may revoke class codes'
      using errcode = '42501';
  end if;
  update public.teacher_class_codes
  set revoked_at = now()
  where teacher_id = (select auth.uid())
    and revoked_at is null;
end;
$$;

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
  normalized_code text := upper(regexp_replace(coalesce(input_code, ''), '\s+', '', 'g'));
  matched public.teacher_class_codes%rowtype;
  teacher_profile public.profiles%rowtype;
begin
  if caller is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.profiles
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

create or replace function public.get_my_teacher_connection()
returns table (
  teacher_id uuid,
  teacher_name text
)
language sql
security definer
set search_path = ''
as $$
  select p.id, p.full_name
  from public.teacher_students ts
  join public.profiles p on p.id = ts.teacher_id
  where ts.student_id = (select auth.uid())
    and p.role = 'teacher'
  order by ts.assigned_at
  limit 1;
$$;

alter function public.create_class_join_code() owner to postgres;
alter function public.get_active_class_join_code() owner to postgres;
alter function public.revoke_class_join_code() owner to postgres;
alter function public.join_class_code(text) owner to postgres;
alter function public.get_my_teacher_connection() owner to postgres;

revoke all on function public.create_class_join_code() from public, anon;
revoke all on function public.get_active_class_join_code() from public, anon;
revoke all on function public.revoke_class_join_code() from public, anon;
revoke all on function public.join_class_code(text) from public, anon;
revoke all on function public.get_my_teacher_connection() from public, anon;
grant execute on function public.create_class_join_code() to authenticated, service_role;
grant execute on function public.get_active_class_join_code() to authenticated, service_role;
grant execute on function public.revoke_class_join_code() to authenticated, service_role;
grant execute on function public.join_class_code(text) to authenticated, service_role;
grant execute on function public.get_my_teacher_connection() to authenticated, service_role;

commit;
