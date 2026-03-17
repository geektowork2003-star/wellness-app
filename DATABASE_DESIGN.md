# Database Design & Table Creation Guide
## Supabase / PostgreSQL Reference for PWA Projects

---

## 1. Design Principles

1. **One row per user per day** for time-series data (weights, steps, water, habits)
2. **Upsert over insert** for daily logs — `onConflict: "user_id,date"`
3. **Row Level Security on every table** — users see only their own data
4. **Store JSON in text columns** for flexible arrays (equipment, goals, items)
5. **Profile table as single source of truth** for user preferences and health data

---

## 2. Standard Table Patterns

### Pattern A: Daily Log (one value per user per day)
```sql
create table public.steps (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users not null,
  date date not null,
  value integer not null,
  created_at timestamptz default now(),
  unique(user_id, date)
);
```

### Pattern B: Multi-entry per day (food log, notes)
```sql
create table public.food_log (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users not null,
  date date not null,
  meal text,
  description text,
  items jsonb,
  total_kcal integer default 0,
  total_protein_g decimal,
  assessment text,
  suggestion text,
  created_at timestamptz default now()
);
```

### Pattern C: Key-value per user per day (habits)
```sql
create table public.habits (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users not null,
  date date not null,
  habit_id text not null,
  done boolean default false,
  created_at timestamptz default now(),
  unique(user_id, date, habit_id)
);
```

### Pattern D: Profile / settings (one row per user)
```sql
create table public.profiles (
  id uuid references auth.users primary key,
  display_name text,
  -- add all user settings/preferences here
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
```

---

## 3. Row Level Security (RLS)

**Enable on every table. Never skip this.**

```sql
-- Enable RLS
alter table public.table_name enable row level security;

-- Standard "own data only" policy
create policy "own" on public.table_name
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- For profiles table (id = auth.uid())
create policy "own_profile" on public.profiles
  for all
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- For insert-only tables (feedback, logs)
create policy "insert_only" on public.feedback
  for insert with check (true);
```

**Safe policy creation (no IF NOT EXISTS for policies in Postgres):**
```sql
do $$ begin
  if not exists (
    select 1 from pg_policies
    where tablename = 'my_table' and policyname = 'own'
  ) then
    create policy "own" on public.my_table
      for all using (auth.uid() = user_id)
      with check (auth.uid() = user_id);
  end if;
end $$;
```

---

## 4. Auto-create Profile on Signup

```sql
-- Function: create profile row when user signs up
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, display_name, signup_date)
  values (new.id, new.raw_user_meta_data->>'display_name', current_date);
  return new;
end;
$$ language plpgsql security definer;

-- Trigger: fires on every new auth.users insert
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();
```

---

## 5. Migration Best Practices

```sql
-- Always use IF NOT EXISTS — safe to re-run
alter table public.profiles
  add column if not exists new_column text;

-- Never use IF NOT EXISTS for policies — use DO block (see above)

-- Add unique constraint safely
do $$ begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'unique_user_date' and conrelid = 'steps'::regclass
  ) then
    alter table public.steps add constraint unique_user_date unique(user_id, date);
  end if;
end $$;
```

---

## 6. Complete Schema for This Project

```sql
-- ── PROFILES ──────────────────────────────────────────────────────────
create table if not exists public.profiles (
  id uuid references auth.users primary key,
  display_name text, preferred_name text,
  start_weight decimal, goal_weight decimal, height_cm decimal,
  birth_year integer, calorie_target integer,
  onboarded boolean default false,
  user_goals text, equipment text, exercise_pref text,
  diet_style text, health_conds text, challenges text,
  sleep_hrs decimal, sleep_time text, sleep_qual text, sleep_score integer,
  health_sugar decimal, health_chol decimal,
  health_bp_sys decimal, health_bp_dia decimal,
  health_hba1c decimal, health_trig decimal,
  health_hb decimal, health_vitd decimal,
  health_vitb12 decimal, health_uric decimal, health_other text,
  ai_plan text, signup_date date default current_date,
  promo_code text, is_paid boolean default false,
  day_closed_date date,
  created_at timestamptz default now()
);

-- ── DAILY LOGS ────────────────────────────────────────────────────────
create table if not exists public.weights (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users not null,
  date date not null, value decimal not null,
  created_at timestamptz default now(),
  unique(user_id, date)
);

create table if not exists public.steps (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users not null,
  date date not null, value integer not null,
  created_at timestamptz default now(),
  unique(user_id, date)
);

create table if not exists public.water (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users not null,
  date date not null, glasses integer default 0,
  created_at timestamptz default now(),
  unique(user_id, date)
);

create table if not exists public.habits (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users not null,
  date date not null, habit_id text not null, done boolean default false,
  created_at timestamptz default now(),
  unique(user_id, date, habit_id)
);

create table if not exists public.food_log (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users not null,
  date date not null, meal text, description text,
  items jsonb, total_kcal integer default 0,
  total_protein_g decimal, assessment text, suggestion text,
  created_at timestamptz default now()
);

create table if not exists public.health_reports (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users not null,
  sugar decimal, cholesterol decimal,
  bp_systolic decimal, bp_diastolic decimal,
  hba1c decimal, triglycerides decimal,
  haemoglobin decimal, vitamin_d decimal,
  vitamin_b12 decimal, uric_acid decimal, other_notes text,
  created_at timestamptz default now()
);

create table if not exists public.daily_logs (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users not null,
  date date not null,
  what_worked text, next_challenge text,
  created_at timestamptz default now(),
  unique(user_id, date)
);

create table if not exists public.promo_codes (
  code text primary key,
  description text, extends_days integer default 36500,
  created_at timestamptz default now()
);

create table if not exists public.feedback (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users,
  feedback text, topics text, contact text,
  created_at timestamptz default now()
);
```

---

## 7. Useful Queries

```sql
-- Check today's entries for a user
select * from food_log
where user_id = 'uuid-here' and date = current_date
order by created_at;

-- Find duplicate entries (common bug source)
select user_id, date, meal, count(*)
from food_log
group by user_id, date, meal
having count(*) > 1;

-- Remove duplicates keeping earliest
delete from food_log a
using food_log b
where a.ctid > b.ctid
  and a.user_id = b.user_id
  and a.date = b.date
  and a.meal = b.meal;

-- User summary
select p.preferred_name, p.start_weight, p.goal_weight,
       count(distinct f.date) as days_logged
from profiles p
left join food_log f on f.user_id = p.id
group by p.id, p.preferred_name, p.start_weight, p.goal_weight;
```
