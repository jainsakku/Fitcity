-- Phase 4 comprehensive DB verification (safe: rolls back all test data)
-- Run:
--   psql "$SUPABASE_DB_URL" -f scripts/phase4_db_verification.sql
-- Or paste into Supabase SQL editor.

begin;

DO $$
DECLARE
  v_suffix text := replace(substr(gen_random_uuid()::text, 1, 8), '-', '');
  v_owner_uid text := 'phase4_owner_' || v_suffix;
  v_member_uid text := 'phase4_member_' || v_suffix;

  v_task_catalog_id text := 'phase4_task_' || v_suffix;
  v_shop_item_id text := 'phase4_shop_' || v_suffix;
  v_achievement_id text := 'phase4_ach_' || v_suffix;

  v_user_task_id uuid;
  v_neighborhood_id uuid;
  v_raid_id uuid;

  v_owner_coins_before integer;
  v_owner_coins_after_completion integer;
  v_owner_coins_after_purchase integer;

  v_raid_before bigint;
  v_raid_after bigint;

  v_member_count integer;
  v_exists integer;
  v_result jsonb;
BEGIN
  RAISE NOTICE 'Phase 4 DB verification started (suffix=%).', v_suffix;

  -- 0) Realtime publication prerequisites for live subscriptions
  SELECT count(*) INTO v_exists
  FROM pg_publication_tables
  WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'streaks';
  IF v_exists = 0 THEN
    RAISE EXCEPTION 'Realtime publication missing table: public.streaks';
  END IF;

  SELECT count(*) INTO v_exists
  FROM pg_publication_tables
  WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'raid_bosses';
  IF v_exists = 0 THEN
    RAISE EXCEPTION 'Realtime publication missing table: public.raid_bosses';
  END IF;

  SELECT count(*) INTO v_exists
  FROM pg_publication_tables
  WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'users';
  IF v_exists = 0 THEN
    RAISE EXCEPTION 'Realtime publication missing table: public.users';
  END IF;

  -- 1) Seed users
  INSERT INTO public.users (uid, name, title, status_total, coins, level, real_age, body_age, lifespan_added)
  VALUES
    (v_owner_uid, 'Phase4 Owner', 'Tester', 2000, 500, 12, 30, 30.0, 0),
    (v_member_uid, 'Phase4 Member', 'Tester', 800, 100, 5, 29, 29.0, 0);

  SELECT coins INTO v_owner_coins_before FROM public.users WHERE uid = v_owner_uid;

  -- 2) Seed catalog/task/streak
  INSERT INTO public.task_catalog (
    id, name, category, base_difficulty, duration_min,
    body_age_impact, disease_risk_heart, disease_risk_diabetes, disease_risk_stroke,
    lifespan_impact, calories_burned
  ) VALUES (
    v_task_catalog_id, 'Phase 4 Verification Workout', 'cardio', 4.0, 45,
    0.05, -0.20, -0.25, -0.15,
    0.01, 500
  );

  INSERT INTO public.user_tasks (user_id, task_catalog_id, frequency, is_active)
  VALUES (v_owner_uid, v_task_catalog_id, 5, true)
  RETURNING id INTO v_user_task_id;

  INSERT INTO public.streaks (
    user_id, user_task_id, count, longest_count, last_completed_date,
    grace_days_remaining, shield_active, is_broken
  ) VALUES (
    v_owner_uid, v_user_task_id, 2, 2, current_date - 1,
    3, false, false
  );

  -- 3) Achievement trigger fixture (unlock on first completion)
  INSERT INTO public.achievement_definitions (
    id, name, description, condition_type, condition_value, reward_status, reward_coins
  ) VALUES (
    v_achievement_id,
    'Phase4 Completion Achievement',
    'Unlock on first task completion in test',
    'task_completions',
    1,
    25,
    15
  );

  -- 4) Neighborhood + membership via Phase 4 RPCs
  SELECT public.found_neighborhood(
    v_owner_uid,
    'P4 Neighborhood ' || v_suffix,
    'Realtime test motto',
    'interest'
  ) INTO v_result;

  v_neighborhood_id := (v_result ->> 'neighborhoodId')::uuid;
  IF v_neighborhood_id IS NULL THEN
    RAISE EXCEPTION 'found_neighborhood did not return neighborhoodId';
  END IF;

  PERFORM public.join_neighborhood(v_member_uid, v_neighborhood_id);

  SELECT member_count INTO v_member_count
  FROM public.neighborhoods
  WHERE id = v_neighborhood_id;

  IF v_member_count <> 2 THEN
    RAISE EXCEPTION 'join_neighborhood/member_count mismatch. expected=2 got=%', v_member_count;
  END IF;

  -- 5) Active raid boss fixture
  INSERT INTO public.raid_bosses (
    neighborhood_id,
    title,
    description,
    target_value,
    current_progress,
    unit,
    reward_status,
    reward_coins,
    deadline,
    is_active
  ) VALUES (
    v_neighborhood_id,
    'Phase4 Raid Boss',
    'Verification raid',
    1000000,
    430000,
    'kcal',
    100,
    25,
    now() + interval '2 days',
    true
  ) RETURNING id, current_progress INTO v_raid_id, v_raid_before;

  -- 6) Core loop atomic completion (Phase 3->4 dependency)
  PERFORM public.process_task_completion(
    v_owner_uid,
    v_user_task_id,
    v_task_catalog_id,
    3,
    3,
    120,
    12,
    0.05,
    0.01,
    'auto',
    '{"steps":1200,"distanceKm":1.2}'::jsonb,
    1.2,
    current_date
  );

  SELECT count(*) INTO v_exists
  FROM public.task_completions
  WHERE user_id = v_owner_uid
    AND user_task_id = v_user_task_id
    AND completion_date = current_date;
  IF v_exists <> 1 THEN
    RAISE EXCEPTION 'task completion row missing after process_task_completion';
  END IF;

  SELECT count(*) INTO v_exists
  FROM public.streaks
  WHERE user_id = v_owner_uid
    AND user_task_id = v_user_task_id
    AND count = 3
    AND is_broken = false
    AND last_completed_date = current_date;
  IF v_exists <> 1 THEN
    RAISE EXCEPTION 'streak row not updated correctly by process_task_completion';
  END IF;

  SELECT coins INTO v_owner_coins_after_completion FROM public.users WHERE uid = v_owner_uid;
  IF v_owner_coins_after_completion <= v_owner_coins_before THEN
    RAISE EXCEPTION 'user coins did not increase after completion';
  END IF;

  -- 7) Achievement trigger verification
  SELECT count(*) INTO v_exists
  FROM public.user_achievements
  WHERE user_id = v_owner_uid AND achievement_id = v_achievement_id;
  IF v_exists <> 1 THEN
    RAISE EXCEPTION 'achievement was not unlocked by completion trigger';
  END IF;

  SELECT count(*) INTO v_exists
  FROM public.coin_transactions
  WHERE user_id = v_owner_uid
    AND type = 'achievement_reward'
    AND reference_id = v_achievement_id;
  IF v_exists <> 1 THEN
    RAISE EXCEPTION 'achievement reward coin transaction missing';
  END IF;

  -- 8) Raid contribution RPC verification (source of raid realtime updates)
  PERFORM public.contribute_to_active_raids(v_owner_uid, 500, now());

  SELECT current_progress INTO v_raid_after
  FROM public.raid_bosses
  WHERE id = v_raid_id;

  IF v_raid_after <> least(1000000, v_raid_before + 500) THEN
    RAISE EXCEPTION 'raid progress mismatch. expected=% got=%', least(1000000, v_raid_before + 500), v_raid_after;
  END IF;

  SELECT count(*) INTO v_exists
  FROM public.raid_contributions
  WHERE raid_id = v_raid_id AND user_id = v_owner_uid AND amount = 500;
  IF v_exists <> 1 THEN
    RAISE EXCEPTION 'raid contribution row missing';
  END IF;

  -- 9) Shop purchase RPC verification
  INSERT INTO public.shop_items (id, name, category, price, is_active, description)
  VALUES (v_shop_item_id, 'Phase4 Shop Item', 'building_skin', 90, true, 'Phase 4 verification item');

  PERFORM public.purchase_shop_item(v_owner_uid, v_shop_item_id);

  SELECT count(*) INTO v_exists
  FROM public.user_inventory
  WHERE user_id = v_owner_uid AND item_id = v_shop_item_id;
  IF v_exists <> 1 THEN
    RAISE EXCEPTION 'purchase_shop_item did not grant inventory item';
  END IF;

  SELECT coins INTO v_owner_coins_after_purchase FROM public.users WHERE uid = v_owner_uid;
  IF v_owner_coins_after_purchase <> (v_owner_coins_after_completion + 15 - 90) THEN
    -- +15 comes from achievement reward above, -90 from shop purchase.
    RAISE EXCEPTION 'final coin balance mismatch. expected=% got=%',
      (v_owner_coins_after_completion + 15 - 90),
      v_owner_coins_after_purchase;
  END IF;

  SELECT count(*) INTO v_exists
  FROM public.coin_transactions
  WHERE user_id = v_owner_uid
    AND type = 'purchase'
    AND reference_id = v_shop_item_id;
  IF v_exists <> 1 THEN
    RAISE EXCEPTION 'purchase coin transaction missing';
  END IF;

  RAISE NOTICE 'Phase 4 DB verification PASSED. All checks succeeded.';
END $$;

rollback;
