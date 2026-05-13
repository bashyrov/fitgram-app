-- Mealgram social layer — public profiles, privacy, friendships, feed,
-- reactions, blocks. Privacy-first: every default value hides data,
-- visibility rules enforced at the RLS layer so no client query can
-- bypass them.
--
-- Apply via:  supabase db push   (after `supabase link` to the project)
-- or:        psql $DATABASE_URL -f supabase/migrations/20260514_social_layer.sql

-- =========================================================================
-- public_profiles — the only profile row a non-friend can ever read.
-- =========================================================================
create table if not exists public.public_profiles (
    user_id     uuid primary key references auth.users(id) on delete cascade,
    username    text unique not null,
    display_name text,
    photo_url   text,
    bio         text,
    created_at  timestamptz not null default now(),
    updated_at  timestamptz not null default now()
);

create index if not exists public_profiles_username_lower_idx
    on public.public_profiles (lower(username));

-- =========================================================================
-- profile_privacy — granular share toggles. Visibility column gates the
-- overall surface; per-field booleans gate individual rows.
-- =========================================================================
create table if not exists public.profile_privacy (
    user_id              uuid primary key references auth.users(id) on delete cascade,
    visibility           text not null default 'private'
                          check (visibility in ('private', 'friends', 'public')),
    show_streak          boolean not null default false,
    show_level           boolean not null default false,
    show_achievements    boolean not null default false,
    show_goal            boolean not null default false,
    show_weekly_stats    boolean not null default false,
    show_recipes         boolean not null default false,
    show_weight_height   boolean not null default false,
    show_meal_details    boolean not null default false,
    updated_at           timestamptz not null default now()
);

-- =========================================================================
-- friendships — mutual consent. user_a < user_b convention enforces a
-- single row per pair.
-- =========================================================================
create table if not exists public.friendships (
    id           uuid primary key default gen_random_uuid(),
    user_a       uuid not null references auth.users(id) on delete cascade,
    user_b       uuid not null references auth.users(id) on delete cascade,
    status       text not null check (status in ('pending', 'accepted', 'blocked')),
    requested_by uuid not null references auth.users(id) on delete cascade,
    requested_at timestamptz not null default now(),
    accepted_at  timestamptz,
    constraint friendships_user_order_check check (user_a < user_b),
    unique (user_a, user_b)
);

create index if not exists friendships_user_a_idx on public.friendships (user_a);
create index if not exists friendships_user_b_idx on public.friendships (user_b);

-- =========================================================================
-- activity_events — events publishable to the feed. Subject to privacy.
-- =========================================================================
create table if not exists public.activity_events (
    id          uuid primary key default gen_random_uuid(),
    user_id     uuid not null references auth.users(id) on delete cascade,
    event_type  text not null check (event_type in (
        'achievement.earned',
        'streak.milestone',
        'recipe.cooked',
        'challenge.won',
        'goal.hit',
        'user.joined'
    )),
    event_data  jsonb not null default '{}'::jsonb,
    created_at  timestamptz not null default now()
);

create index if not exists activity_events_user_created_idx
    on public.activity_events (user_id, created_at desc);

-- =========================================================================
-- reactions — positive only.
-- =========================================================================
create table if not exists public.reactions (
    id            uuid primary key default gen_random_uuid(),
    from_user     uuid not null references auth.users(id) on delete cascade,
    to_user       uuid not null references auth.users(id) on delete cascade,
    event_id      uuid references public.activity_events(id) on delete cascade,
    reaction_type text not null check (reaction_type in (
        'encourage', 'celebrate', 'congratulate', 'heart', 'clap', 'flame', 'sparkles'
    )),
    created_at    timestamptz not null default now(),
    unique (from_user, event_id, reaction_type)
);

-- =========================================================================
-- user_blocks — hard hide, asymmetric.
-- =========================================================================
create table if not exists public.user_blocks (
    blocker    uuid not null references auth.users(id) on delete cascade,
    blocked    uuid not null references auth.users(id) on delete cascade,
    blocked_at timestamptz not null default now(),
    primary key (blocker, blocked)
);

-- =========================================================================
-- moderation_reports — append-only for review.
-- =========================================================================
create table if not exists public.moderation_reports (
    id           uuid primary key default gen_random_uuid(),
    reporter     uuid not null references auth.users(id) on delete cascade,
    reported     uuid not null references auth.users(id) on delete cascade,
    reason       text not null,
    created_at   timestamptz not null default now()
);

-- =========================================================================
-- Helpers
-- =========================================================================
create or replace function public.user_pair(a uuid, b uuid)
returns table(low uuid, high uuid) language sql immutable as $$
    select least(a, b), greatest(a, b);
$$;

create or replace function public.are_friends(viewer uuid, owner uuid)
returns boolean language sql stable as $$
    select exists (
        select 1
        from public.friendships f, public.user_pair(viewer, owner) up
        where f.user_a = up.low and f.user_b = up.high and f.status = 'accepted'
    );
$$;

