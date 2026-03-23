create or replace function public.buy_streak_shield(
  p_uid text,
  p_user_task_id uuid,
  p_cost integer default 150
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
  set shield_active = true
  where user_id = p_uid and user_task_id = p_user_task_id and shield_active = false;

  if not found then
    raise exception 'Shield already active or streak not found';
  end if;

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
    'shield_purchase',
    p_user_task_id::text,
    'Purchased streak shield'
  );

  return jsonb_build_object('success', true, 'balance', new_balance);
end;
$$;
