alter table public.users
add column if not exists onboarding_completed boolean not null default false;

update public.users u
set onboarding_completed = true
where u.onboarding_completed = false
  and u.archetype is not null
  and exists (
    select 1
    from public.user_tasks ut
    where ut.user_id = u.uid
      and ut.is_active = true
  );
