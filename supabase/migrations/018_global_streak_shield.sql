create or replace function public.buy_streak_shield(
  p_uid text,
  p_user_task_id uuid default null,
  p_cost integer default 150
)
returns jsonb
language plpgsql
as $$
declare
  new_balance integer;
  activated_count integer;
begin
  update public.users
  set coins = coins - p_cost
  where uid = p_uid and coins >= p_cost
  returning coins into new_balance;

  if not found then
    raise exception 'Insufficient coins';
  end if;

  update public.streaks
  set
    shield_active = true
  where user_id = p_uid
    and count > 0
    and shield_active = false;

  get diagnostics activated_count = row_count;

  if activated_count = 0 then
    raise exception 'Shield already active or no active streak found';
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
    coalesce(p_user_task_id::text, 'all'),
    'Purchased global streak shield'
  );

  return jsonb_build_object('success', true, 'balance', new_balance, 'activated_count', activated_count);
end;
$$;

create or replace function public.process_missed_streaks_global_shield()
returns void
language plpgsql
as $$
begin
  with candidates as (
    select s.id, s.user_id, s.count, s.grace_days_remaining, s.shield_active
    from public.streaks s
    where s.last_completed_date < current_date - 1
      and s.is_broken = false
      and s.count > 0
  ),
  shield_trigger_users as (
    select distinct c.user_id
    from candidates c
    where c.grace_days_remaining <= 0
      and c.shield_active = true
  ),
  saved_rows as (
    select distinct on (c.user_id) c.id, c.user_id
    from candidates c
    join shield_trigger_users u on u.user_id = c.user_id
    where c.grace_days_remaining <= 0
      and c.shield_active = true
    order by c.user_id, c.count desc, c.id
  )
  update public.streaks s
  set
    grace_days_remaining = case
      when s.grace_days_remaining > 0 then s.grace_days_remaining - 1
      else 0
    end,
    is_broken = case
      when s.grace_days_remaining <= 0
        and s.shield_active
        and exists (select 1 from saved_rows sr where sr.id = s.id) then false
      when s.grace_days_remaining <= 0 then true
      else false
    end,
    broken_at = case
      when s.grace_days_remaining <= 0
        and s.shield_active
        and exists (select 1 from saved_rows sr where sr.id = s.id) then null
      when s.grace_days_remaining <= 0 then now()
      else null
    end,
    recovery_deadline = case
      when s.grace_days_remaining <= 0
        and s.shield_active
        and exists (select 1 from saved_rows sr where sr.id = s.id) then null
      when s.grace_days_remaining <= 0 then now() + interval '48 hours'
      else null
    end,
    recovery_cost = case
      when s.grace_days_remaining <= 0
        and s.shield_active
        and exists (select 1 from saved_rows sr where sr.id = s.id) then null
      when s.grace_days_remaining <= 0 then
        case
          when s.count between 1 and 7 then 50
          when s.count between 8 and 30 then 150
          when s.count between 31 and 90 then 300
          when s.count between 91 and 365 then 500
          else 1000
        end
      else null
    end,
    shield_active = case
      when s.user_id in (select user_id from shield_trigger_users) then false
      else s.shield_active
    end
  where s.last_completed_date < current_date - 1
    and s.is_broken = false
    and s.count > 0;
end;
$$;

do $$
begin
  perform cron.unschedule(jobid)
  from cron.job
  where jobname = 'midnight-streak-check';
exception
  when others then null;
end $$;

select cron.schedule('midnight-streak-check', '5 0 * * *', $$
  select public.process_missed_streaks_global_shield();
$$);
