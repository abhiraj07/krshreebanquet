-- Shree Banquet Hall: shared Supabase booking access
-- Apply only after reviewing the existing project schema and taking a backup.
-- This migration deliberately keeps booking_dates as the public-safe status table.
-- Client names, phone numbers, event types and notes live only in admin_bookings.

begin;

-- Fail early rather than applying against an incompatible legacy table or wrong Auth account.
do $preflight$
begin
  if to_regclass('public.booking_dates') is null then
    raise exception 'Expected public.booking_dates table was not found; inspect the existing Supabase schema before applying this migration.';
  end if;

  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'booking_dates' and column_name = 'booking_date'
  ) or not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'booking_dates' and column_name = 'status'
  ) then
    raise exception 'public.booking_dates must contain booking_date and status columns.';
  end if;

  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'booking_dates' and column_name = 'updated_at'
  ) then
    raise exception 'public.booking_dates must contain updated_at because the save RPC maintains this timestamp.';
  end if;

  if not exists (
    select 1
    from pg_index i
    join pg_class t on t.oid = i.indrelid
    join pg_namespace n on n.oid = t.relnamespace
    join pg_attribute a on a.attrelid = t.oid and a.attname = 'booking_date'
    where n.nspname = 'public'
      and t.relname = 'booking_dates'
      and i.indisunique
      and i.indisvalid
      and i.indpred is null
      and i.indnkeyatts = 1
      and i.indkey[0] = a.attnum
  ) then
    raise exception 'public.booking_dates needs a valid, non-partial unique index on booking_date alone for safe upsert.';
  end if;

  if (
    select count(*) from auth.users
    where lower(coalesce(email, '')) = 'krshreebanquethall@gmail.com'
  ) <> 1 then
    raise exception 'Expected exactly one Supabase Auth user with email krshreebanquethall@gmail.com. Verify the Auth account before applying.';
  end if;
end;
$preflight$;

-- Lock the existing calendar table to public-safe, read-only columns.
-- All writes are performed by the SECURITY DEFINER booking RPCs below.
alter table public.booking_dates enable row level security;
revoke all on table public.booking_dates from public, anon, authenticated;
grant select (booking_date, status) on table public.booking_dates to anon, authenticated;

drop policy if exists "booking_dates_public_read" on public.booking_dates;
create policy "booking_dates_public_read"
  on public.booking_dates
  for select
  to anon, authenticated
  using (true);

create table if not exists public.admin_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  username text not null unique,
  created_at timestamptz not null default now()
);

alter table public.admin_users enable row level security;
revoke all on public.admin_users from anon, public;
grant select on public.admin_users to authenticated;

drop policy if exists "admin_users_read_own" on public.admin_users;
create policy "admin_users_read_own"
  on public.admin_users
  for select
  to authenticated
  using (user_id = auth.uid());

create or replace function public.is_shree_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.admin_users au
    where au.user_id = (select auth.uid())
  );
$$;

revoke all on function public.is_shree_admin() from public;
grant execute on function public.is_shree_admin() to authenticated;



create table if not exists public.admin_bookings (
  booking_date date primary key,
  status text not null check (status in ('pending', 'booked')),
  client_name text not null default '',
  client_phone text not null default '',
  event_type text not null default '' check (event_type in ('', 'Marriage', 'Engagement', 'Anniversary', 'Meeting', 'Birthday Party', 'Others')),
  notes text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id)
);


-- Realtime is required by the web calendars and Android selectAsFlow streams.
-- Add the three shared tables idempotently; existing publication membership is preserved.
do $realtime$
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    raise exception 'Supabase Realtime publication supabase_realtime was not found; inspect the project publication configuration before applying.';
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'booking_dates'
  ) then
    execute 'alter publication supabase_realtime add table public.booking_dates';
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'admin_bookings'
  ) then
    execute 'alter publication supabase_realtime add table public.admin_bookings';
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'admin_users'
  ) then
    execute 'alter publication supabase_realtime add table public.admin_users';
  end if;
