-- Chapter-based Story Vault and per-student reading progress.
-- Requires ilocano_teatro_master_supabase_setup.sql and
-- 20261031000000_curriculum_editor_management.sql to be applied first.
-- Additive only: does not recreate cultural_stories or alter lesson_progress.
-- Review and apply manually; do not run from the Flutter client.

begin;

create table public.story_chapters (
  chapter_id uuid primary key default gen_random_uuid(),
  story_id uuid not null
    references public.cultural_stories(story_id) on delete restrict,
  title text not null,
  content text not null default '',
  chapter_order integer not null check (chapter_order > 0),
  source_title text,
  source_url text,
  is_published boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (story_id, chapter_order)
);

-- A progress row means the student explicitly marked this chapter as read.
-- The chapter UUID, rather than its order, anchors progress through reordering.
-- RESTRICT prevents chapter deletion from erasing historical progress.
create table public.story_reading_progress (
  student_id uuid not null default auth.uid()
    references public.profiles(id) on delete cascade,
  chapter_id uuid not null
    references public.story_chapters(chapter_id) on delete restrict,
  completed_at timestamptz not null default now(),
  primary key (student_id, chapter_id)
);

create index story_chapters_published_order_idx
  on public.story_chapters (story_id, is_published, chapter_order);
create index story_reading_progress_chapter_idx
  on public.story_reading_progress (chapter_id, student_id);

alter table public.story_chapters enable row level security;
alter table public.story_reading_progress enable row level security;

-- Students can read published stories through the existing stories_read policy.
-- Editors can additionally read unpublished story metadata.
drop policy if exists stories_curriculum_editor_read
  on public.cultural_stories;
create policy stories_curriculum_editor_read
  on public.cultural_stories for select to authenticated
  using ((select public.is_curriculum_editor()));

-- Preserve the base authenticated read grant, but clear any broad/default write
-- grants before adding the editor-only column privileges below.
revoke all on public.cultural_stories
  from public, anon, authenticated;
grant select on public.cultural_stories to authenticated;
grant insert (
  title, summary, content, region, genre, story_type, cultural_background,
  source_title, source_url, is_published
) on public.cultural_stories to authenticated;
grant update (
  title, summary, content, region, genre, story_type, cultural_background,
  source_title, source_url, is_published
) on public.cultural_stories to authenticated;

drop policy if exists stories_curriculum_editor_insert
  on public.cultural_stories;
create policy stories_curriculum_editor_insert
  on public.cultural_stories for insert to authenticated
  with check ((select public.is_curriculum_editor()));

drop policy if exists stories_curriculum_editor_update
  on public.cultural_stories;
create policy stories_curriculum_editor_update
  on public.cultural_stories for update to authenticated
  using ((select public.is_curriculum_editor()))
  with check ((select public.is_curriculum_editor()));

-- Supabase projects can have default grants on newly created public tables.
-- Clear them so delete/truncate and non-editor writes are not inherited.
revoke all on public.story_chapters
  from public, anon, authenticated;
grant select on public.story_chapters to authenticated;
grant insert (
  story_id, title, content, chapter_order, source_title, source_url,
  is_published
) on public.story_chapters to authenticated;
grant update (
  title, content, chapter_order, source_title, source_url, is_published
) on public.story_chapters to authenticated;

drop policy if exists story_chapters_published_read on public.story_chapters;
create policy story_chapters_published_read
  on public.story_chapters for select to authenticated
  using (
    is_published
    and exists (
      select 1 from public.cultural_stories as s
      where s.story_id = story_chapters.story_id and s.is_published
    )
  );

drop policy if exists story_chapters_editor_read on public.story_chapters;
create policy story_chapters_editor_read
  on public.story_chapters for select to authenticated
  using ((select public.is_curriculum_editor()));

drop policy if exists story_chapters_editor_insert on public.story_chapters;
create policy story_chapters_editor_insert
  on public.story_chapters for insert to authenticated
  with check ((select public.is_curriculum_editor()));

drop policy if exists story_chapters_editor_update on public.story_chapters;
create policy story_chapters_editor_update
  on public.story_chapters for update to authenticated
  using ((select public.is_curriculum_editor()))
  with check ((select public.is_curriculum_editor()));

-- Defense in depth for story/chapter publication and all editor writes.
-- SQL Editor/service-role operations may have no auth.uid(); authenticated
-- non-editors must never gain editor access via an accidental grant or policy.
create or replace function public.guard_story_publication()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if (select auth.uid()) is not null
     and not (select public.is_curriculum_editor()) then
    raise exception 'Curriculum editor permission required'
      using errcode = '42501';
  end if;

  if new.is_published then
    if tg_op = 'INSERT' and not exists (
      select 1 from public.story_chapters as c
      where c.story_id = new.story_id and c.is_published
    ) then
      raise exception 'Publish at least one chapter before publishing a story'
        using errcode = '23514';
    elsif tg_op = 'UPDATE' and not old.is_published and not exists (
      select 1 from public.story_chapters as c
      where c.story_id = new.story_id and c.is_published
    ) then
      raise exception 'Publish at least one chapter before publishing a story'
        using errcode = '23514';
    end if;
  end if;
  return new;
end;
$$;

create trigger cultural_stories_publication_guard
  before insert or update of is_published on public.cultural_stories
  for each row execute function public.guard_story_publication();

