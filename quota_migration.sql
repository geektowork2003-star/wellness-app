-- Run in Supabase SQL Editor
-- Server-side AI quota tracking (replaces localStorage)

create table if not exists public.daily_usage (
  user_id uuid references auth.users not null,
  date date not null,
  analysis_count integer default 0,
  primary key (user_id, date)
);

alter table public.daily_usage enable row level security;

do $$ begin
  if not exists (
    select 1 from pg_policies
    where tablename='daily_usage' and policyname='own'
  ) then
    create policy "own" on public.daily_usage
      for all using (auth.uid() = user_id)
      with check (auth.uid() = user_id);
  end if;
end $$;

-- To reset quota for a user during testing:
-- delete from daily_usage where user_id = 'uuid-here' and date = current_date;
-- Or reset all users today:
-- delete from daily_usage where date = current_date;
