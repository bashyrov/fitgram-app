-- Lets the operator mark a report as handled, so the daily moderation
-- queue (supabase/scripts/moderation_queue.sql) only shows open reports.
-- Clients still cannot read or update reports: RLS only allows the insert.
--
-- Safe to re-run.

alter table public.moderation_reports add column if not exists handled_at timestamptz;
alter table public.moderation_reports add column if not exists handled_note text;

create index if not exists moderation_reports_open_idx
    on public.moderation_reports (created_at)
    where handled_at is null;
