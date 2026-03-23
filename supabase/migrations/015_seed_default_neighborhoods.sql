insert into public.neighborhoods (
  name,
  motto,
  type,
  theme,
  is_competitive,
  member_count,
  active_members,
  collective_hours
)
values
  (
    'Gym Warriors Hub',
    'Lift together, level up together.',
    'interest',
    'iron-core',
    true,
    0,
    0,
    0
  ),
  (
    'Badminton Smash Circle',
    'Fast feet, sharp smashes, shared wins.',
    'interest',
    'court-light',
    true,
    0,
    0,
    0
  )
on conflict (name) do update
set
  motto = excluded.motto,
  type = excluded.type,
  theme = excluded.theme,
  is_competitive = excluded.is_competitive;
