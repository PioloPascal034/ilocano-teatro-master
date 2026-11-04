-- Stage B. Review and apply manually after the structured-lessons migration.
-- No existing lesson, progress, publication, or quiz data is rewritten.
begin;

alter table public.lessons
  add column if not exists overview text,
  add column if not exists estimated_reading_minutes integer;

alter table public.lessons
  add constraint lessons_estimated_reading_minutes_range
  check (estimated_reading_minutes is null
         or estimated_reading_minutes between 1 and 999);

-- Table-level SELECT already covers these columns. Existing editor-only
-- INSERT/UPDATE RLS still applies to these column grants.
grant insert (overview, estimated_reading_minutes)
  on public.lessons to authenticated;
grant update (overview, estimated_reading_minutes)
  on public.lessons to authenticated;

commit;

-- Legacy rows retain NULL metadata. Clients calculate reading time from the
-- current lesson text; the stored estimate is updated when an editor saves.
