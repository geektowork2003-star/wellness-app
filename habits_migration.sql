-- Add ai_key_habits column to profiles
-- Stores structured habit list from AI plan as JSON
alter table public.profiles
  add column if not exists ai_key_habits text;
