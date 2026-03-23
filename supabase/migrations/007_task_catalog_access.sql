grant usage on schema public to anon, authenticated;
grant select on table public.task_catalog to anon, authenticated;

alter table public.task_catalog enable row level security;

drop policy if exists task_catalog_read on public.task_catalog;
create policy task_catalog_read
on public.task_catalog
for select
using (true);
