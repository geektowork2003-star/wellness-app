-- ============================================================
-- WELLNESS APP — ENGAGEMENT DASHBOARD QUERIES
-- Run each section in Supabase SQL Editor
-- Best run weekly to track trends
-- ============================================================


-- ════════════════════════════════════════════════════════════
-- SECTION 1: USER BASE OVERVIEW
-- Run this first — gives you the big picture
-- ════════════════════════════════════════════════════════════

select
  count(*)                                                    as total_signups,
  count(*) filter (where onboarded = true)                    as completed_onboarding,
  count(*) filter (where onboarded = false or onboarded is null) as dropped_at_onboarding,
  count(*) filter (where day_closed_date is not null)         as ever_closed_a_day,
  count(*) filter (where ai_plan is not null)                 as have_ai_plan,
  count(*) filter (where health_hba1c is not null
                      or health_sugar is not null
                      or health_chol is not null)             as entered_health_params,
  round(
    count(*) filter (where onboarded = true) * 100.0 / nullif(count(*), 0)
  , 1)                                                        as onboarding_completion_pct
from public.profiles;


-- ════════════════════════════════════════════════════════════
-- SECTION 2: DAILY ACTIVE USERS (last 30 days)
-- Shows engagement trend — are people coming back?
-- ════════════════════════════════════════════════════════════

select
  activity_date,
  count(distinct user_id) as active_users
from (
  -- Food logging activity
  select user_id, date as activity_date from food_log
  union
  -- Habit checking activity
  select user_id, date from habits where done = true
  union
  -- Step logging activity
  select user_id, date from steps
  union
  -- Water logging activity
  select user_id, date from water
  union
  -- Close Day activity
  select user_id, day_closed_date as activity_date
  from profiles where day_closed_date is not null
) all_activity
where activity_date >= current_date - 30
  and activity_date <= current_date
group by activity_date
order by activity_date desc;


-- ════════════════════════════════════════════════════════════
-- SECTION 3: PER-USER ENGAGEMENT SCORE
-- Who are your most engaged users? Who has gone quiet?
-- ════════════════════════════════════════════════════════════

select
  u.email,
  p.preferred_name,
  p.signup_date,
  current_date - p.signup_date                               as days_since_signup,

  -- Activity counts
  count(distinct f.date)                                     as days_logged_food,
  count(distinct s.date)                                     as days_logged_steps,
  count(distinct w.date)                                     as days_logged_water,
  count(distinct dl.date)                                    as days_closed_day,

  -- Recency (last seen)
  greatest(
    max(f.date),
    max(s.date),
    max(w.date),
    p.day_closed_date
  )                                                          as last_active_date,
  current_date - greatest(
    max(f.date),
    max(s.date),
    max(w.date),
    p.day_closed_date
  )                                                          as days_since_active,

  -- Health data entered?
  case when p.health_hba1c is not null
            or p.health_sugar is not null
       then 'Yes' else 'No'
  end                                                        as health_params_entered,

  -- Simple engagement score (0-100)
  least(100, (
    count(distinct f.date) * 5 +
    count(distinct dl.date) * 10 +
    count(distinct s.date) * 3 +
    count(distinct w.date) * 2 +
    case when p.health_hba1c is not null then 10 else 0 end +
    case when p.ai_plan is not null then 5 else 0 end
  ))                                                         as engagement_score

from public.profiles p
join auth.users u on u.id = p.id
left join food_log f  on f.user_id  = p.id
left join steps s     on s.user_id  = p.id
left join water w     on w.user_id  = p.id
left join daily_logs dl on dl.user_id = p.id
where p.onboarded = true
group by u.email, p.preferred_name, p.signup_date,
         p.day_closed_date, p.health_hba1c, p.health_sugar,
         p.ai_plan
order by engagement_score desc;


-- ════════════════════════════════════════════════════════════
-- SECTION 4: FEATURE USAGE BREAKDOWN
-- Which features are actually being used?
-- ════════════════════════════════════════════════════════════

select 'Food logging'    as feature,
       count(distinct user_id) as users_used,
       count(distinct date)    as total_days_used,
       round(count(*)::numeric / nullif(count(distinct user_id),0), 1) as avg_entries_per_user
from food_log

union all

