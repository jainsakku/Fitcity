create or replace function public.process_task_completion(
  p_uid text,
  p_user_task_id uuid,
  p_task_catalog_id text,
  p_streak_count integer,
  p_longest_streak integer,
  p_status_earned integer,
  p_coins_earned integer,
  p_body_age_impact numeric,
  p_lifespan_impact numeric,
  p_verification_type text,
  p_health_connect_data jsonb,
  p_streak_multiplier numeric,
  p_completion_date date
)
returns jsonb
language plpgsql
as $$
declare
  new_coins integer;
begin
  insert into public.task_completions (
    user_id,
    user_task_id,
    task_catalog_id,
    completion_date,
    verification_type,
    health_connect_data,
    streak_at_completion,
    streak_multiplier,
    status_earned,
    coins_earned,
    body_age_impact,
    lifespan_impact
  ) values (
    p_uid,
    p_user_task_id,
    p_task_catalog_id,
    p_completion_date,
    p_verification_type,
    p_health_connect_data,
    p_streak_count,
    p_streak_multiplier,
    p_status_earned,
    p_coins_earned,
    p_body_age_impact,
    p_lifespan_impact
  );

  update public.streaks
  set count = p_streak_count,
      longest_count = greatest(longest_count, p_longest_streak),
      last_completed_date = p_completion_date,
      is_broken = false,
      broken_at = null,
      recovery_deadline = null,
      recovery_cost = null
  where user_id = p_uid and user_task_id = p_user_task_id;

  update public.users
  set status_total = status_total + p_status_earned,
      coins = coins + p_coins_earned,
      body_age = greatest(coalesce(body_age, coalesce(real_age, 30)::numeric) - p_body_age_impact, coalesce(real_age, 30) - 15),
      lifespan_added = coalesce(lifespan_added, 0) + p_lifespan_impact
  where uid = p_uid
  returning coins into new_coins;

  insert into public.coin_transactions (
    user_id,
    amount,
    balance_after,
    type,
    description
  ) values (
    p_uid,
    p_coins_earned,
    new_coins,
    'task_completion',
    'Earned from ' || p_task_catalog_id
  );

  return jsonb_build_object('new_coins', new_coins);
end;
$$;

create or replace function public.recover_streak(
  p_uid text,
  p_user_task_id uuid,
  p_cost integer
)
returns jsonb
language plpgsql
as $$
declare
  new_balance integer;
begin
  update public.users
  set coins = coins - p_cost
  where uid = p_uid and coins >= p_cost
  returning coins into new_balance;

  if not found then
    raise exception 'Insufficient coins';
  end if;

  update public.streaks
  set is_broken = false,
      broken_at = null,
      recovery_deadline = null,
      recovery_cost = null
  where user_id = p_uid and user_task_id = p_user_task_id;

  insert into public.coin_transactions (
    user_id,
    amount,
    balance_after,
    type,
    reference_id,
    description
  ) values (
    p_uid,
    -p_cost,
    new_balance,
    'streak_recovery',
    p_user_task_id::text,
    'Recovered streak'
  );

  return jsonb_build_object('success', true, 'balance', new_balance);
end;
$$;

create or replace function public.purchase_shop_item(
  p_uid text,
  p_item_id text
)
returns jsonb
language plpgsql
as $$
declare
  item_price integer;
  user_balance integer;
begin
  select price into item_price
  from public.shop_items
  where id = p_item_id and is_active = true;

  if not found then
    raise exception 'Item not found';
  end if;

  if exists (
    select 1 from public.user_inventory
    where user_id = p_uid and item_id = p_item_id
  ) then
    raise exception 'Already owned';
  end if;

  update public.users
  set coins = coins - item_price
  where uid = p_uid and coins >= item_price
  returning coins into user_balance;

  if not found then
    raise exception 'Insufficient coins';
  end if;

  insert into public.user_inventory (user_id, item_id)
  values (p_uid, p_item_id);

  insert into public.coin_transactions (
    user_id,
    amount,
    balance_after,
    type,
    reference_id,
    description
  ) values (
    p_uid,
    -item_price,
    user_balance,
    'purchase',
    p_item_id,
    'Purchased ' || p_item_id
  );

  return jsonb_build_object('success', true, 'balance', user_balance);
end;
$$;
