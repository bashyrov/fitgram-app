-- What a user shares on their profile (streak, level, badges, goal, weekly
-- stats, top recipes, weight/height), so friends actually see it.
--
-- The app writes only the fields the owner switched on in Privacy, and
-- deletes the row when the profile is "Only me". Readers: the owner, and
-- whoever can_view_profile() allows (friends, or everyone for a public
-- profile; never blocked users).
--
-- Rows go away with the auth user (on delete cascade). Safe to re-run.

create table if not exists public.profile_shares (
    user_id uuid primary key default auth.uid() references auth.users (id) on delete cascade,
    payload text not null default '{}' check (octet_length(payload) <= 20000),
    updated_at timestamptz not null default now()
);

create or replace function public.touch_profile_share()
returns trigger language plpgsql set search_path = public as $$
begin
    new.updated_at := now();
    return new;
end;
$$;

drop trigger if exists profile_shares_touch on public.profile_shares;
create trigger profile_shares_touch
    before insert or update on public.profile_shares
    for each row execute function public.touch_profile_share();

alter table public.profile_shares enable row level security;

drop policy if exists profile_shares_read on public.profile_shares;
create policy profile_shares_read on public.profile_shares
    for select to authenticated
    using (user_id = auth.uid() or public.can_view_profile(auth.uid(), user_id));

drop policy if exists profile_shares_insert on public.profile_shares;
create policy profile_shares_insert on public.profile_shares
    for insert to authenticated with check (user_id = auth.uid());

drop policy if exists profile_shares_update on public.profile_shares;
create policy profile_shares_update on public.profile_shares
    for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists profile_shares_delete on public.profile_shares;
create policy profile_shares_delete on public.profile_shares
    for delete to authenticated using (user_id = auth.uid());

revoke all on public.profile_shares from anon;
grant select, insert, update, delete on public.profile_shares to authenticated;
