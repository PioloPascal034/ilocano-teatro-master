-- Private profile avatars. Apply manually after reviewing the existing Storage
-- configuration; this migration never makes a bucket public or changes an
-- existing bucket's settings.
begin;

alter table public.profiles
  add column if not exists avatar_storage_path text;

alter table public.profiles enable row level security;

grant update (avatar_storage_path) on public.profiles to authenticated;

-- Restrictive RLS composes with every permissive UPDATE policy. It guarantees
-- authenticated clients can only update their own profile row, even if another
-- permissive policy is added later.
create policy profiles_avatar_storage_path_own
  as restrictive on public.profiles for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

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
-- protections when an existing client-facing policy could also apply to this
-- bucket. Inspect every existing policy by its effective command predicates,
-- never by name. If a profile-avatar policy already exists, stop for review.

do $$
declare
  conflicting_policy record;
  predicate text;
  predicates text[];
  bucket_match text[];
  character_index integer;
  parenthesis_depth integer;
  bucket_guard_depth integer;
  in_string boolean;
  has_unguarded_or boolean;
  current_character text;
  next_character text;
  is_and boolean;
  is_or boolean;
  has_conflict boolean := false;
begin
  for conflicting_policy in
    select p.policyname, p.roles, p.cmd, p.qual, p.with_check
    from pg_catalog.pg_policies as p
    where p.schemaname = 'storage'
      and p.tablename = 'objects'
      and p.cmd in ('SELECT', 'INSERT', 'UPDATE', 'DELETE', 'ALL')
      and (
        'public' = any(p.roles)
        or 'anon' = any(p.roles)
        or 'authenticated' = any(p.roles)
      )
  loop
    predicates := case conflicting_policy.cmd
      when 'SELECT' then array[conflicting_policy.qual]
      when 'INSERT' then array[conflicting_policy.with_check]
      when 'UPDATE' then array[
        conflicting_policy.qual, conflicting_policy.with_check
      ]
      when 'DELETE' then array[conflicting_policy.qual]
      when 'ALL' then array[
        conflicting_policy.qual, conflicting_policy.with_check
      ]
      else array[null::text]
    end;

    foreach predicate in array predicates
    loop
      bucket_match := regexp_match(
        coalesce(predicate, ''),
        $bucket_scope$^\(*[[:space:]]*bucket_id[[:space:]]*=[[:space:]]*'([^']+)'(::text)?[[:space:]]*\)*[[:space:]]+AND[[:space:]]$bucket_scope$,
        'i'
      );

      if predicate is null
         or bucket_match is null
         or lower(bucket_match[1]) = 'ilocano-profile-avatars' then
        has_conflict := true;
        exit;
      end if;

      -- A leading bucket equality alone is insufficient if an unparenthesized
      -- OR later in the expression can bypass it. Permit only policies whose
      -- OR branches are nested below the AND that establishes the bucket guard.
      parenthesis_depth := 0;
      bucket_guard_depth := null;
      in_string := false;
      has_unguarded_or := false;
      character_index := 1;

      while character_index <= char_length(predicate)
      loop
        current_character := substr(predicate, character_index, 1);

        if in_string then
          if current_character = chr(39) then
            next_character := substr(predicate, character_index + 1, 1);
            if next_character = chr(39) then
              character_index := character_index + 2;
              continue;
            end if;
            in_string := false;
          end if;
          character_index := character_index + 1;
          continue;
        end if;

        if current_character = chr(39) then
          in_string := true;
        elsif current_character = '(' then
          parenthesis_depth := parenthesis_depth + 1;
        elsif current_character = ')' then
          parenthesis_depth := parenthesis_depth - 1;
        end if;

        is_and :=
          upper(substr(predicate, character_index, 3)) = 'AND'
          and (
            character_index = 1
            or substr(predicate, character_index - 1, 1) !~ '[[:alnum:]_]'
          )
          and (
            character_index + 3 > char_length(predicate)
            or substr(predicate, character_index + 3, 1) !~ '[[:alnum:]_]'
          );
        is_or :=
          upper(substr(predicate, character_index, 2)) = 'OR'
          and (
            character_index = 1
            or substr(predicate, character_index - 1, 1) !~ '[[:alnum:]_]'
          )
          and (
            character_index + 2 > char_length(predicate)
            or substr(predicate, character_index + 2, 1) !~ '[[:alnum:]_]'
          );

        if is_and and bucket_guard_depth is null then
          bucket_guard_depth := parenthesis_depth;
        elsif is_or
          and bucket_guard_depth is not null
          and parenthesis_depth = bucket_guard_depth then
          has_unguarded_or := true;
          exit;
        end if;

        character_index := character_index + 1;
      end loop;

      if bucket_guard_depth is null or has_unguarded_or then
        has_conflict := true;
        exit;
      end if;
    end loop;

    if has_conflict then
      exit;
    end if;
  end loop;

  if has_conflict then
    raise exception
      'Existing storage.objects policy % (roles %, command %) cannot be proven to be restricted to another bucket. Review it manually before retrying. USING predicate: %; WITH CHECK predicate: %',
      conflicting_policy.policyname, conflicting_policy.roles,
      conflicting_policy.cmd, conflicting_policy.qual,
      conflicting_policy.with_check;
  end if;
end;
$$;

-- A user's object is a single file directly under their Auth UUID folder.
-- Owners and teachers authorized to review a student can read profile photos;
-- object listing remains excluded by the operation-aware SELECT predicate.
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
        and (
          p.id = (select auth.uid())
          or (p.role = 'student' and public.can_review(p.id))
        )
    )
  );

create policy ilocano_profile_avatars_insert_own
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'ilocano-profile-avatars'
    and pg_catalog.cardinality(storage.foldername(name)) = 1
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and lower(storage.extension(name)) in ('jpg', 'jpeg', 'png', 'webp')
  );

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

create policy ilocano_profile_avatars_delete_own
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'ilocano-profile-avatars'
    and pg_catalog.cardinality(storage.foldername(name)) = 1
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and lower(storage.extension(name)) in ('jpg', 'jpeg', 'png', 'webp')
  );

commit;
