-- Seed data for cohort_stats
-- Representative frequency counts to bootstrap cohort insights before real users contribute.
-- All values are plausible population distributions, not real user data.

-- ── Training segment ─────────────────────────────────────
INSERT INTO cohort_stats (segment, field_name, field_value, frequency) VALUES
  ('training', 'age_band', '18-24', 312),
  ('training', 'age_band', '25-34', 541),
  ('training', 'age_band', '35-44', 389),
  ('training', 'age_band', '45-54', 198),
  ('training', 'age_band', '55+',   87),

  ('training', 'gender_band', 'male',            742),
  ('training', 'gender_band', 'female',          711),
  ('training', 'gender_band', 'prefer_not_to_say', 74),

  ('training', 'bmi_band', 'under_18.5', 63),
  ('training', 'bmi_band', '18.5-24.9',  597),
  ('training', 'bmi_band', '25-29.9',    478),
  ('training', 'bmi_band', '30+',        389),

  ('training', 'active_weeks_band', '0',   112),
  ('training', 'active_weeks_band', '1-3', 398),
  ('training', 'active_weeks_band', '4+',  1017),

  ('training', 'program_phase', 'foundation', 423),
  ('training', 'program_phase', 'build',      612),
  ('training', 'program_phase', 'peak',       298),
  ('training', 'program_phase', 'recovery',   194),

  ('training', 'training_days_week_band', '1-2', 287),
  ('training', 'training_days_week_band', '3-4', 814),
  ('training', 'training_days_week_band', '5+',  426),

  ('training', 'avg_session_duration_band', 'under_30', 198),
  ('training', 'avg_session_duration_band', '30-45',    612),
  ('training', 'avg_session_duration_band', '46-60',    489),
  ('training', 'avg_session_duration_band', '60+',      228),

  ('training', 'primary_goal', 'weight_loss',  487),
  ('training', 'primary_goal', 'muscle_gain',  539),
  ('training', 'primary_goal', 'endurance',    312),
  ('training', 'primary_goal', 'maintenance',  189)
ON CONFLICT (segment, field_name, field_value) DO NOTHING;

-- ── Nutrition segment ────────────────────────────────────
INSERT INTO cohort_stats (segment, field_name, field_value, frequency) VALUES
  ('nutrition', 'caloric_balance_band', 'deficit_large',  198),
  ('nutrition', 'caloric_balance_band', 'deficit_small',  412),
  ('nutrition', 'caloric_balance_band', 'maintenance',    498),
  ('nutrition', 'caloric_balance_band', 'surplus_small',  312),
  ('nutrition', 'caloric_balance_band', 'surplus_large',  107),

  ('nutrition', 'protein_adequacy_band', 'below_target',  387),
  ('nutrition', 'protein_adequacy_band', 'at_target',     742),
  ('nutrition', 'protein_adequacy_band', 'above_target',  398),

  ('nutrition', 'meal_frequency_band', '1-2', 213),
  ('nutrition', 'meal_frequency_band', '3-4', 891),
  ('nutrition', 'meal_frequency_band', '5+',  423),

  ('nutrition', 'diet_pattern', 'standard',   987),
  ('nutrition', 'diet_pattern', 'vegetarian', 312),
  ('nutrition', 'diet_pattern', 'vegan',      187),
  ('nutrition', 'diet_pattern', 'keto',       198),
  ('nutrition', 'diet_pattern', 'other',      143)
ON CONFLICT (segment, field_name, field_value) DO NOTHING;

-- ── Recovery segment ─────────────────────────────────────
INSERT INTO cohort_stats (segment, field_name, field_value, frequency) VALUES
  ('recovery', 'sleep_duration_band', 'under_6', 287),
  ('recovery', 'sleep_duration_band', '6-7',     498),
  ('recovery', 'sleep_duration_band', '7-8',     712),
  ('recovery', 'sleep_duration_band', '8+',      312),

  ('recovery', 'sleep_quality_band', 'poor', 398),
  ('recovery', 'sleep_quality_band', 'fair', 712),
  ('recovery', 'sleep_quality_band', 'good', 699),

  ('recovery', 'resting_hr_band', 'under_60', 312),
  ('recovery', 'resting_hr_band', '60-70',    698),
  ('recovery', 'resting_hr_band', '71-80',    487),
  ('recovery', 'resting_hr_band', '81+',      112),

  ('recovery', 'stress_level_band', 'low',      398),
  ('recovery', 'stress_level_band', 'moderate', 812),
  ('recovery', 'stress_level_band', 'high',     399)
ON CONFLICT (segment, field_name, field_value) DO NOTHING;

-- ── Stats segment ────────────────────────────────────────
INSERT INTO cohort_stats (segment, field_name, field_value, frequency) VALUES
  ('stats', 'weekly_sessions_band', '0-1', 312),
  ('stats', 'weekly_sessions_band', '2-3', 698),
  ('stats', 'weekly_sessions_band', '4-5', 512),
  ('stats', 'weekly_sessions_band', '6+',  187),

  ('stats', 'total_active_minutes_band', 'under_150', 398),
  ('stats', 'total_active_minutes_band', '150-300',   712),
  ('stats', 'total_active_minutes_band', '300-450',   412),
  ('stats', 'total_active_minutes_band', '450+',      187),

  ('stats', 'steps_daily_band', 'under_5000',   298),
  ('stats', 'steps_daily_band', '5000-7500',    512),
  ('stats', 'steps_daily_band', '7500-10000',   612),
  ('stats', 'steps_daily_band', '10000+',       387),

  ('stats', 'workout_consistency_band', 'low',      398),
  ('stats', 'workout_consistency_band', 'moderate', 698),
  ('stats', 'workout_consistency_band', 'high',     513)
ON CONFLICT (segment, field_name, field_value) DO NOTHING;