create or replace function public.guard_story_chapter_write()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  parent_is_published boolean;
begin
  if (select auth.uid()) is not null
     and not (select public.is_curriculum_editor()) then
    raise exception 'Curriculum editor permission required'
      using errcode = '42501';
  end if;

  if tg_op = 'UPDATE' and new.story_id is distinct from old.story_id then
    raise exception 'A chapter cannot be moved to another story'
      using errcode = '42501';
  end if;

  select s.is_published into parent_is_published
  from public.cultural_stories as s where s.story_id = new.story_id;
  if parent_is_published is null then
    raise exception 'Story not found' using errcode = '23503';
  end if;

  if tg_op = 'UPDATE' and old.is_published and not new.is_published
     and parent_is_published
     and not exists (
       select 1 from public.story_chapters as c
       where c.story_id = old.story_id
         and c.is_published and c.chapter_id <> old.chapter_id
     ) then
    raise exception 'Unpublish the story before unpublishing its last chapter'
      using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger story_chapters_write_guard
  before insert or update on public.story_chapters
  for each row execute function public.guard_story_chapter_write();

create trigger story_chapters_updated
  before update on public.story_chapters
  for each row execute function public.set_updated_at();

-- Progress is private to the authenticated student. A student may only mark a
-- currently published chapter in a currently published story as read.
revoke all on public.story_reading_progress
  from public, anon, authenticated;
grant select on public.story_reading_progress to authenticated;
grant insert (chapter_id) on public.story_reading_progress to authenticated;

drop policy if exists story_reading_progress_read_own
  on public.story_reading_progress;
create policy story_reading_progress_read_own
  on public.story_reading_progress for select to authenticated
  using (student_id = (select auth.uid()));

drop policy if exists story_reading_progress_insert_own
  on public.story_reading_progress;
create policy story_reading_progress_insert_own
  on public.story_reading_progress for insert to authenticated
  with check (
    student_id = (select auth.uid())
    and exists (
      select 1
      from public.story_chapters as c
      join public.cultural_stories as s on s.story_id = c.story_id
      where c.chapter_id = story_reading_progress.chapter_id
        and c.is_published and s.is_published
    )
  );

-- Reorder the complete story chapter list atomically. Progress follows the
-- stable chapter_id, and editor-only authorization avoids exposing order writes.
create or replace function public.reorder_story_chapters(
  p_story_id uuid,
  p_chapter_ids uuid[]
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  chapter_count integer;
  distinct_id_count integer;
  max_order integer;
  temp_base bigint;
begin
  if not (select public.is_curriculum_editor()) then
    raise exception 'Curriculum editor permission required'
      using errcode = '42501';
  end if;
  if p_story_id is null or p_chapter_ids is null then
    raise exception 'A story and complete chapter order are required'
      using errcode = '22004';
  end if;

  lock table public.story_chapters in share row exclusive mode;
  if not exists (
    select 1 from public.cultural_stories as s where s.story_id = p_story_id
  ) then
    raise exception 'Story not found' using errcode = 'P0002';
  end if;

  select pg_catalog.count(*)::integer, coalesce(pg_catalog.max(c.chapter_order), 0)
    into chapter_count, max_order
  from public.story_chapters as c where c.story_id = p_story_id;

  if pg_catalog.cardinality(p_chapter_ids) <> chapter_count then
    raise exception 'Provide every chapter in the story exactly once'
      using errcode = '22023';
  end if;
  select pg_catalog.count(distinct requested.chapter_id)::integer
    into distinct_id_count
  from pg_catalog.unnest(p_chapter_ids) as requested(chapter_id);
  if distinct_id_count <> chapter_count then
    raise exception 'Chapter identifiers must be unique and non-null'
      using errcode = '22023';
  end if;
  if exists (
    select 1
    from pg_catalog.unnest(p_chapter_ids) as requested(chapter_id)
    left join public.story_chapters as c
      on c.chapter_id = requested.chapter_id and c.story_id = p_story_id
    where c.chapter_id is null
  ) then
    raise exception 'Every chapter must belong to the requested story'
      using errcode = '22023';
  end if;
  if chapter_count = 0 then return; end if;

  temp_base := max_order::bigint + chapter_count::bigint + 1;
  if temp_base + chapter_count > 2147483647 then
    raise exception 'Chapter ordering range is exhausted; no order was changed'
      using errcode = '22003';
  end if;

  update public.story_chapters as c
  set chapter_order = (temp_base + requested.ordinality - 1)::integer
  from pg_catalog.unnest(p_chapter_ids) with ordinality
    as requested(chapter_id, ordinality)
  where c.chapter_id = requested.chapter_id and c.story_id = p_story_id;

  update public.story_chapters as c
  set chapter_order = requested.ordinality::integer
  from pg_catalog.unnest(p_chapter_ids) with ordinality
    as requested(chapter_id, ordinality)
  where c.chapter_id = requested.chapter_id and c.story_id = p_story_id;
end;
$$;

alter function public.reorder_story_chapters(uuid, uuid[]) owner to postgres;
revoke all on function public.reorder_story_chapters(uuid, uuid[])
  from public, anon;
grant execute on function public.reorder_story_chapters(uuid, uuid[])
  to authenticated, service_role;

revoke all on function public.guard_story_publication() from public, anon;
revoke all on function public.guard_story_chapter_write() from public, anon;
grant execute on function public.guard_story_publication() to authenticated, service_role;
grant execute on function public.guard_story_chapter_write() to authenticated, service_role;

commit;

-- Existing cultural_stories.content values are intentionally not transformed
-- into chapters here: the schema has no chapter boundaries or verified chapter
-- titles. Editors should create source-accurate chapters before republishing a
-- legacy story that has no published chapters.
