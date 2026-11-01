-- Optional private Storage support for Story Vault images.
-- Requires 20261101000001_story_chapters_and_reading_progress.sql.
-- Review/apply separately and manually; no objects are uploaded by this SQL.
-- Existing bucket configuration is inspected and never overwritten.

begin;

alter table public.cultural_stories
  add column cover_storage_path text,
  add column cover_alt_text text,
  add column cover_caption text,
  add column cover_source_title text,
  add column cover_source_url text;

alter table public.story_chapters
  add column illustration_storage_path text,
  add column illustration_alt_text text,
  add column illustration_caption text,
  add column illustration_source_title text,
  add column illustration_source_url text;

grant update (
  cover_storage_path, cover_alt_text, cover_caption,
  cover_source_title, cover_source_url
) on public.cultural_stories to authenticated;
grant insert (
  story_id, title, content, chapter_order, source_title, source_url,
  is_published, illustration_storage_path, illustration_alt_text,
  illustration_caption, illustration_source_title, illustration_source_url
) on public.story_chapters to authenticated;
grant update (
  title, content, chapter_order, source_title, source_url, is_published,
  illustration_storage_path, illustration_alt_text, illustration_caption,
  illustration_source_title, illustration_source_url
) on public.story_chapters to authenticated;

-- Supabase Storage supports per-bucket MIME and maximum file-size limits.
-- Create only when absent. If this id already exists with different settings,
-- abort with its current settings so an administrator can review it explicitly.
insert into storage.buckets (
  id, name, public, file_size_limit, allowed_mime_types
)
values (
  'ilocano-story-media', 'ilocano-story-media', false, 5242880,
  array['image/jpeg', 'image/png', 'image/webp']::text[]
)
on conflict (id) do nothing;

do $$
declare
  existing_name text;
  existing_public boolean;
  existing_file_size_limit bigint;
  existing_allowed_mime_types text[];
begin
  select b.name, b.public, b.file_size_limit, b.allowed_mime_types
    into existing_name, existing_public,
         existing_file_size_limit, existing_allowed_mime_types
  from storage.buckets as b
  where b.id = 'ilocano-story-media'
  for update;

  if not found then
    raise exception 'Could not create or find Storage bucket ilocano-story-media';
  end if;

  if existing_name is distinct from 'ilocano-story-media'
     or existing_public is distinct from false
     or existing_file_size_limit is distinct from 5242880
     or existing_allowed_mime_types is distinct from
       array['image/jpeg', 'image/png', 'image/webp']::text[] then
    raise exception
      'Existing ilocano-story-media bucket configuration differs: name=%, public=%, file_size_limit=%, allowed_mime_types=%. Expected name=ilocano-story-media, public=false, file_size_limit=5242880, allowed_mime_types={image/jpeg,image/png,image/webp}. Review and reconcile the existing bucket manually before retrying.',
      existing_name, existing_public, existing_file_size_limit,
      existing_allowed_mime_types;
  end if;
end;
$$;

-- Storage policies are permissive by default and combine with OR. Abort if an
-- existing client-facing SELECT/INSERT/UPDATE/DELETE/ALL policy could broaden
-- access to this bucket. Review existing policies manually instead of
-- silently relying on this migration's policies to override them (they cannot).
do $$
declare
  conflicting_policy record;
begin
  select p.policyname, p.roles, p.cmd, p.qual
    into conflicting_policy
  from pg_catalog.pg_policies as p
  where p.schemaname = 'storage'
    and p.tablename = 'objects'
    and p.policyname <> 'ilocano_story_media_published_read'
    and p.cmd in ('SELECT', 'INSERT', 'UPDATE', 'DELETE', 'ALL')
    and (
      'public' = any(p.roles)
      or 'anon' = any(p.roles)
      or 'authenticated' = any(p.roles)
    )
  limit 1;

  if found then
    raise exception
      'Existing storage.objects policy % (roles %, command %) may combine with Story Vault media policies. Inspect pg_policies and narrow or remove conflicting access manually before retrying. USING predicate: %; WITH CHECK predicate: %',
      conflicting_policy.policyname, conflicting_policy.roles,
      conflicting_policy.cmd, conflicting_policy.qual,
      conflicting_policy.with_check;
  end if;
end;
$$;

