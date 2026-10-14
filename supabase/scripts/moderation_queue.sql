-- Moderation queue. Paste one block at a time into Supabase → SQL Editor.
-- Step-by-step guide: docs/MODERATION.md.

-- 1. Open reports, oldest first. post_id is filled when a post was reported.
select
    r.id as report_id,
    r.created_at,
    reporter.username as reporter,
    reported.username as reported,
    r.reported as reported_id,
    substring(r.reason from '^post:([0-9a-f-]{36})')::uuid as post_id,
    r.reason,
    (select count(*) from public.moderation_reports x where x.reported = r.reported) as reports_on_user
from public.moderation_reports r
left join public.public_profiles reporter on reporter.user_id = r.reporter
left join public.public_profiles reported on reported.user_id = r.reported
where r.handled_at is null
order by r.created_at;

-- 2. Look at the reported post (replace POST_ID).
select id, user_id, title, body, photo_path, created_at
from public.posts
where id = 'POST_ID';

-- 2b. Everything the reported user has posted (replace REPORTED_ID).
select id, title, body, photo_path, created_at
from public.posts
where user_id = 'REPORTED_ID'
order by created_at desc;

-- 3. Remove a post (replace POST_ID). If photo_path comes back non-empty,
--    also delete that file in Storage → post-photos.
delete from public.posts where id = 'POST_ID' returning photo_path;

-- 4. Close the report (replace REPORT_ID and the note).
update public.moderation_reports
set handled_at = now(), handled_note = 'removed post'
where id = 'REPORT_ID';