end;
$realtime$;
alter table public.admin_bookings enable row level security;
revoke all on public.admin_bookings from anon, public;

drop policy if exists "admin_bookings_admin_select" on public.admin_bookings;
create policy "admin_bookings_admin_select"
  on public.admin_bookings
  for select
  to authenticated
  using ((select public.is_shree_admin()));

drop policy if exists "admin_bookings_admin_insert" on public.admin_bookings;
create policy "admin_bookings_admin_insert"
  on public.admin_bookings
  for insert
  to authenticated
  with check ((select public.is_shree_admin()));

drop policy if exists "admin_bookings_admin_update" on public.admin_bookings;
create policy "admin_bookings_admin_update"
  on public.admin_bookings
  for update
  to authenticated
  using ((select public.is_shree_admin()))
  with check ((select public.is_shree_admin()));

drop policy if exists "admin_bookings_admin_delete" on public.admin_bookings;
create policy "admin_bookings_admin_delete"
  on public.admin_bookings
  for delete
  to authenticated
  using ((select public.is_shree_admin()));

grant select, insert, update, delete on public.admin_bookings to authenticated;

-- Existing public website continues to read only booking_dates(booking_date, status).
-- Do not add client PII to booking_dates or grant anon access to admin_bookings.

create or replace function public.save_shree_booking(
  p_booking_date date,
  p_status text,
  p_client_name text default '',
  p_client_phone text default '',
  p_event_type text default '',
  p_notes text default ''
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_shree_admin() then
    raise exception 'Admin access required' using errcode = '42501';
  end if;

  if p_status not in ('pending', 'booked') then
    raise exception 'Status must be pending or booked';
  end if;

  if coalesce(p_event_type, '') not in ('', 'Marriage', 'Engagement', 'Anniversary', 'Meeting', 'Birthday Party', 'Others') then
    raise exception 'Event type is not one of the allowed options';
  end if;

  insert into public.booking_dates (booking_date, status, updated_at)
  values (p_booking_date, p_status, now())
  on conflict (booking_date)
  do update set status = excluded.status, updated_at = now();

  insert into public.admin_bookings (
    booking_date, status, client_name, client_phone, event_type, notes, created_at, updated_at, updated_by
  )
  values (
    p_booking_date,
    p_status,
    left(trim(coalesce(p_client_name, '')), 100),
    left(trim(coalesce(p_client_phone, '')), 30),
    left(trim(coalesce(p_event_type, '')), 60),
    left(trim(coalesce(p_notes, '')), 500),
    now(),
    now(),
    auth.uid()
  )
  on conflict (booking_date)
  do update set
    status = excluded.status,
    client_name = excluded.client_name,
    client_phone = excluded.client_phone,
    event_type = excluded.event_type,
    notes = excluded.notes,
    updated_at = now(),
    updated_by = auth.uid();
end;
$$;

create or replace function public.clear_shree_booking(p_booking_date date)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_shree_admin() then
    raise exception 'Admin access required' using errcode = '42501';
  end if;

  delete from public.admin_bookings where booking_date = p_booking_date;
  delete from public.booking_dates where booking_date = p_booking_date;
end;
$$;

revoke all on function public.save_shree_booking(date, text, text, text, text, text) from public;
revoke all on function public.clear_shree_booking(date) from public;
grant execute on function public.save_shree_booking(date, text, text, text, text, text) to authenticated;
grant execute on function public.clear_shree_booking(date) to authenticated;

-- Existing Supabase Auth admin from the current main website.
-- This is an allow-list entry, not a password or secret.
insert into public.admin_users (user_id, username)
select id, 'admin980123'
from auth.users
where lower(coalesce(email, '')) = 'krshreebanquethall@gmail.com'
on conflict (user_id) do update set username = excluded.username;

commit;
