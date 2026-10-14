-- Closes two holes in the social layer.
--
-- • friendships: RLS let the requester insert a row that was already
--   'accepted', or accept their own pending request, which opened the other
--   person's friends-only profile and posts. A trigger now allows only
--   "requester inserts pending" and "the other party accepts".
-- • Premium: public_profiles.is_premium was writable by its owner, and the
--   post trigger trusted it. Premium now comes from premium_until, which only
--   the Worker (service role, after verifying the App Store transaction) can
--   write. is_premium stays as a read-only mirror for the Premium mark.
--
-- Requests without a user JWT (SQL editor, service role) skip the checks, same
-- as enforce_post_rules, so demo data can still be seeded.
--
-- Run after 20261010_post_activity.sql. Safe to re-run.

-- =========================================================================
-- friendships
-- =========================================================================
create or replace function public.guard_friendship()
returns trigger language plpgsql security definer set search_path = public as $$
declare
    me uuid := auth.uid();
    other uuid;
begin
    if me is null then
        return new;
    end if;

    if tg_op = 'INSERT' then
        if new.requested_by is distinct from me or me not in (new.user_a, new.user_b) then
            raise exception 'not_party' using errcode = 'P0001';
        end if;
        if new.status <> 'pending' then
            raise exception 'friendship_must_start_pending' using errcode = 'P0001';
        end if;
        other := case when new.user_a = me then new.user_b else new.user_a end;
        if public.is_blocked(me, other) then
            raise exception 'blocked' using errcode = 'P0001';
        end if;
        new.requested_at := now();
        new.accepted_at := null;
        return new;
    end if;

    if new.user_a is distinct from old.user_a
        or new.user_b is distinct from old.user_b
        or new.requested_by is distinct from old.requested_by
        or new.requested_at is distinct from old.requested_at
    then
        raise exception 'friendship_immutable' using errcode = 'P0001';
    end if;
    if new.status is distinct from old.status then
        if old.status <> 'pending' or new.status <> 'accepted' then
            raise exception 'bad_friendship_transition' using errcode = 'P0001';
        end if;
        if me = old.requested_by then
            raise exception 'cannot_accept_own_request' using errcode = 'P0001';
        end if;
        new.accepted_at := now();
    else
        new.accepted_at := old.accepted_at;
    end if;
    return new;
end;
$$;

drop trigger if exists friendships_guard on public.friendships;
create trigger friendships_guard
    before insert or update on public.friendships
    for each row execute function public.guard_friendship();

-- =========================================================================
-- Premium
-- =========================================================================
alter table public.public_profiles add column if not exists premium_until timestamptz;

create or replace function public.guard_premium()
returns trigger language plpgsql security definer set search_path = public as $$
begin
    if auth.uid() is not null then
        new.premium_until := case when tg_op = 'UPDATE' then old.premium_until else null end;
    end if;
    new.is_premium := coalesce(new.premium_until > now(), false);
    return new;
end;
$$;

drop trigger if exists public_profiles_guard_premium on public.public_profiles;
create trigger public_profiles_guard_premium
    before insert or update on public.public_profiles
    for each row execute function public.guard_premium();

-- Flags set by clients before this migration are not trustworthy. The Worker
-- restores premium_until on each subscriber's next app launch.
update public.public_profiles set is_premium = false where premium_until is null and is_premium;

create or replace function public.enforce_post_rules()
returns trigger language plpgsql security definer set search_path = public as $$
declare
    today date := (now() at time zone 'utc')::date;
begin
    if auth.uid() is null then
        return new;
    end if;
    if new.user_id is distinct from auth.uid() then
        raise exception 'not_owner' using errcode = 'P0001';
    end if;
    if not coalesce(
        (select premium_until > now() from public.public_profiles where user_id = new.user_id), false)
    then
        raise exception 'premium_required' using errcode = 'P0001';
    end if;
    if new.local_day < today - 1 or new.local_day > today + 1 then
        raise exception 'bad_local_day' using errcode = 'P0001';
    end if;
    perform pg_advisory_xact_lock(hashtext('posts:' || new.user_id::text));
    if (select count(*) from public.posts where user_id = new.user_id and local_day = new.local_day) >= 7
        or (select count(*) from public.posts
            where user_id = new.user_id and created_at > now() - interval '24 hours') >= 14
    then
        raise exception 'daily_post_limit' using errcode = 'P0001';
    end if;
    new.created_at := now();
    return new;
end;
$$;
