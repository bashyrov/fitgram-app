-- Per-account app data on the server, so meals, recipes, weight, water and the
-- rest follow the account to a new iPhone or a reinstall.
--
-- One generic table: the app sends each record as JSON text keyed by
-- (kind, id), e.g. ('meal', '<uuid>'), ('profile', 'self'). The server never
-- reads inside payload; it only stores it for the owner.
--
-- • RLS: a user sees and writes only their own rows.
-- • updated_at is set by the server (clock_timestamp, distinct per row) and
--   is the cursor the app pulls changes with.
-- • deleted = true is a tombstone so other devices remove the record too.
-- • Rows go away with the auth user (on delete cascade), so the existing
--   `account` Edge Function deletes them without changes.
--
-- Safe to re-run.

create table if not exists public.user_records (
    user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
    kind text not null check (char_length(kind) between 1 and 40),
    id text not null check (char_length(id) between 1 and 100),
    payload text not null default '' check (octet_length(payload) <= 500000),
    deleted boolean not null default false,
    updated_at timestamptz not null default clock_timestamp(),
    primary key (user_id, kind, id)
);

create index if not exists user_records_user_updated_idx
    on public.user_records (user_id, updated_at);

create or replace function public.touch_user_record()
returns trigger language plpgsql set search_path = public as $$
begin
    new.updated_at := clock_timestamp();
    return new;
end;
$$;

drop trigger if exists user_records_touch on public.user_records;
create trigger user_records_touch
    before insert or update on public.user_records
    for each row execute function public.touch_user_record();

alter table public.user_records enable row level security;

drop policy if exists user_records_select on public.user_records;
create policy user_records_select on public.user_records
    for select to authenticated using (user_id = auth.uid());

drop policy if exists user_records_insert on public.user_records;
create policy user_records_insert on public.user_records
    for insert to authenticated with check (user_id = auth.uid());

drop policy if exists user_records_update on public.user_records;
create policy user_records_update on public.user_records
    for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists user_records_delete on public.user_records;
create policy user_records_delete on public.user_records
    for delete to authenticated using (user_id = auth.uid());

revoke all on public.user_records from anon;
grant select, insert, update, delete on public.user_records to authenticated;
