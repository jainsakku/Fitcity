create or replace view public.v_user_dashboard as
select
  ut.id as user_task_id,
  ut.user_id,
  ut.frequency,
  ut.effective_difficulty,
  ut.building_skin,
  tc.id as task_id,
  tc.name as task_name,
  tc.category,
  tc.emoji,
  tc.base_difficulty,
  tc.duration_min,
  tc.description,
  tc.body_age_impact,
  tc.disease_risk_heart,
  tc.disease_risk_diabetes,
  tc.disease_risk_stroke,
  tc.lifespan_impact,
  tc.calories_burned,
  tc.money_saved_daily,
  tc.energy_boost_pct,
  s.count as streak_count,
  s.longest_count,
  s.last_completed_date,
  s.is_broken,
  s.grace_days_remaining,
  s.shield_active,
  s.recovery_deadline,
  s.recovery_cost
from public.user_tasks ut
join public.task_catalog tc on tc.id = ut.task_catalog_id
left join public.streaks s on s.user_task_id = ut.id
where ut.is_active = true;

create or replace view public.v_city_buildings as
select
  u.uid as user_id,
  u.name as user_name,
  u.level as user_level,
  u.city_plot_x,
  u.city_plot_y,
  u.district_name,
  ut.id as user_task_id,
  tc.id as task_type,
  tc.name as task_name,
  tc.category,
  tc.emoji,
  tc.base_difficulty,
  ut.effective_difficulty,
  ut.building_skin,
  s.count as streak_count,
  s.longest_count,
  s.is_broken,
  s.last_completed_date,
  least(coalesce(s.count, 0) * 5, 500) as building_height,
  40 + (tc.base_difficulty::int * 10) as building_width,
  case
    when s.is_broken then 'cracked'
    when coalesce(s.count, 0) > 0 and s.count < 7 then 'construction'
    else 'complete'
  end as building_state
from public.users u
join public.user_tasks ut on ut.user_id = u.uid and ut.is_active = true
join public.task_catalog tc on tc.id = ut.task_catalog_id
left join public.streaks s on s.user_task_id = ut.id;