select 'Steps logging',
       count(distinct user_id),
       count(distinct date),
       round(count(*)::numeric / nullif(count(distinct user_id),0), 1)
from steps

union all

select 'Water logging',
       count(distinct user_id),
       count(distinct date),
       round(avg(glasses)::numeric, 1)
from water

union all

select 'Habit checking',
       count(distinct user_id),
       count(distinct date),
       round(count(*)::numeric / nullif(count(distinct user_id),0), 1)
from habits where done = true

union all

select 'Close My Day',
       count(distinct user_id),
       count(*),
       null
from daily_logs

union all

select 'AI food analysis',
       count(distinct user_id),
       count(distinct date),
       null
from food_log
where assessment is not null and assessment != ''

union all

select 'Weight logging',
       count(distinct user_id),
       count(distinct date),
       null
from weights

union all

select 'Health params entered',
       count(*),
       null,
       null
from profiles
where health_hba1c is not null
   or health_sugar is not null
   or health_chol is not null

order by users_used desc;


-- ════════════════════════════════════════════════════════════
-- SECTION 5: FOOD HABITS — WHAT ARE PEOPLE EATING?
-- ════════════════════════════════════════════════════════════

-- Most logged meal types
select
  meal,
  count(*)                                                   as times_logged,
  count(distinct user_id)                                    as unique_users,
  round(avg(total_kcal) filter (where total_kcal > 0), 0)   as avg_kcal
from food_log
group by meal
order by times_logged desc;

-- Average calories logged vs typical targets
select
  count(distinct user_id)                                    as users_who_analysed,
  round(avg(daily_kcal), 0)                                 as avg_daily_kcal,
  round(min(daily_kcal), 0)                                 as min_daily_kcal,
  round(max(daily_kcal), 0)                                 as max_daily_kcal
from (
  select user_id, date, sum(total_kcal) as daily_kcal
  from food_log
  where total_kcal > 0
  group by user_id, date
) daily;


-- ════════════════════════════════════════════════════════════
-- SECTION 6: HABIT COMPLETION RATES
-- Are people actually doing their habits?
-- ════════════════════════════════════════════════════════════

select
  habit_id,
  count(*) filter (where done = true)                        as times_completed,
  count(*) filter (where done = false)                       as times_missed,
  count(distinct user_id)                                    as unique_users,
  round(
    count(*) filter (where done = true) * 100.0 /
    nullif(count(*), 0)
  , 1)                                                       as completion_pct
from habits
where date >= current_date - 30
group by habit_id
order by completion_pct desc;


-- ════════════════════════════════════════════════════════════
-- SECTION 7: RETENTION — ARE USERS COMING BACK?
-- The most important metric for any wellness app
-- ════════════════════════════════════════════════════════════

with user_weeks as (
  select
    user_id,
    date_trunc('week', activity_date::date) as week
  from (
    select user_id, date as activity_date from food_log
    union select user_id, date from habits where done = true
    union select user_id, date from steps
    union select user_id, date from water
  ) all_activity
  group by user_id, date_trunc('week', activity_date::date)
),
signup_week as (
  select id as user_id,
         date_trunc('week', signup_date) as first_week
  from profiles where onboarded = true
)
select
  sw.first_week                                              as signup_week,
  count(distinct sw.user_id)                                 as signed_up,
  count(distinct uw1.user_id)                                as active_week_1,
  count(distinct uw2.user_id)                                as active_week_2,
  count(distinct uw3.user_id)                                as active_week_3,
  count(distinct uw4.user_id)                                as active_week_4,
  round(count(distinct uw1.user_id)*100.0/nullif(count(distinct sw.user_id),0),0) as w1_retention_pct,
  round(count(distinct uw4.user_id)*100.0/nullif(count(distinct sw.user_id),0),0) as w4_retention_pct
from signup_week sw
left join user_weeks uw1 on uw1.user_id = sw.user_id
  and uw1.week = sw.first_week + interval '1 week'
left join user_weeks uw2 on uw2.user_id = sw.user_id
  and uw2.week = sw.first_week + interval '2 weeks'
left join user_weeks uw3 on uw3.user_id = sw.user_id
  and uw3.week = sw.first_week + interval '3 weeks'
