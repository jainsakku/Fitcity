alter table public.users enable row level security;
alter table public.user_tasks enable row level security;
alter table public.streaks enable row level security;
alter table public.task_completions enable row level security;
alter table public.user_inventory enable row level security;
alter table public.coin_transactions enable row level security;

-- users
drop policy if exists users_read on public.users;
create policy users_read on public.users
for select using (true);

drop policy if exists users_write on public.users;
create policy users_write on public.users
for update using (auth.uid()::text = uid);

-- user_tasks
drop policy if exists tasks_read on public.user_tasks;
create policy tasks_read on public.user_tasks
for select using (auth.uid()::text = user_id);

drop policy if exists tasks_insert on public.user_tasks;
create policy tasks_insert on public.user_tasks
for insert with check (auth.uid()::text = user_id);

-- streaks
drop policy if exists streaks_read on public.streaks;
create policy streaks_read on public.streaks
for select using (auth.uid()::text = user_id);

-- completions
drop policy if exists completions_read on public.task_completions;
create policy completions_read on public.task_completions
for select using (auth.uid()::text = user_id);

-- inventory + coin transactions
drop policy if exists inventory_read on public.user_inventory;
create policy inventory_read on public.user_inventory
for select using (auth.uid()::text = user_id);

drop policy if exists coins_read on public.coin_transactions;
create policy coins_read on public.coin_transactions
for select using (auth.uid()::text = user_id);
