-- Ensure authenticated students can read published Story Vault content even
-- when the base setup policies were not present in the hosted database.
-- Apply after 20261101000001_story_chapters_and_reading_progress.sql.

begin;

alter table public.cultural_stories enable row level security;
alter table public.story_chapters enable row level security;

grant select on public.cultural_stories, public.story_chapters to authenticated;

drop policy if exists stories_read on public.cultural_stories;
create policy stories_read
  on public.cultural_stories for select to authenticated
  using (is_published);

drop policy if exists story_chapters_published_read
  on public.story_chapters;
create policy story_chapters_published_read
  on public.story_chapters for select to authenticated
  using (
    is_published
    and exists (
      select 1
      from public.cultural_stories as s
      where s.story_id = story_chapters.story_id
        and s.is_published
    )
  );

commit;
