-- Run this in Supabase → SQL Editor → New Query → Run
-- Safe to re-run — all statements use IF NOT EXISTS

alter table public.profiles
  add column if not exists preferred_name text,
  add column if not exists onboarded boolean default false,
  add column if not exists equipment text,
  add column if not exists exercise_pref text,
  add column if not exists diet_style text,
  add column if not exists health_conds text,
  add column if not exists sleep_hrs decimal,
  add column if not exists sleep_time text,
  add column if not exists sleep_qual text,
  add column if not exists sleep_score integer,
  add column if not exists challenges text,
  add column if not exists ai_plan text,
  add column if not exists anthropic_key text,
  add column if not exists signup_date date default current_date,
  add column if not exists promo_code text,
  add column if not exists is_paid boolean default false,
  add column if not exists day_closed_date date;

create table if not exists public.promo_codes (
  code text primary key,
  description text,
  extends_days integer default 36500,
  created_at timestamptz default now()
);

insert into public.promo_codes (code, description, extends_days)
values
  ('WELLNESS2025', 'Founder promo — lifetime free', 36500),
  ('FAMILY2025',   'Family invite — 6 months free', 180),
  ('BETA',         'Beta tester — 3 months free',   90)
on conflict do nothing;

create table if not exists public.daily_logs (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users not null,
  date date not null,
  what_worked text,
  next_challenge text,
  created_at timestamptz default now(),
  unique(user_id, date)
);

alter table public.daily_logs enable row level security;

do $$ begin
  if not exists (
    select 1 from pg_policies where tablename='daily_logs' and policyname='own'
  ) then
    create policy "own" on daily_logs for all
      using (auth.uid() = user_id)
      with check (auth.uid() = user_id);
  end if;
end $$;

-- Reset onboarded flag for existing users so they go through onboarding
update public.profiles set onboarded = false where onboarded is null;

-- Additional columns for goals and plan customisation
alter table public.profiles
  add column if not exists user_goals text;
