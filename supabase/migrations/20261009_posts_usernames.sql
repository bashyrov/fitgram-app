-- Posts for friends, likes, one-time usernames and the Premium mark.
--
-- • public_profiles: anyone signed in can find anyone (name, username,
--   avatar, Premium mark) unless one blocked the other. What the profile
--   shows beyond that still follows profile_privacy.visibility.
-- • Usernames: lowercase a–z / 0–9 / "." / "_", 3–20 chars, unique, and
--   locked once chosen (placeholder "mg…" names stay changeable).
-- • posts / post_likes: friends always see each other's posts; everyone
--   else only when profile_privacy.posts_visibility = 'public'. Only
--   Premium users post, at most 7 per local calendar day.
-- • storage bucket post-photos: public read, each user writes only into
--   their own "<user_id>/" folder.
--
-- Safe to re-run.

-- =========================================================================
-- public_profiles
-- =========================================================================
alter table public.public_profiles add column if not exists username_set boolean not null default false;
alter table public.public_profiles add column if not exists is_premium boolean not null default false;

update public.public_profiles
set username_set = true
where not username_set and username !~ '^mg[0-9a-f]{10}$';

alter table public.public_profiles drop constraint if exists public_profiles_username_format;
alter table public.public_profiles add constraint public_profiles_username_format
    check (username ~ '^[a-z][a-z0-9._]{2,19}$') not valid;

create unique index if not exists public_profiles_username_lower_unique
    on public.public_profiles (lower(username));

create or replace function public.guard_username()
returns trigger language plpgsql as $$
begin
    if tg_op = 'INSERT' then
        new.username_set := new.username !~ '^mg[0-9a-f]{10}$';
        return new;
    end if;
    if old.username_set and new.username is distinct from old.username then
        raise exception 'username_locked' using errcode = 'P0001';
    end if;
    new.username_set := old.username_set or new.username_set or new.username is distinct from old.username;
    return new;
end;
$$;

drop trigger if exists public_profiles_guard_username on public.public_profiles;
create trigger public_profiles_guard_username
    before insert or update on public.public_profiles
    for each row execute function public.guard_username();

create or replace function public.username_available(candidate text)
returns boolean language sql stable security definer set search_path = public as $$
    select candidate ~ '^[a-z][a-z0-9._]{2,19}$'
        and not exists (
            select 1 from public.public_profiles
            where lower(username) = lower(candidate)
              and user_id is distinct from auth.uid()
        );
$$;
grant execute on function public.username_available(text) to authenticated;

-- Search: everyone signed in sees the identity card of everyone they
-- haven't blocked (and who hasn't blocked them).
drop policy if exists "public_profiles_other_read" on public.public_profiles;
drop policy if exists "public_profiles_directory_read" on public.public_profiles;
create policy "public_profiles_directory_read" on public.public_profiles
    for select to authenticated
    using (auth.uid() = user_id or not public.is_blocked(auth.uid(), user_id));

grant execute on function public.can_view_profile(uuid, uuid) to authenticated;

-- =========================================================================
-- profile_privacy.posts_visibility
-- =========================================================================
alter table public.profile_privacy add column if not exists posts_visibility text not null default 'friends';
alter table public.profile_privacy drop constraint if exists profile_privacy_posts_visibility_check;
alter table public.profile_privacy add constraint profile_privacy_posts_visibility_check
    check (posts_visibility in ('friends', 'public'));

create or replace function public.can_view_posts(viewer uuid, owner uuid)
returns boolean language sql stable security definer set search_path = public as $$
    select case
        when viewer is distinct from auth.uid() then false
        when viewer = owner then true
        when public.is_blocked(viewer, owner) then false
        when public.are_friends(viewer, owner) then true
        else coalesce(
            (select pp.posts_visibility = 'public' from public.profile_privacy pp where pp.user_id = owner),
            false
        )
    end;
$$;
grant execute on function public.can_view_posts(uuid, uuid) to authenticated;

-- =========================================================================
-- posts
-- =========================================================================
create table if not exists public.posts (
    id          uuid primary key default gen_random_uuid(),
    user_id     uuid not null references auth.users(id) on delete cascade,
    title       text not null check (char_length(btrim(title)) between 3 and 60),
    body        text not null default '' check (char_length(body) <= 500),
    photo_path  text check (photo_path is null or photo_path like (user_id::text || '/%')),
    macros      jsonb,
    local_day   date not null,
    created_at  timestamptz not null default now()
);

create index if not exists posts_user_created_idx on public.posts (user_id, created_at desc);
create index if not exists posts_user_day_idx on public.posts (user_id, local_day);

-- Premium + daily limit. Inserts made from the SQL editor (no JWT) skip
-- the checks so demo data can be seeded.
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
    if not coalesce((select is_premium from public.public_profiles where user_id = new.user_id), false) then
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

drop trigger if exists posts_enforce_rules on public.posts;
create trigger posts_enforce_rules
    before insert on public.posts
    for each row execute function public.enforce_post_rules();

alter table public.posts enable row level security;

drop policy if exists "posts_read" on public.posts;
create policy "posts_read" on public.posts
    for select to authenticated using (public.can_view_posts(auth.uid(), user_id));

drop policy if exists "posts_insert_own" on public.posts;
create policy "posts_insert_own" on public.posts
    for insert to authenticated with check (auth.uid() = user_id);

drop policy if exists "posts_delete_own" on public.posts;
create policy "posts_delete_own" on public.posts
    for delete to authenticated using (auth.uid() = user_id);

-- =========================================================================
-- post_likes
-- =========================================================================
create table if not exists public.post_likes (
    post_id    uuid not null references public.posts(id) on delete cascade,
    user_id    uuid not null references auth.users(id) on delete cascade,
    created_at timestamptz not null default now(),
    primary key (post_id, user_id)
);

create index if not exists post_likes_post_idx on public.post_likes (post_id);

alter table public.post_likes enable row level security;

-- The sub-select runs under posts RLS, so likes are visible exactly when
-- the post is.
drop policy if exists "post_likes_read" on public.post_likes;
create policy "post_likes_read" on public.post_likes
    for select to authenticated
    using (exists (select 1 from public.posts p where p.id = post_likes.post_id));

drop policy if exists "post_likes_insert_own" on public.post_likes;
create policy "post_likes_insert_own" on public.post_likes
    for insert to authenticated
    with check (
        auth.uid() = user_id
        and exists (select 1 from public.posts p where p.id = post_likes.post_id)
    );

drop policy if exists "post_likes_delete_own" on public.post_likes;
create policy "post_likes_delete_own" on public.post_likes
    for delete to authenticated using (auth.uid() = user_id);

-- =========================================================================
-- Storage: post-photos
-- =========================================================================
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('post-photos', 'post-photos', true, 5242880, array['image/jpeg'])
on conflict (id) do update
    set public = true, file_size_limit = 5242880, allowed_mime_types = array['image/jpeg'];

drop policy if exists "post_photos_select_own" on storage.objects;
create policy "post_photos_select_own" on storage.objects
    for select to authenticated
    using (bucket_id = 'post-photos' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "post_photos_insert_own" on storage.objects;
create policy "post_photos_insert_own" on storage.objects
    for insert to authenticated
    with check (bucket_id = 'post-photos' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "post_photos_delete_own" on storage.objects;
create policy "post_photos_delete_own" on storage.objects
    for delete to authenticated
    using (bucket_id = 'post-photos' and (storage.foldername(name))[1] = auth.uid()::text);
