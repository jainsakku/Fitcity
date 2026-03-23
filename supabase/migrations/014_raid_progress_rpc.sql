create or replace function public.contribute_to_active_raids(
  p_uid text,
  p_amount bigint,
  p_contributed_at timestamptz default now()
)
returns jsonb
language plpgsql
as $$
declare
  raid_row record;
  new_progress bigint;
  touched integer := 0;
begin
  if coalesce(p_amount, 0) <= 0 then
    return jsonb_build_object('updatedRaids', 0);
  end if;

  for raid_row in
    select rb.id, rb.current_progress, rb.target_value
    from public.raid_bosses rb
    join public.neighborhood_members nm on nm.neighborhood_id = rb.neighborhood_id
    where nm.user_id = p_uid
      and rb.is_active = true
      and rb.completed_at is null
      and rb.deadline > now()
  loop
    new_progress := least(raid_row.target_value, coalesce(raid_row.current_progress, 0) + p_amount);

    update public.raid_bosses
    set
      current_progress = new_progress,
      completed_at = case when new_progress >= target_value then coalesce(completed_at, p_contributed_at) else completed_at end,
      is_active = case when new_progress >= target_value then false else is_active end
    where id = raid_row.id;

    insert into public.raid_contributions (raid_id, user_id, amount, contributed_at)
    values (raid_row.id, p_uid, p_amount, p_contributed_at);

    touched := touched + 1;
  end loop;

  return jsonb_build_object('updatedRaids', touched);
end;
$$;