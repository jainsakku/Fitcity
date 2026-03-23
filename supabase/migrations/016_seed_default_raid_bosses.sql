with target_neighborhoods as (
  select id, name
  from public.neighborhoods
  where name in ('Gym Warriors Hub', 'Badminton Smash Circle')
),
seed_rows as (
  select
    tn.id as neighborhood_id,
    case
      when tn.name = 'Gym Warriors Hub' then 'Gym Marathon: Burn 1,000,000 kcal'
      else 'Badminton Blitz: Smash 200,000 Rally Points'
    end as title,
    case
      when tn.name = 'Gym Warriors Hub' then 'Community cut challenge: log training sessions and burn calories together.'
      else 'Win long rallies and stack points as a neighborhood team.'
    end as description,
    case
      when tn.name = 'Gym Warriors Hub' then 1000000::bigint
      else 200000::bigint
    end as target_value,
    case
      when tn.name = 'Gym Warriors Hub' then 'kcal'
      else 'points'
    end as unit,
    case
      when tn.name = 'Gym Warriors Hub' then 100
      else 80
    end as reward_status,
    case
      when tn.name = 'Gym Warriors Hub' then 25
      else 20
    end as reward_coins
  from target_neighborhoods tn
)
insert into public.raid_bosses (
  neighborhood_id,
  title,
  description,
  target_value,
  current_progress,
  unit,
  reward_status,
  reward_coins,
  starts_at,
  deadline,
  completed_at,
  is_active
)
select
  s.neighborhood_id,
  s.title,
  s.description,
  s.target_value,
  0,
  s.unit,
  s.reward_status,
  s.reward_coins,
  now(),
  now() + interval '14 days',
  null,
  true
from seed_rows s
where not exists (
  select 1
  from public.raid_bosses rb
  where rb.neighborhood_id = s.neighborhood_id
    and rb.title = s.title
    and rb.is_active = true
);
