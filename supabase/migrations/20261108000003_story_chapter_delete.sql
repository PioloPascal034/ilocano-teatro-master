-- Curriculum-editor-only Story Vault chapter deletion.
-- Review and apply manually after 20261108000000_story_delete.sql.
-- This migration is not applied by the Flutter client.

begin;

create or replace function public.delete_story_chapter(p_chapter_id uuid)
returns table(storage_path text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  chapter_story_id uuid;
  chapter_published boolean;
  chapter_illustration text;
  max_order integer;
  chapter_count integer;
  temp_base bigint;
begin
  if not (select public.is_curriculum_editor()) then
    raise exception 'Curriculum editor permission required'
      using errcode = '42501';
  end if;

  select c.story_id
    into chapter_story_id
  from public.story_chapters as c
  where c.chapter_id = p_chapter_id;

  if not found then
    raise exception 'Chapter not found' using errcode = 'P0002';
  end if;

  -- Lock parent first, matching whole-story deletion's lock order. This keeps
  -- story deletion, chapter deletion, and chapter reordering serialized.
  perform 1
  from public.cultural_stories as s
  where s.story_id = chapter_story_id
  for update;

  select c.is_published, c.illustration_storage_path
    into chapter_published, chapter_illustration
  from public.story_chapters as c
  where c.chapter_id = p_chapter_id
    and c.story_id = chapter_story_id
  for update;

  if not found then
    raise exception 'Chapter not found' using errcode = 'P0002';
  end if;

  perform 1
  from public.story_chapters as c
  where c.story_id = chapter_story_id
  for update;

  if chapter_published then
    raise exception 'Unpublish the chapter before deleting it'
      using errcode = '55000';
  end if;

  if exists (
    select 1
    from public.story_reading_progress as rp
    where rp.chapter_id = p_chapter_id
  ) then
    raise exception 'Chapter has student reading progress and cannot be deleted'
      using errcode = '55000';
  end if;

  if chapter_illustration is not null and exists (
    select 1
    from public.story_deletion_media as dm
    where dm.storage_path = chapter_illustration
      and dm.story_id <> chapter_story_id
  ) then
    raise exception 'Chapter illustration is already pending cleanup for another story'
      using errcode = '23505';
  end if;

  if chapter_illustration is not null then
    insert into public.story_deletion_media (
      story_id, storage_path, deleted_by
    ) values (
      chapter_story_id, chapter_illustration, (select auth.uid())
    ) on conflict on constraint story_deletion_media_pkey do nothing;
  end if;

  delete from public.story_chapters
  where chapter_id = p_chapter_id;

  -- Preserve the relative order of remaining chapters while avoiding the
  -- unique(story_id, chapter_order) constraint during renumbering.
  select pg_catalog.count(*)::integer, coalesce(pg_catalog.max(c.chapter_order), 0)
    into chapter_count, max_order
  from public.story_chapters as c
  where c.story_id = chapter_story_id;

  if chapter_count > 0 then
    temp_base := max_order::bigint + chapter_count::bigint + 1;
    if temp_base + max_order > 2147483647 then
      raise exception 'Chapter ordering range is exhausted; no order was changed'
        using errcode = '22003';
    end if;

    update public.story_chapters as c
    set chapter_order = (temp_base + c.chapter_order)::integer
    where c.story_id = chapter_story_id;

    with ordered as (
      select c.chapter_id,
             row_number() over (order by c.chapter_order)::integer as new_order
      from public.story_chapters as c
      where c.story_id = chapter_story_id
    )
    update public.story_chapters as c
    set chapter_order = ordered.new_order
    from ordered
    where c.chapter_id = ordered.chapter_id;
  end if;

  if chapter_illustration is not null then
    return query select chapter_illustration;
  end if;
end;
$$;

alter function public.delete_story_chapter(uuid) owner to postgres;
revoke all on function public.delete_story_chapter(uuid)
  from public, anon, service_role;
grant execute on function public.delete_story_chapter(uuid)
  to authenticated;

create or replace function public.complete_story_media_cleanup(p_storage_path text)
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
    where dm.storage_path = p_storage_path
      and dm.deleted_by = (select auth.uid())
  ) and exists (
    select 1
    from storage.objects as object
    where object.bucket_id = 'ilocano-story-media'
      and object.name = p_storage_path
  ) then
    raise exception 'Story media cleanup is incomplete'
      using errcode = '55000';
  end if;

  delete from public.story_deletion_media
  where storage_path = p_storage_path
    and deleted_by = (select auth.uid());
end;
$$;

alter function public.complete_story_media_cleanup(text) owner to postgres;
revoke all on function public.complete_story_media_cleanup(text)
  from public, anon, service_role;
grant execute on function public.complete_story_media_cleanup(text)
  to authenticated;

commit;
