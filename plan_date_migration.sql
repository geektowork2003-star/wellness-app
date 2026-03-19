-- Add ai_plan_date column to profiles
alter table public.profiles
  add column if not exists ai_plan_date date;
