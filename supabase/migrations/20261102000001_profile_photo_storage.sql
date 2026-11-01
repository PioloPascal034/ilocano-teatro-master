-- Private profile avatars. Apply manually after reviewing the existing Storage
-- configuration; this migration never makes a bucket public or changes an
-- existing bucket's settings.
begin;

alter table public.profiles
  add column if not exists avatar_storage_path text;

grant update (avatar_storage_path) on public.profiles to authenticated;

insert into storage.buckets (
  id, name, public, file_size_limit, allowed_mime_types
)
values (
  'ilocano-profile-avatars', 'ilocano-profile-avatars', false, 5242880,
  array['image/jpeg', 'image/png', 'image/webp']::text[]
)
on conflict (id) do nothing;

do $$
declare
  bucket_name text;
  is_public boolean;
  size_limit bigint;
  mime_types text[];
begin
  select name, public, file_size_limit, allowed_mime_types
    into bucket_name, is_public, size_limit, mime_types
  from storage.buckets
  where id = 'ilocano-profile-avatars'
  for update;

  if not found then
    raise exception 'Could not create or find ilocano-profile-avatars bucket';
  end if;

  if bucket_name is distinct from 'ilocano-profile-avatars'
     or is_public is distinct from false
     or size_limit is distinct from 5242880
     or mime_types is distinct from
       array['image/jpeg', 'image/png', 'image/webp']::text[] then
    raise exception
      'Existing ilocano-profile-avatars bucket configuration differs: name=%, public=%, file_size_limit=%, allowed_mime_types=%. Review and reconcile it manually before retrying.',
      bucket_name, is_public, size_limit, mime_types;
  end if;
end;
$$;

-- Storage policies are permissive and combine with OR. Refuse to add these
-- protections when an existing broad policy could bypass the owner boundary.
do $$
declare
  conflicting_policy record;
begin
  select policyname, roles, cmd, qual, with_check
    into conflicting_policy
  from pg_catalog.pg_policies
  where schemaname = 'storage'
    and tablename = 'objects'
    and policyname not in (
      'ilocano_profile_avatars_read_authorized',
      'ilocano_profile_avatars_insert_own',
      'ilocano_profile_avatars_update_own',
      'ilocano_profile_avatars_delete_own',
      'profile_photos_read_own', 'profile_photos_insert_own',
      'profile_photos_update_own', 'profile_photos_delete_own'
    )
    and cmd in ('SELECT', 'INSERT', 'UPDATE', 'DELETE', 'ALL')
    and (
      'public' = any(roles)
      or 'anon' = any(roles)
      or 'authenticated' = any(roles)
    )
    and (
      coalesce(qual, '') not ilike '%bucket_id%'
      or coalesce(with_check, '') ilike '%ilocano-profile-avatars%'
    )
  limit 1;

  if found then
    raise exception
      'Existing storage.objects policy % (roles %, command %) may weaken profile-avatar ownership. Review it and retry manually. USING predicate: %; WITH CHECK predicate: %',
      conflicting_policy.policyname, conflicting_policy.roles,
      conflicting_policy.cmd, conflicting_policy.qual,
      conflicting_policy.with_check;
  end if;
end;
$$;

-- A user's object is a single file directly under their Auth UUID folder.
-- Owners and teachers authorized to review a student can read profile photos;
-- object listing remains excluded by the operation-aware SELECT predicate.
drop policy if exists ilocano_profile_avatars_read_authorized on storage.objects;
create policy ilocano_profile_avatars_read_authorized
  on storage.objects for select to authenticated
  using (
    bucket_id = 'ilocano-profile-avatars'
    and storage.allow_any_operation(array['storage.object.get_authenticated'])
    and pg_catalog.cardinality(storage.foldername(name)) = 1
    and lower(storage.extension(name)) in ('jpg', 'jpeg', 'png', 'webp')
    and exists (
      select 1
      from public.profiles as p
      where p.id::text = (storage.foldername(name))[1]
        and p.avatar_storage_path = storage.objects.name
        and (p.id = (select auth.uid()) or public.can_review(p.id))
    )
  );

drop policy if exists ilocano_profile_avatars_insert_own on storage.objects;
create policy ilocano_profile_avatars_insert_own
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'ilocano-profile-avatars'
    and pg_catalog.cardinality(storage.foldername(name)) = 1
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and lower(storage.extension(name)) in ('jpg', 'jpeg', 'png', 'webp')
  );

drop policy if exists ilocano_profile_avatars_update_own on storage.objects;
create policy ilocano_profile_avatars_update_own
  on storage.objects for update to authenticated
  using (
    bucket_id = 'ilocano-profile-avatars'
    and pg_catalog.cardinality(storage.foldername(name)) = 1
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and lower(storage.extension(name)) in ('jpg', 'jpeg', 'png', 'webp')
  )
  with check (
    bucket_id = 'ilocano-profile-avatars'
    and pg_catalog.cardinality(storage.foldername(name)) = 1
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and lower(storage.extension(name)) in ('jpg', 'jpeg', 'png', 'webp')
  );

drop policy if exists ilocano_profile_avatars_delete_own on storage.objects;
create policy ilocano_profile_avatars_delete_own
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'ilocano-profile-avatars'
    and pg_catalog.cardinality(storage.foldername(name)) = 1
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and lower(storage.extension(name)) in ('jpg', 'jpeg', 'png', 'webp')
  );

commit;
