-- shift-hours — Supabase schema
-- Paste this whole file into the Supabase SQL Editor and run it once.
--
-- The isolation between users is enforced *by the database*, not by the app.
-- Row Level Security means Postgres itself refuses to return one user's rows to
-- another, so a mistake in the frontend cannot leak anyone's hours.

-- ---------------------------------------------------------------- shifts
create table if not exists public.shifts (
  user_id    uuid        not null references auth.users (id) on delete cascade,
  id         text        not null,             -- client-generated, stable across devices
  date       date        not null,
  start_time text        not null,             -- "13:00"
  end_time   text        not null,             -- "18:00" ("00:00" = midnight)
  label      text        not null default '',
  brk        integer,                          -- null = use the automatic break
  holiday    boolean     not null default false,
  deleted    boolean     not null default false,  -- soft delete, so removals propagate
  updated_at timestamptz not null default now(), -- last-write-wins on conflict
  primary key (user_id, id)
);

alter table public.shifts enable row level security;

drop policy if exists "own shifts" on public.shifts;
create policy "own shifts" on public.shifts
  for all
  using      (auth.uid() = user_id)   -- can only read own rows
  with check (auth.uid() = user_id);  -- can only write rows owned by self

create index if not exists shifts_user_date_idx on public.shifts (user_id, date);

-- ---------------------------------------------------------------- settings
-- Rate bands, weekly limit, break rule — one JSON blob per user.
create table if not exists public.settings (
  user_id    uuid        primary key references auth.users (id) on delete cascade,
  data       jsonb       not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.settings enable row level security;

drop policy if exists "own settings" on public.settings;
create policy "own settings" on public.settings
  for all
  using      (auth.uid() = user_id)
  with check (auth.uid() = user_id);
