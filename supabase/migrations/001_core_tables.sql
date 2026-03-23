create extension if not exists pgcrypto;

create table if not exists public.users (
  uid text primary key,
  name text not null check (char_length(name) between 3 and 20),
  title text default 'Newcomer',
  archetype text check (archetype in ('fresh_start','serious','beast_mode','elite')),
  avatar_config jsonb default '{}'::jsonb,
  status_total integer default 0 check (status_total >= 0),
  coins integer default 0 check (coins >= 0),
  level integer default 1,
  body_age numeric(4,1),
  real_age integer,
  lifespan_added numeric(8,4) default 0,
  city_plot_x integer,
  city_plot_y integer,
  district_name text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index if not exists idx_users_status on public.users (status_total desc);
create index if not exists idx_users_city_plot on public.users (city_plot_x, city_plot_y);

create or replace function public.update_modified_column()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists users_updated_at on public.users;
create trigger users_updated_at
before update on public.users
for each row execute function public.update_modified_column();

create or replace function public.compute_level(status integer)
returns integer
language plpgsql
immutable
as $$
begin
  return case
    when status < 500 then 1
    when status < 1000 then 2
    when status < 2000 then 3
    when status < 3500 then 4
    when status < 5000 then 5
    when status < 7500 then 6
    when status < 10000 then 7
    when status < 12500 then 8
    when status < 15000 then 9
    when status < 20000 then 10
    when status < 30000 then 12
    when status < 50000 then 15
    when status < 100000 then 20
    when status < 250000 then 25
    else 30
  end;
end;
$$;

create or replace function public.sync_user_level()
returns trigger
language plpgsql
as $$
begin
  new.level := public.compute_level(new.status_total);
  return new;
end;
$$;

drop trigger if exists trg_sync_level on public.users;
create trigger trg_sync_level
before insert or update of status_total on public.users
for each row execute function public.sync_user_level();

create table if not exists public.task_catalog (
  id text primary key,
  name text not null,
  category text not null check (category in ('cardio','strength','wellness','sports')),
  emoji text,
  base_difficulty numeric(2,1) not null,
  duration_min integer,
  description text,
  body_age_impact numeric(4,2),
  disease_risk_heart numeric(4,2),
  disease_risk_diabetes numeric(4,2),
  disease_risk_stroke numeric(4,2),
  lifespan_impact numeric(6,4),
  calories_burned integer,
  money_saved_daily numeric(6,2),
  energy_boost_pct numeric(4,1)
);

create table if not exists public.user_tasks (
  id uuid primary key default gen_random_uuid(),
  user_id text not null references public.users(uid) on delete cascade,
  task_catalog_id text not null references public.task_catalog(id),
  frequency integer not null default 3 check (frequency between 1 and 7),
  frequency_multiplier numeric(3,2),
  effective_difficulty numeric(4,2),
  building_skin text default 'default',
  is_active boolean default true,
  created_at timestamptz default now()
);

create index if not exists idx_user_tasks_user on public.user_tasks (user_id) where is_active = true;

create or replace function public.compute_task_difficulty()
returns trigger
language plpgsql
as $$
declare
  base_diff numeric(2,1);
  freq_mult numeric(3,2);
begin
  select base_difficulty into base_diff from public.task_catalog where id = new.task_catalog_id;
  freq_mult := case new.frequency
    when 7 then 1.50
    when 6 then 1.40
    when 5 then 1.30
    when 4 then 1.10
    when 3 then 1.00
    when 2 then 0.85
    when 1 then 0.70
  end;
  new.frequency_multiplier := freq_mult;
  new.effective_difficulty := base_diff * freq_mult;
  return new;
end;
$$;

drop trigger if exists trg_compute_difficulty on public.user_tasks;
create trigger trg_compute_difficulty
before insert or update of frequency on public.user_tasks
for each row execute function public.compute_task_difficulty();

create table if not exists public.streaks (
  id uuid primary key default gen_random_uuid(),
  user_id text not null references public.users(uid) on delete cascade,
  user_task_id uuid not null references public.user_tasks(id) on delete cascade,
  count integer default 0,
  longest_count integer default 0,
  last_completed_date date,
  grace_days_remaining integer default 3,
  grace_days_reset_at date default (current_date + interval '90 days'),
  shield_active boolean default false,
  is_broken boolean default false,
  broken_at timestamptz,
  recovery_deadline timestamptz,
  recovery_cost integer,
  unique (user_id, user_task_id)
);

create index if not exists idx_streaks_broken on public.streaks (is_broken, recovery_deadline) where is_broken = true;

create table if not exists public.task_completions (
  id uuid primary key default gen_random_uuid(),
  user_id text not null references public.users(uid),
  user_task_id uuid not null references public.user_tasks(id),
  task_catalog_id text not null references public.task_catalog(id),
  completed_at timestamptz default now(),
  completion_date date default current_date,
  verification_type text default 'honor' check (verification_type in ('auto','photo','buddy','honor')),
  health_connect_data jsonb,
  streak_at_completion integer,
  streak_multiplier numeric(4,2),
  status_earned integer,
  coins_earned integer,
  body_age_impact numeric(4,2),
  lifespan_impact numeric(6,4),
  unique (user_id, user_task_id, completion_date)
);

create index if not exists idx_completions_user on public.task_completions (user_id, completion_date desc);

create table if not exists public.neighborhoods (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  motto text,
  type text check (type in ('geo','interest')),
  theme text,
  banner_url text,
  founder_uid text references public.users(uid),
  mayor_uid text references public.users(uid),
  member_count integer default 0,
  is_competitive boolean default false,
  collective_hours numeric(10,1) default 0,
  active_members integer default 0,
  created_at timestamptz default now()
);

create table if not exists public.neighborhood_members (
  neighborhood_id uuid not null references public.neighborhoods(id) on delete cascade,
  user_id text not null references public.users(uid) on delete cascade,
  membership_type text check (membership_type in ('geo','interest')),
  role text default 'member' check (role in ('member','mayor','founder')),
  status_in_neighborhood integer default 0,
  joined_at timestamptz default now(),
  primary key (neighborhood_id, user_id)
);

create or replace function public.check_dual_membership()
returns trigger
language plpgsql
as $$
declare
  existing_count integer;
  ntype text;
begin
  select type into ntype from public.neighborhoods where id = new.neighborhood_id;

  select count(*) into existing_count
  from public.neighborhood_members nm
  join public.neighborhoods n on n.id = nm.neighborhood_id
  where nm.user_id = new.user_id and n.type = ntype;

  if existing_count >= 1 then
    raise exception 'User already has a % neighborhood', ntype;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_dual_membership on public.neighborhood_members;
create trigger trg_dual_membership
before insert on public.neighborhood_members
for each row execute function public.check_dual_membership();

create table if not exists public.raid_bosses (
  id uuid primary key default gen_random_uuid(),
  neighborhood_id uuid not null references public.neighborhoods(id) on delete cascade,
  title text not null,
  description text,
  target_value bigint not null,
  current_progress bigint default 0,
  unit text default 'kcal',
  reward_status integer default 10,
  reward_coins integer default 5,
  starts_at timestamptz default now(),
  deadline timestamptz not null,
  completed_at timestamptz,
  is_active boolean default true
);

create table if not exists public.raid_contributions (
  raid_id uuid references public.raid_bosses(id),
  user_id text references public.users(uid),
  amount bigint not null,
  contributed_at timestamptz default now()
);

create table if not exists public.shop_items (
  id text primary key,
  name text not null,
  category text check (category in ('building_skin','color','effect','character','booster')),
  price integer not null check (price > 0),
  description text,
  preview_url text,
  is_active boolean default true
);

create table if not exists public.user_inventory (
  user_id text not null references public.users(uid) on delete cascade,
  item_id text not null references public.shop_items(id),
  purchased_at timestamptz default now(),
  primary key (user_id, item_id)
);

create table if not exists public.coin_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id text not null references public.users(uid),
  amount integer not null,
  balance_after integer not null,
  type text not null,
  reference_id text,
  description text,
  created_at timestamptz default now()
);

create index if not exists idx_coin_tx_user on public.coin_transactions (user_id, created_at desc);

create table if not exists public.achievement_definitions (
  id text primary key,
  name text not null,
  description text,
  icon_url text,
  condition_type text,
  condition_value integer,
  reward_status integer default 0,
  reward_coins integer default 0
);

create table if not exists public.user_achievements (
  user_id text not null references public.users(uid) on delete cascade,
  achievement_id text not null references public.achievement_definitions(id),
  unlocked_at timestamptz default now(),
  primary key (user_id, achievement_id)
);

create table if not exists public.push_tokens (
  user_id text not null references public.users(uid) on delete cascade,
  token text not null,
  platform text check (platform in ('android','ios')),
  updated_at timestamptz default now(),
  primary key (user_id, token)
);
