-- Backend for BIOL3139 lima-bean-touch.html
-- Intended to be applied to a Supabase project.

create extension if not exists pgcrypto;

create table if not exists public.lima_bean_submissions (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  experiment_id text not null,
  group_number integer not null check (group_number between 1 and 20),
  shelf text not null check (shelf in ('Top','Middle','Bottom')),
  expected_members integer not null check (expected_members between 2 and 8),
  member_number integer not null check (member_number between 1 and 8),
  touched numeric[] not null check (cardinality(touched) >= 1),
  control numeric[] not null check (cardinality(control) >= 1),
  updated_at timestamptz not null default now(),
  constraint lima_bean_one_member_slot
    unique (experiment_id, group_number, member_number),
  constraint lima_bean_member_within_group_size
    check (member_number <= expected_members)
);

alter table public.lima_bean_submissions enable row level security;

grant select, insert, update, delete
on table public.lima_bean_submissions
to authenticated;

drop policy if exists "class can read submissions"
on public.lima_bean_submissions;

create policy "class can read submissions"
on public.lima_bean_submissions
for select
to authenticated
using (auth.uid() is not null);

drop policy if exists "student can create own submission"
on public.lima_bean_submissions;

create policy "student can create own submission"
on public.lima_bean_submissions
for insert
to authenticated
with check (owner_id = auth.uid());

drop policy if exists "student can update own submission"
on public.lima_bean_submissions;

create policy "student can update own submission"
on public.lima_bean_submissions
for update
to authenticated
using (owner_id = auth.uid())
with check (owner_id = auth.uid());

drop policy if exists "student can delete own submission"
on public.lima_bean_submissions;

create policy "student can delete own submission"
on public.lima_bean_submissions
for delete
to authenticated
using (owner_id = auth.uid());

-- Add the table to Supabase Realtime, but only if it is not already present.
do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'lima_bean_submissions'
  ) then
    alter publication supabase_realtime
      add table public.lima_bean_submissions;
  end if;
end
$$;
