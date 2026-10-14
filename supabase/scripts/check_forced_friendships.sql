-- One-off check after 20261012_social_hardening.sql. Read-only.
--
-- Before that migration a requester could accept their own request. Such
-- rows usually have accepted_at within a few seconds of requested_at; a real
-- person on another phone is slower. An empty result means nothing to do.
-- To undo a row: delete from public.friendships where id = '…';

select
    f.id,
    requester.username as requested_by,
    other.username as other_party,
    f.requested_at,
    f.accepted_at,
    f.accepted_at - f.requested_at as accepted_after
from public.friendships f
left join public.public_profiles requester on requester.user_id = f.requested_by
left join public.public_profiles other
    on other.user_id = case when f.user_a = f.requested_by then f.user_b else f.user_a end
where f.status = 'accepted'
  and (f.accepted_at is null or f.accepted_at - f.requested_at < interval '5 seconds')
order by f.requested_at desc;
