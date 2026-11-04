-- Prepared migration for Stage A structured lessons.
-- Review and apply manually in Supabase SQL Editor. Do not run from Flutter.
begin;

alter table public.lessons
  add column if not exists sections jsonb;

alter table public.lessons
  drop constraint if exists lessons_sections_object;

alter table public.lessons
  add constraint lessons_sections_object
  check (
    sections is null
    or (
      jsonb_typeof(sections) = 'object'
      and (sections->'introduction' is null or jsonb_typeof(sections->'introduction') = 'string')
      and (sections->'discussion' is null or jsonb_typeof(sections->'discussion') = 'string')
      and (sections->'examples' is null or jsonb_typeof(sections->'examples') = 'string')
      and (sections->'activities' is null or jsonb_typeof(sections->'activities') = 'string')
      and (sections->'summary' is null or jsonb_typeof(sections->'summary') = 'string')
    )
  );

-- Preserve the existing editor-only write surface while allowing the new field.
grant insert (sections) on public.lessons to authenticated;
grant update (sections) on public.lessons to authenticated;

commit;

-- Compatibility notes:
-- * Existing lessons keep sections = NULL and continue rendering from content.
-- * Structured lessons use keys: introduction, discussion, examples, activities, summary.
-- * Supported section keys must contain JSON strings; unknown keys remain allowed
--   for forward-compatible additive content.
-- * The existing RLS policies remain in force; no publication visibility changes are made.
