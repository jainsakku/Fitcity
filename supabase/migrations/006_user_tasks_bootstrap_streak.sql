create or replace function public.bootstrap_streak_for_user_task()
returns trigger
language plpgsql
as $$
begin
  insert into public.streaks (user_id, user_task_id)
  values (new.user_id, new.id)
  on conflict (user_id, user_task_id) do nothing;

  return new;
end;
$$;

drop trigger if exists trg_bootstrap_streak on public.user_tasks;
create trigger trg_bootstrap_streak
after insert on public.user_tasks
for each row execute function public.bootstrap_streak_for_user_task();
