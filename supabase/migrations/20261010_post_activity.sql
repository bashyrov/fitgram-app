-- Posts can carry a logged workout ("activity") instead of macros — one
-- of the two, never both. Run after 20261009_posts_usernames.sql.
-- Safe to re-run.

alter table public.posts add column if not exists activity jsonb;

alter table public.posts drop constraint if exists posts_one_attachment;
alter table public.posts add constraint posts_one_attachment
    check (macros is null or activity is null);
