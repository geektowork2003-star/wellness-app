-- Run in Supabase SQL Editor

create table if not exists public.feedback (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users,
  feedback text,
  topics text,
  contact text,
  created_at timestamptz default now()
);

alter table public.feedback enable row level security;

do $$ begin
  if not exists (
    select 1 from pg_policies where tablename='feedback' and policyname='insert_feedback'
  ) then
    create policy "insert_feedback" on public.feedback
      for insert with check (true);
  end if;
  if not exists (
    select 1 from pg_policies where tablename='feedback' and policyname='read_own_feedback'
  ) then
    create policy "read_own_feedback" on public.feedback
      for select using (auth.uid() = user_id);
  end if;
end $$;
