create or replace function public.streak_recovery_cost_for_count(p_count integer)
returns integer
language plpgsql
immutable
as $$
begin
  return case
    when coalesce(p_count, 0) <= 7 then 50
    when p_count <= 30 then 150
    when p_count <= 90 then 300
    when p_count <= 365 then 500
    else 1000
  end;
end;
$$;

create or replace function public.enforce_broken_streak_metadata()
returns trigger
language plpgsql
as $$
begin
  if new.is_broken then
    if new.broken_at is null then
      new.broken_at := now();
    end if;

    if new.recovery_deadline is null then
      new.recovery_deadline := new.broken_at + interval '48 hours';
    end if;

    if new.recovery_cost is null then
      new.recovery_cost := public.streak_recovery_cost_for_count(new.count);
    end if;
  else
    new.broken_at := null;
    new.recovery_deadline := null;
    new.recovery_cost := null;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_enforce_broken_streak_metadata on public.streaks;
create trigger trg_enforce_broken_streak_metadata
before insert or update of is_broken, count, broken_at, recovery_deadline, recovery_cost
on public.streaks
for each row execute function public.enforce_broken_streak_metadata();

update public.streaks
set
  broken_at = coalesce(broken_at, now()),
  recovery_deadline = coalesce(recovery_deadline, coalesce(broken_at, now()) + interval '48 hours'),
  recovery_cost = coalesce(recovery_cost, public.streak_recovery_cost_for_count(count))
where is_broken = true
  and (broken_at is null or recovery_deadline is null or recovery_cost is null);