-- Operation-aware filtering is important because Storage uses SELECT for both
-- object fetch/sign operations and bucket listings. Do not grant list/list_v2.
drop policy if exists ilocano_story_media_published_read on storage.objects;
create policy ilocano_story_media_published_read
  on storage.objects for select to authenticated
  using (
    bucket_id = 'ilocano-story-media'
    and storage.allow_any_operation(array[
      'storage.object.get_authenticated'
    ])
    and (
      (
        (storage.foldername(name))[2] = 'cover'
        and pg_catalog.cardinality(storage.foldername(name)) = 2
        and exists (
          select 1 from public.cultural_stories as s
          where s.story_id::text = (storage.foldername(name))[1]
            and (
              (select public.is_curriculum_editor())
              or (s.is_published and s.cover_storage_path = storage.objects.name)
            )
        )
      )
      or
      (
        (storage.foldername(name))[2] = 'chapters'
        and pg_catalog.cardinality(storage.foldername(name)) = 3
        and exists (
          select 1
          from public.story_chapters as c
          join public.cultural_stories as s on s.story_id = c.story_id
          where s.story_id::text = (storage.foldername(name))[1]
            and c.chapter_id::text = (storage.foldername(name))[3]
            and (
              (select public.is_curriculum_editor())
              or (
                s.is_published and c.is_published
                and c.illustration_storage_path = storage.objects.name
              )
            )
        )
      )
    )
  );

drop policy if exists ilocano_story_media_editor_insert on storage.objects;
create policy ilocano_story_media_editor_insert
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'ilocano-story-media'
    and (select public.is_curriculum_editor())
    and (
      ((storage.foldername(name))[2] = 'cover'
       and pg_catalog.cardinality(storage.foldername(name)) = 2
       and exists (
         select 1 from public.cultural_stories as s
         where s.story_id::text = (storage.foldername(name))[1]
       ))
      or
      ((storage.foldername(name))[2] = 'chapters'
       and pg_catalog.cardinality(storage.foldername(name)) = 3
       and exists (
         select 1 from public.story_chapters as c
         where c.story_id::text = (storage.foldername(name))[1]
           and c.chapter_id::text = (storage.foldername(name))[3]
       ))
    )
  );

drop policy if exists ilocano_story_media_editor_update on storage.objects;
create policy ilocano_story_media_editor_update
  on storage.objects for update to authenticated
  using (
    bucket_id = 'ilocano-story-media'
    and (select public.is_curriculum_editor())
    and (
      ((storage.foldername(name))[2] = 'cover'
       and pg_catalog.cardinality(storage.foldername(name)) = 2
       and exists (
         select 1 from public.cultural_stories as s
         where s.story_id::text = (storage.foldername(name))[1]
       ))
      or
      ((storage.foldername(name))[2] = 'chapters'
       and pg_catalog.cardinality(storage.foldername(name)) = 3
       and exists (
         select 1 from public.story_chapters as c
         where c.story_id::text = (storage.foldername(name))[1]
           and c.chapter_id::text = (storage.foldername(name))[3]
       ))
    )
  )
  with check (
    bucket_id = 'ilocano-story-media'
    and (select public.is_curriculum_editor())
    and (
      ((storage.foldername(name))[2] = 'cover'
       and pg_catalog.cardinality(storage.foldername(name)) = 2
       and exists (
         select 1 from public.cultural_stories as s
         where s.story_id::text = (storage.foldername(name))[1]
       ))
      or
      ((storage.foldername(name))[2] = 'chapters'
       and pg_catalog.cardinality(storage.foldername(name)) = 3
       and exists (
         select 1 from public.story_chapters as c
         where c.story_id::text = (storage.foldername(name))[1]
           and c.chapter_id::text = (storage.foldername(name))[3]
       ))
    )
  );

drop policy if exists ilocano_story_media_editor_delete on storage.objects;
create policy ilocano_story_media_editor_delete
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'ilocano-story-media'
    and (select public.is_curriculum_editor())
    and (
      ((storage.foldername(name))[2] = 'cover'
       and pg_catalog.cardinality(storage.foldername(name)) = 2
       and exists (
         select 1 from public.cultural_stories as s
         where s.story_id::text = (storage.foldername(name))[1]
       ))
      or
      ((storage.foldername(name))[2] = 'chapters'
       and pg_catalog.cardinality(storage.foldername(name)) = 3
       and exists (
         select 1 from public.story_chapters as c
         where c.story_id::text = (storage.foldername(name))[1]
           and c.chapter_id::text = (storage.foldername(name))[3]
       ))
    )
  );

commit;

-- Object key layout:
--   <story_uuid>/cover/<file>
--   <story_uuid>/chapters/<chapter_uuid>/<file>
-- The bucket is private. Read images with authenticated Storage requests.
-- Do not mint signed URLs for unpublished media; signed URLs are bearer links.
