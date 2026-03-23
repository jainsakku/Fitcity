create or replace function public.join_neighborhood(
  p_uid text,
  p_neighborhood_id uuid
)
returns jsonb
language plpgsql
as $$
declare
  n_type text;
  new_member_count integer;
begin
  select type into n_type
  from public.neighborhoods
  where id = p_neighborhood_id;

  if not found then
    raise exception 'Neighborhood not found';
  end if;

  insert into public.neighborhood_members (
    neighborhood_id,
    user_id,
    membership_type,
    role,
    status_in_neighborhood
  ) values (
    p_neighborhood_id,
    p_uid,
    n_type,
    'member',
    0
  );

  update public.neighborhoods
  set member_count = (
        select count(*)::int
        from public.neighborhood_members
        where neighborhood_id = p_neighborhood_id
      ),
      active_members = (
        select count(*)::int
        from public.neighborhood_members
        where neighborhood_id = p_neighborhood_id
      )
  where id = p_neighborhood_id
  returning member_count into new_member_count;

  return jsonb_build_object(
    'success', true,
    'neighborhoodId', p_neighborhood_id,
    'memberCount', coalesce(new_member_count, 0)
  );
end;
$$;

create or replace function public.found_neighborhood(
  p_uid text,
  p_name text,
  p_motto text default '',
  p_type text default 'interest'
)
returns jsonb
language plpgsql
as $$
declare
  u_level integer;
  u_status integer;
  new_id uuid;
begin
  if p_type not in ('geo', 'interest') then
    raise exception 'Invalid neighborhood type';
  end if;

  select level, coalesce(status_total, 0)
  into u_level, u_status
  from public.users
  where uid = p_uid;

  if not found then
    raise exception 'User not found';
  end if;

  if coalesce(u_level, 1) < 10 then
    raise exception 'Level 10 required to found a neighborhood';
  end if;

  insert into public.neighborhoods (
    name,
    motto,
    type,
    founder_uid,
    mayor_uid,
    member_count,
    active_members
  ) values (
    p_name,
    nullif(p_motto, ''),
    p_type,
    p_uid,
    p_uid,
    1,
    1
  )
  returning id into new_id;

  insert into public.neighborhood_members (
    neighborhood_id,
    user_id,
    membership_type,
    role,
    status_in_neighborhood
  ) values (
    new_id,
    p_uid,
    p_type,
    'founder',
    u_status
  );

  return jsonb_build_object(
    'success', true,
    'neighborhoodId', new_id,
    'name', p_name
  );
end;
$$;

create or replace function public.unlock_achievements_on_completion()
returns trigger
language plpgsql
as $$
declare
  def record;
  completion_count integer;
  new_balance integer;
  inserted_count integer;
begin
  for def in
    select id, reward_status, reward_coins, condition_type, condition_value
    from public.achievement_definitions
  loop
    if def.condition_type = 'streak_days' and coalesce(new.streak_at_completion, 0) >= coalesce(def.condition_value, 0) then
      insert into public.user_achievements (user_id, achievement_id)
      values (new.user_id, def.id)
      on conflict do nothing;

      get diagnostics inserted_count = row_count;

      if inserted_count > 0 then
        update public.users
        set status_total = status_total + coalesce(def.reward_status, 0),
            coins = coins + coalesce(def.reward_coins, 0)
        where uid = new.user_id
        returning coins into new_balance;

        if coalesce(def.reward_coins, 0) != 0 then
          insert into public.coin_transactions (
            user_id,
            amount,
            balance_after,
            type,
            reference_id,
            description
          ) values (
            new.user_id,
            coalesce(def.reward_coins, 0),
            coalesce(new_balance, 0),
            'achievement_reward',
            def.id,
            'Achievement unlocked: ' || def.id
          );
        end if;
      end if;
    end if;

    if def.condition_type = 'task_completions' then
      select count(*)::int
      into completion_count
      from public.task_completions
      where user_id = new.user_id;

      if completion_count >= coalesce(def.condition_value, 0) then
        insert into public.user_achievements (user_id, achievement_id)
        values (new.user_id, def.id)
        on conflict do nothing;

        get diagnostics inserted_count = row_count;

        if inserted_count > 0 then
          update public.users
          set status_total = status_total + coalesce(def.reward_status, 0),
              coins = coins + coalesce(def.reward_coins, 0)
          where uid = new.user_id
          returning coins into new_balance;

          if coalesce(def.reward_coins, 0) != 0 then
            insert into public.coin_transactions (
              user_id,
              amount,
              balance_after,
              type,
              reference_id,
              description
            ) values (
              new.user_id,
              coalesce(def.reward_coins, 0),
              coalesce(new_balance, 0),
              'achievement_reward',
              def.id,
              'Achievement unlocked: ' || def.id
            );
          end if;
        end if;
      end if;
    end if;
  end loop;

  return new;
end;
$$;

drop trigger if exists trg_unlock_achievements_on_completion on public.task_completions;
create trigger trg_unlock_achievements_on_completion
after insert on public.task_completions
for each row
execute function public.unlock_achievements_on_completion();
