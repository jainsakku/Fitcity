insert into public.task_catalog (
  id, name, category, emoji, base_difficulty, duration_min, description,
  body_age_impact, disease_risk_heart, disease_risk_diabetes, disease_risk_stroke,
  lifespan_impact, calories_burned, money_saved_daily, energy_boost_pct
) values
  ('walk_5k', 'Walk 5K Steps', 'cardio', 'WALK', 2.0, 45, 'Daily walking target', 0.05, 0.10, 0.08, 0.06, 0.0040, 220, 8.00, 5.0),
  ('gym_1hr', 'Gym Workout 1hr', 'strength', 'GYM', 4.0, 60, 'Strength training session', 0.10, 0.12, 0.09, 0.05, 0.0060, 420, 14.00, 7.0),
  ('meditate_15', 'Meditation 15min', 'wellness', 'ZEN', 1.5, 15, 'Guided mindful session', 0.03, 0.04, 0.03, 0.02, 0.0020, 40, 3.00, 4.0),
  ('sports_2hr', 'Outdoor Sports 2hr', 'sports', 'BALL', 4.5, 120, 'Match or training outdoors', 0.12, 0.16, 0.12, 0.08, 0.0080, 700, 18.00, 9.0)
on conflict (id) do nothing;

insert into public.shop_items (id, name, category, price, description, is_active) values
  ('skin_neon_core', 'Neon Core Skin', 'building_skin', 120, 'Cyberpunk skin for skyline towers', true),
  ('fx_teal_bloom', 'Teal Bloom Effect', 'effect', 180, 'Neon bloom particle effect', true),
  ('char_hoodie_x', 'Hoodie X Outfit', 'character', 140, 'Streetwear avatar outfit', true),
  ('booster_streak_shield', 'Streak Shield', 'booster', 150, 'Protect one missed day', true)
on conflict (id) do nothing;

insert into public.achievement_definitions (
  id, name, description, condition_type, condition_value, reward_status, reward_coins
) values
  ('streak_7', 'Week Warrior', 'Reach a 7-day streak', 'streak_days', 7, 100, 50),
  ('streak_30', 'Monthly Machine', 'Reach a 30-day streak', 'streak_days', 30, 500, 200),
  ('tasks_50', 'Consistency Champ', 'Complete 50 tasks', 'task_completions', 50, 300, 150)
on conflict (id) do nothing;
