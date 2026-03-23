import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { getAuthUserId } from "../_shared/auth.ts";
import { failure, success } from "../_shared/response.ts";
import { getServiceClient } from "../_shared/supabase.ts";

serve(async (req) => {
  try {
    const uid = await getAuthUserId(req);
    const body = await req.json();

    if (!body.name) {
      return failure("name is required", 422);
    }

    const name = String(body.name).trim();
    const motto = typeof body.motto === "string" ? body.motto.trim() : "";
    const type = typeof body.type === "string" ? body.type : "interest";

    const supabase = getServiceClient();
    const { data, error } = await supabase.rpc("found_neighborhood", {
      p_uid: uid,
      p_name: name,
      p_motto: motto,
      p_type: type,
    });

    if (error) {
      return failure(error.message, 400);
    }

    return success({ uid, ...(data as Record<string, unknown> | null) });
  } catch (error) {
    return failure(error instanceof Error ? error.message : "Unknown error", 500);
  }
});
