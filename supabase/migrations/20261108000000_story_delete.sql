-- Curriculum-editor-only Story Vault deletion.
-- Review and apply manually after the Story Vault tables and storage policies.
-- This migration is not applied by the Flutter client.

begin;

-- A tombstone keeps the exact media paths authorized for cleanup after the
-- relational rows are removed. It prevents a broad editor delete policy.
create table if not exists public.story_deletion_media (
  story_id uuid not null,
  storage_path text primary key,
  deleted_at timestamptz not null default now(),
  deleted_by uuid not null default auth.uid()
);

alter table public.story_deletion_media enable row level security;
revoke all on table public.story_deletion_media
  from public, anon, authenticated;

create or replace function public.can_delete_story_media(p_storage_path text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (select public.is_curriculum_editor())
    and exists (
      select 1
      from public.story_deletion_media as dm
      where dm.storage_path = p_storage_path
        and dm.deleted_by = (select auth.uid())
    )
    and not exists (
      select 1
      from public.cultural_stories as s
      where s.cover_storage_path = p_storage_path
    )
    and not exists (
      select 1
      from public.story_chapters as c
      where c.illustration_storage_path = p_storage_path
    );
$$;

alter function public.can_delete_story_media(text) owner to postgres;
revoke all on function public.can_delete_story_media(text) from public, anon;
grant execute on function public.can_delete_story_media(text)
  to authenticated, service_role;

create or replace function public.delete_story(p_story_id uuid)
returns table(storage_path text)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not (select public.is_curriculum_editor()) then
    raise exception 'Curriculum editor permission required'
      using errcode = '42501';
  end if;

  if p_story_id is null or not exists (
    select 1 from public.cultural_stories as s
    where s.story_id = p_story_id
  ) then
    raise exception 'Story not found' using errcode = 'P0002';
  end if;

  if exists (
    select 1
    from public.story_deletion_media as dm
    where dm.storage_path in (
      select s.cover_storage_path
      from public.cultural_stories as s
      where s.story_id = p_story_id
      union
      select c.illustration_storage_path
      from public.story_chapters as c
      where c.story_id = p_story_id
    )
    and dm.story_id <> p_story_id
  ) then
    raise exception 'A media path is already pending cleanup for another story'
      using errcode = '23505';
  end if;

  insert into public.story_deletion_media (story_id, storage_path, deleted_by)
  select p_story_id, paths.storage_path, (select auth.uid())
  from (
    select s.cover_storage_path as storage_path
    from public.cultural_stories as s
    where s.story_id = p_story_id
    union
    select c.illustration_storage_path
    from public.story_chapters as c
    where c.story_id = p_story_id
  ) as paths
  where paths.storage_path is not null
  -- Never reassign an existing tombstone to another story. A shared path is
  -- left protected for its original cleanup owner and is not deleted here.
  on conflict on constraint story_deletion_media_pkey do nothing;

  -- RESTRICT foreign keys require explicit, ordered deletion. Reading progress
  -- is intentionally and irreversibly removed only for this story's chapters;
  -- the client confirmation warns the editor before invoking this function.
  delete from public.story_reading_progress as rp
  using public.story_chapters as c
  where c.story_id = p_story_id
    and rp.chapter_id = c.chapter_id;

  delete from public.story_chapters
  where story_id = p_story_id;

  delete from public.cultural_stories
  where story_id = p_story_id;

  return query
    select dm.storage_path
    from public.story_deletion_media as dm
    where dm.story_id = p_story_id
    order by dm.storage_path;
end;
$$;

alter function public.delete_story(uuid) owner to postgres;
revoke all on function public.delete_story(uuid) from public, anon;
grant execute on function public.delete_story(uuid) to authenticated, service_role;

create or replace function public.complete_story_deletion(p_story_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not (select public.is_curriculum_editor()) then
    raise exception 'Curriculum editor permission required'
      using errcode = '42501';
  end if;

  if exists (
    select 1
    from public.story_deletion_media as dm
    join storage.objects as object
      on object.bucket_id = 'ilocano-story-media'
     and object.name = dm.storage_path
    where dm.story_id = p_story_id
      and dm.deleted_by = (select auth.uid())
  ) then
    raise exception 'Story media cleanup is incomplete'
      using errcode = '55000';
  end if;

  delete from public.story_deletion_media
  where story_id = p_story_id
    and deleted_by = (select auth.uid());
end;
$$;

alter function public.complete_story_deletion(uuid) owner to postgres;
revoke all on function public.complete_story_deletion(uuid) from public, anon;
grant execute on function public.complete_story_deletion(uuid)
  to authenticated, service_role;

-- Preserve the existing exact story/chapter path checks and add only the
-- tombstoned paths created by delete_story. No bucket-wide delete access is
-- granted to curriculum editors.
drop policy if exists ilocano_story_media_editor_delete on storage.objects;
create policy ilocano_story_media_editor_delete
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'ilocano-story-media'
    and (select public.is_curriculum_editor())
    and (
      (
        (storage.foldername(name))[2] = 'cover'
        and pg_catalog.cardinality(storage.foldername(name)) = 2
        and exists (
          select 1 from public.cultural_stories as s
          where s.story_id::text = (storage.foldername(name))[1]
            and s.cover_storage_path = name
        )
      )
      or
      (
        (storage.foldername(name))[2] = 'chapters'
        and pg_catalog.cardinality(storage.foldername(name)) = 3
        and exists (
          select 1 from public.story_chapters as c
          where c.story_id::text = (storage.foldername(name))[1]
            and c.chapter_id::text = (storage.foldername(name))[3]
            and c.illustration_storage_path = name
        )
      )
      or public.can_delete_story_media(name)
    )
  );

commit;
