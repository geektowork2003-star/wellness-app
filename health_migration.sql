-- Run in Supabase SQL Editor

-- Health parameters on profiles table
alter table public.profiles
  add column if not exists health_sugar    decimal,
  add column if not exists health_chol     decimal,
  add column if not exists health_bp_sys   decimal,
  add column if not exists health_bp_dia   decimal,
  add column if not exists health_hba1c    decimal,
  add column if not exists health_trig     decimal,
  add column if not exists health_hb       decimal,
  add column if not exists health_vitd     decimal,
  add column if not exists health_vitb12   decimal,
  add column if not exists health_uric     decimal,
  add column if not exists health_other    text;

-- New fields on health_reports table
alter table public.health_reports
  add column if not exists haemoglobin  decimal,
  add column if not exists vitamin_d    decimal,
  add column if not exists vitamin_b12  decimal,
  add column if not exists uric_acid    decimal,
  add column if not exists other_notes  text;
