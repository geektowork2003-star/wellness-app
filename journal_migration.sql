-- Add journal_notes and challenge_notes to daily_logs
alter table public.daily_logs
  add column if not exists journal_notes   text,
  add column if not exists challenge_notes text;
