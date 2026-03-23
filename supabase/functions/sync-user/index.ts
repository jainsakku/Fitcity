import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { getAuthUserId } from "../_shared/auth.ts";
import { failure, success } from "../_shared/response.ts";
import { getServiceClient } from "../_shared/supabase.ts";

function normalizeAvatarConfig(input: unknown, fallbackSeed: string) {
  const source = typeof input === "object" && input !== null
    ? input as Record<string, unknown>
    : {};

  const hairId = Number.isInteger(source.hair_id) ? Number(source.hair_id) : 1;
  const skinId = Number.isInteger(source.skin_id) ? Number(source.skin_id) : 1;
  const outfitId = Number.isInteger(source.outfit_id) ? Number(source.outfit_id) : 1;
  const gender = typeof source.gender === "string" && source.gender.trim().length > 0
    ? source.gender.trim()
    : "nb";
  const bodyType = typeof source.body_type === "string" && source.body_type.trim().length > 0
    ? source.body_type.trim()
    : "athletic";

  const existingAvatarUrl = typeof source.avatar_url === "string" ? source.avatar_url.trim() : "";
  const avatarUrl = existingAvatarUrl.length > 0
    ? existingAvatarUrl
    : `https://api.dicebear.com/9.x/personas/png?seed=${encodeURIComponent(fallbackSeed)}&backgroundType=gradientLinear`;

  const avatarSource = typeof source.avatar_source === "string" && source.avatar_source.trim().length > 0
    ? source.avatar_source.trim()
    : "dicebear_fallback";

  return {
    ...source,
    hair_id: hairId,
    skin_id: skinId,
    outfit_id: outfitId,
    gender,
    body_type: bodyType,
    avatar_url: avatarUrl,
    avatar_source: avatarSource,
  };
}

serve(async (req) => {
  try {
    const uid = await getAuthUserId(req);
    const body = await req.json().catch(() => ({}));
    const hasExplicitName = typeof body.name === "string" && body.name.trim().length > 0;
    const explicitName = hasExplicitName ? String(body.name).trim() : null;
    const normalizedExplicitName = explicitName && explicitName.length >= 3
      ? explicitName.substring(0, 20)
      : null;
    const explicitArchetype = typeof body.archetype === "string" ? body.archetype : null;
    const explicitAvatarConfig = typeof body.avatar_config === "object" && body.avatar_config !== null
      ? body.avatar_config
      : null;
    const explicitDistrictName = typeof body.district_name === "string" && body.district_name.trim().length > 0
      ? body.district_name.trim()
      : null;
    const explicitRealAge = Number.isInteger(body.real_age) && body.real_age >= 13 && body.real_age <= 100
      ? Number(body.real_age)
      : null;

    const supabase = getServiceClient();

    const { data: existing } = await supabase
      .from("users")
      .select("uid,name,archetype,avatar_config,city_plot_x,city_plot_y,district_name,real_age,body_age")
      .eq("uid", uid)
      .limit(1)
      .maybeSingle();

    const existingName = typeof existing?.name === "string" && existing.name.length > 0
      ? existing.name
      : null;
    const name = normalizedExplicitName ?? existingName ?? "FitCity User";

    const archetype = explicitArchetype ?? existing?.archetype ?? null;
    const avatarConfig = normalizeAvatarConfig(
      explicitAvatarConfig ?? existing?.avatar_config,
      `${uid}-${name}`,
    );
    const districtName = explicitDistrictName ?? existing?.district_name ?? `${name}'s District`;
    const realAge = explicitRealAge ?? existing?.real_age ?? null;
    const bodyAge = explicitRealAge ?? existing?.body_age ?? existing?.real_age ?? null;

    const { count } = await supabase
      .from("users")
      .select("uid", { count: "exact", head: true });

    const userCount = count ?? 0;
    const cityPlotX = Number.isInteger(body.city_plot_x)
      ? body.city_plot_x
      : (existing?.city_plot_x ?? userCount % 20);
    const cityPlotY = Number.isInteger(body.city_plot_y)
      ? body.city_plot_y
      : (existing?.city_plot_y ?? Math.floor(userCount / 20));

    const { data, error } = await supabase
      .from("users")
      .upsert(
        {
          uid,
          name,
          title: "Newcomer",
          archetype,
          avatar_config: avatarConfig,
          city_plot_x: cityPlotX,
          city_plot_y: cityPlotY,
          district_name: districtName,
          real_age: realAge,
          body_age: bodyAge,
        },
        { onConflict: "uid" },
      )
      .select("uid, name, title, archetype, city_plot_x, city_plot_y, district_name, real_age, body_age, created_at, updated_at")
      .single();

    if (error) {
      return failure(error.message, 400);
    }

    return success({ synced: true, user: data });
  } catch (error) {
    return failure(error instanceof Error ? error.message : "Unknown error", 500);
  }
});
