-- Run this in Supabase → SQL Editor → New Query → Run
-- Fixes corrupted profile values

-- Reset impossible weight values (anything over 300kg or under 30kg is wrong)
update public.profiles
set
  start_weight   = null,
  goal_weight    = null,
  calorie_target = 1650,
  onboarded      = false
where
  (start_weight > 300 or start_weight < 30 or goal_weight > 300 or goal_weight < 30)
  or (calorie_target > 4000 or calorie_target < 800);

-- Also reset anyone with no start_weight so they redo onboarding cleanly
update public.profiles
set onboarded = false
where onboarded is null or start_weight is null;

-- Show what's in your profile now
select id, display_name, preferred_name, start_weight, goal_weight,
       calorie_target, height_cm, onboarded
from public.profiles;