left join user_weeks uw4 on uw4.user_id = sw.user_id
  and uw4.week = sw.first_week + interval '4 weeks'
group by sw.first_week
order by sw.first_week desc;


-- ════════════════════════════════════════════════════════════
-- SECTION 8: CLOSE MY DAY — DEPTH OF USE
-- Are people doing the reflective part?
-- ════════════════════════════════════════════════════════════

select
  u.email,
  p.preferred_name,
  count(dl.id)                                               as days_closed,
  max(dl.date)                                               as last_closed,
  -- Did they pick tomorrow challenges?
  count(dl.id) filter (where dl.next_challenge is not null)  as times_picked_challenge,
  -- Most common challenges
  mode() within group (order by dl.next_challenge)           as favourite_challenge
from daily_logs dl
join public.profiles p on p.id = dl.user_id
join auth.users u on u.id = dl.user_id
group by u.email, p.preferred_name
order by days_closed desc;


-- ════════════════════════════════════════════════════════════
-- SECTION 9: AI USAGE & QUOTA
-- How much AI are people actually consuming?
-- ════════════════════════════════════════════════════════════

-- Daily AI usage this week
select
  date,
  count(distinct user_id)                                    as users_used_ai,
  sum(analysis_count)                                        as total_ai_calls,
  round(avg(analysis_count), 1)                             as avg_calls_per_user,
  max(analysis_count)                                        as max_calls_single_user
from daily_usage
where date >= current_date - 14
group by date
order by date desc;

-- Who hits the daily limit most often?
select
  u.email,
  count(*) filter (where du.analysis_count >= 3)            as days_hit_limit,
  count(*)                                                   as total_days_used_ai,
  round(avg(du.analysis_count), 1)                          as avg_daily_calls
from daily_usage du
join auth.users u on u.id = du.user_id
group by u.email
order by days_hit_limit desc;


-- ════════════════════════════════════════════════════════════
-- SECTION 10: HEALTH PARAMETERS ENTERED
-- How many users are giving us their health context?
-- ════════════════════════════════════════════════════════════

select
  count(*) filter (where health_hba1c   is not null)        as entered_hba1c,
  count(*) filter (where health_sugar   is not null)        as entered_fasting_sugar,
  count(*) filter (where health_chol    is not null)        as entered_cholesterol,
  count(*) filter (where health_bp_sys  is not null)        as entered_bp,
  count(*) filter (where health_hb      is not null)        as entered_haemoglobin,
  count(*) filter (where health_vitd    is not null)        as entered_vitamin_d,
  count(*) filter (where health_other   is not null)        as entered_other_notes,
  count(*) filter (where health_hba1c   is not null
                      or health_sugar   is not null
                      or health_chol    is not null)        as any_health_data,
  count(*)                                                   as total_onboarded_users
from profiles
where onboarded = true;


-- ════════════════════════════════════════════════════════════
-- SECTION 11: FEEDBACK RECEIVED
-- What are users telling you?
-- ════════════════════════════════════════════════════════════

select
  created_at::date                                           as date,
  feedback,
  topics,
  contact
from feedback
order by created_at desc;

-- Topic chip frequency
select
  topic_item,
  count(*)                                                   as times_selected
from feedback,
     json_array_elements_text(topics::json) as topic_item
where topics is not null
  and topics != '[]'
group by topic_item
order by times_selected desc;


-- ════════════════════════════════════════════════════════════
-- SECTION 12: QUICK WEEKLY SUMMARY
-- One query to paste every Monday morning
-- ════════════════════════════════════════════════════════════

select
  'This week (' || (current_date - 7)::text || ' to ' || current_date::text || ')' as period,

  (select count(distinct user_id) from food_log
   where date >= current_date - 7)                          as active_food_loggers,

  (select count(distinct user_id) from habits where done=true
   and date >= current_date - 7)                            as active_habit_checkers,

  (select count(distinct user_id) from daily_logs
   where date >= current_date - 7)                          as closed_their_day,

  (select count(*) from daily_usage
   where date >= current_date - 7)                          as ai_calls_made,

  (select count(*) from feedback
   where created_at >= current_date - 7)                    as feedback_received,

  (select count(*) from auth.users
   where created_at >= current_date - 7)                    as new_signups;
