-- Permit the Storage remove API to resolve only the caller's own avatar object
-- metadata during delete_many. This does not permit object downloads/listing.
-- Apply manually after review; do not run from the Flutter client.

begin;

drop policy if exists ilocano_profile_avatars_delete_metadata_select_own
  on storage.objects;
create policy ilocano_profile_avatars_delete_metadata_select_own
  on storage.objects for select to authenticated
  using (
    bucket_id = 'ilocano-profile-avatars'
    and storage.allow_any_operation(array[
      'storage.object.delete_many'
    ])
    and pg_catalog.cardinality(storage.foldername(name)) = 1
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and lower(storage.extension(name)) in ('jpg', 'jpeg', 'png', 'webp')
  );

commit;
