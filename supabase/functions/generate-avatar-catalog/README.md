# generate-avatar-catalog

One-time admin function to generate avatar images with Gemini and upload them to Supabase Storage.

## Required environment variables

- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `GEMINI_API_KEY`
- `FITCITY_ADMIN_KEY`
- Optional: `GEMINI_IMAGE_MODEL` (if omitted, function auto-discovers supported models)

## Run migration first

Apply `supabase/migrations/008_avatar_catalog_and_bucket.sql`.

## Deploy function

```bash
supabase functions deploy generate-avatar-catalog \
  --project-ref iuynqrakwrmfyehrpeqx
```

## Set/update secrets

```bash
supabase secrets set \
  GEMINI_API_KEY=YOUR_GEMINI_API_KEY \
  FITCITY_ADMIN_KEY=YOUR_ADMIN_KEY \
  --project-ref iuynqrakwrmfyehrpeqx
```

## Invoke once for 100 images

```bash
curl -X POST "$SUPABASE_URL/functions/v1/generate-avatar-catalog" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
  -H "x-fitcity-admin-key: $FITCITY_ADMIN_KEY" \
  -d '{"count":100}'
```

## Output

The response contains:
- `created_count`
- `failed_count`
- `batch_id`
- list of `created` rows (with `public_url`)
- list of failures

Stored assets:
- Storage bucket: `avatars-ai`
- Metadata table: `public.avatar_catalog`
