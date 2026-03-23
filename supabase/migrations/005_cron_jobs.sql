create extension if not exists pg_cron;

do $$
begin
  perform cron.unschedule(jobid)
  from cron.job
  where jobname = 'midnight-streak-check';
exception
  when others then null;
end $$;

select cron.schedule('midnight-streak-check', '5 0 * * *', $$
  update public.streaks
  set grace_days_remaining = case when grace_days_remaining > 0 then grace_days_remaining - 1 else 0 end,
      is_broken = case when grace_days_remaining <= 0 and not shield_active then true else false end,
      broken_at = case when grace_days_remaining <= 0 and not shield_active then now() else null end,
      recovery_deadline = case when grace_days_remaining <= 0 and not shield_active then now() + interval '48 hours' else null end,
      recovery_cost = case when grace_days_remaining <= 0 and not shield_active then
        case
          when count between 1 and 7 then 50
          when count between 8 and 30 then 150
          when count between 31 and 90 then 300
          when count between 91 and 365 then 500
          else 1000
        end
      else null end,
      shield_active = case when grace_days_remaining <= 0 and shield_active then false else shield_active end
  where last_completed_date < current_date - 1 and is_broken = false and count > 0;
$$);

do $$
begin
  perform cron.unschedule(jobid)
  from cron.job
  where jobname = 'expire-broken-streaks';
exception
  when others then null;
end $$;

select cron.schedule('expire-broken-streaks', '*/15 * * * *', $$
  update public.streaks
  set count = 0,
      is_broken = false,
      broken_at = null,
      recovery_deadline = null,
      recovery_cost = null
  where is_broken = true and recovery_deadline < now();
$$);

do $$
begin
  perform cron.unschedule(jobid)
  from cron.job
  where jobname = 'quarterly-grace-reset';
exception
  when others then null;
end $$;

select cron.schedule('quarterly-grace-reset', '0 0 1 1,4,7,10 *', $$
  update public.streaks
  set grace_days_remaining = 3,
      grace_days_reset_at = current_date + interval '90 days';
$$);

do $$
begin
  perform cron.unschedule(jobid)
  from cron.job
  where jobname = 'monthly-mayor-rotation';
exception
  when others then null;
end $$;

select cron.schedule('monthly-mayor-rotation', '0 0 1 * *', $$
  update public.neighborhoods n
  set mayor_uid = (
    select nm.user_id
    from public.neighborhood_members nm
    join public.users u on u.uid = nm.user_id
    where nm.neighborhood_id = n.id
    order by nm.status_in_neighborhood desc
    limit 1
  );
$$);