create or replace function public.is_blocked(viewer uuid, owner uuid)
returns boolean language sql stable as $$
    select exists (
        select 1 from public.user_blocks
        where (blocker = owner and blocked = viewer)
           or (blocker = viewer and blocked = owner)
    );
$$;

create or replace function public.can_view_profile(viewer uuid, owner uuid)
returns boolean language sql stable as $$
    select case
        when viewer = owner then true
        when public.is_blocked(viewer, owner) then false
        else exists (
            select 1 from public.profile_privacy pp
            where pp.user_id = owner
              and (
                  pp.visibility = 'public'
                  or (pp.visibility = 'friends' and public.are_friends(viewer, owner))
              )
        )
    end;
$$;

-- =========================================================================
-- Row Level Security
-- =========================================================================
alter table public.public_profiles   enable row level security;
alter table public.profile_privacy   enable row level security;
alter table public.friendships       enable row level security;
alter table public.activity_events   enable row level security;
alter table public.reactions         enable row level security;
alter table public.user_blocks       enable row level security;
alter table public.moderation_reports enable row level security;

-- public_profiles: I always read my own. I read someone else's only if
-- their profile is viewable by me.
drop policy if exists "public_profiles_self_read" on public.public_profiles;
create policy "public_profiles_self_read" on public.public_profiles
    for select using (auth.uid() = user_id);

drop policy if exists "public_profiles_other_read" on public.public_profiles;
create policy "public_profiles_other_read" on public.public_profiles
    for select using (public.can_view_profile(auth.uid(), user_id));

drop policy if exists "public_profiles_self_write" on public.public_profiles;
create policy "public_profiles_self_write" on public.public_profiles
    for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- profile_privacy: only the owner reads + writes.
drop policy if exists "profile_privacy_self" on public.profile_privacy;
create policy "profile_privacy_self" on public.profile_privacy
    for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- friendships: viewer must be one of the two parties to see / modify.
drop policy if exists "friendships_party_read" on public.friendships;
create policy "friendships_party_read" on public.friendships
    for select using (auth.uid() in (user_a, user_b));

drop policy if exists "friendships_party_insert" on public.friendships;
create policy "friendships_party_insert" on public.friendships
    for insert with check (auth.uid() = requested_by and auth.uid() in (user_a, user_b));

drop policy if exists "friendships_party_update" on public.friendships;
create policy "friendships_party_update" on public.friendships
    for update using (auth.uid() in (user_a, user_b));

drop policy if exists "friendships_party_delete" on public.friendships;
create policy "friendships_party_delete" on public.friendships
    for delete using (auth.uid() in (user_a, user_b));

-- activity_events: owner full access; others see only when can_view_profile
-- holds AND the relevant privacy toggle for that event_type is on.
drop policy if exists "activity_events_self" on public.activity_events;
create policy "activity_events_self" on public.activity_events
    for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "activity_events_other_read" on public.activity_events;
create policy "activity_events_other_read" on public.activity_events
    for select using (
        public.can_view_profile(auth.uid(), user_id)
        and exists (
            select 1 from public.profile_privacy pp
            where pp.user_id = activity_events.user_id and (
                (event_type = 'streak.milestone' and pp.show_streak)
                or (event_type = 'achievement.earned' and pp.show_achievements)
                or (event_type = 'recipe.cooked' and pp.show_recipes)
                or (event_type = 'challenge.won' and pp.show_achievements)
                or (event_type = 'goal.hit' and pp.show_goal)
                or event_type = 'user.joined'
            )
        )
    );

-- reactions: any logged-in user can send + see their own.
drop policy if exists "reactions_self_read" on public.reactions;
create policy "reactions_self_read" on public.reactions
    for select using (auth.uid() in (from_user, to_user));

drop policy if exists "reactions_self_insert" on public.reactions;
create policy "reactions_self_insert" on public.reactions
    for insert with check (auth.uid() = from_user);

drop policy if exists "reactions_self_delete" on public.reactions;
create policy "reactions_self_delete" on public.reactions
    for delete using (auth.uid() = from_user);

-- user_blocks: only the blocker reads + writes.
drop policy if exists "user_blocks_self" on public.user_blocks;
create policy "user_blocks_self" on public.user_blocks
    for all using (auth.uid() = blocker) with check (auth.uid() = blocker);

-- moderation_reports: insert-only by the reporter; nothing readable from
-- client (operators read via service-role queries).
drop policy if exists "moderation_reports_self_insert" on public.moderation_reports;
create policy "moderation_reports_self_insert" on public.moderation_reports
    for insert with check (auth.uid() = reporter);

-- =========================================================================
-- Default-private row for every new auth user. Triggered on user creation
-- so a never-edited profile remains entirely private without any client
-- action.
-- =========================================================================
create or replace function public.ensure_privacy_row()
returns trigger language plpgsql security definer as $$
begin
    insert into public.profile_privacy (user_id) values (new.id)
    on conflict (user_id) do nothing;
    return new;
end;
$$;

drop trigger if exists on_auth_user_created_privacy on auth.users;
create trigger on_auth_user_created_privacy
    after insert on auth.users
    for each row execute function public.ensure_privacy_row();
