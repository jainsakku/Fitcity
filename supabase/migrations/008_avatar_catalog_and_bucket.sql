insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('avatars-ai', 'avatars-ai', true, 5242880, array['image/png'])
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

create table if not exists public.avatar_catalog (
  id bigserial primary key,
  file_path text not null unique,
  public_url text not null,
  gender text not null check (gender in ('male', 'female', 'nb')),
  body_type text not null check (body_type in ('lean', 'athletic', 'buff')),
  skin_tone text not null check (skin_tone in ('fair', 'medium', 'tan', 'deep')),
  style text not null default 'realistic_fitness',
  source_model text not null default 'gemini-2.0-flash-preview-image-generation',
  created_at timestamptz not null default now()
);

create index if not exists idx_avatar_catalog_match
  on public.avatar_catalog (gender, body_type, skin_tone, created_at desc);

alter table public.avatar_catalog enable row level security;

drop policy if exists avatar_catalog_read on public.avatar_catalog;
create policy avatar_catalog_read
on public.avatar_catalog
for select
using (true);

drop policy if exists avatars_ai_public_read on storage.objects;
create policy avatars_ai_public_read
on storage.objects
for select
using (bucket_id = 'avatars-ai');
