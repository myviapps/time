-- Mythili & Vijay Uttarakhand Trip — Supabase Real-Time Sync Schema
-- Run this entire script once in your Supabase Dashboard -> SQL Editor -> New Query.

create table if not exists public.trip_expenses (
  id bigint not null,
  trip_id text not null default 'mythili-vijay-uttarakhand-2026',
  name text not null,
  category text not null,
  amount numeric(12, 2) not null,
  paid boolean not null default false,
  notes text not null default '',
  updated_at timestamptz not null default now(),
  primary key (trip_id, id)
);

create table if not exists public.trip_sync_meta (
  trip_id text primary key,
  expenses_seeded boolean not null default true,
  packed_items jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

-- Required so Postgres broadcasts full row keys on DELETE events over Realtime
alter table public.trip_expenses replica identity full;
alter table public.trip_sync_meta replica identity full;

-- Enable Row Level Security scoped to non-empty trip room IDs
alter table public.trip_expenses enable row level security;
alter table public.trip_sync_meta enable row level security;

drop policy if exists "trip_expenses_room_rw" on public.trip_expenses;
create policy "trip_expenses_room_rw"
  on public.trip_expenses
  for all
  to anon, authenticated
  using (char_length(trip_id) >= 6)
  with check (char_length(trip_id) >= 6);

drop policy if exists "trip_sync_meta_room_rw" on public.trip_sync_meta;
create policy "trip_sync_meta_room_rw"
  on public.trip_sync_meta
  for all
  to anon, authenticated
  using (char_length(trip_id) >= 6)
  with check (char_length(trip_id) >= 6);

-- Add tables to Supabase Realtime publication idempotently
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'trip_expenses'
  ) then
    alter publication supabase_realtime add table public.trip_expenses;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'trip_sync_meta'
  ) then
    alter publication supabase_realtime add table public.trip_sync_meta;
  end if;
end $$;
