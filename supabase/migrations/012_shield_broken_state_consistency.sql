create or replace function public.enforce_broken_streak_metadata()
returns trigger
language plpgsql
as $$
begin
  -- Decision-tree invariant: shielded streak cannot be in broken state.
  if new.shield_active and new.is_broken then
    new.is_broken := false;
  end if;

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

-- Backfill any inconsistent rows from older logic.
update public.streaks
set
  is_broken = false,
  broken_at = null,
  recovery_deadline = null,
  recovery_cost = null
where shield_active = true
  and is_broken = true;
