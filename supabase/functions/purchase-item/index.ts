import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { getAuthUserId } from "../_shared/auth.ts";
import { failure, success } from "../_shared/response.ts";
import { getServiceClient } from "../_shared/supabase.ts";

serve(async (req) => {
  try {
    const uid = await getAuthUserId(req);
    const body = await req.json();

    if (!body.itemId) {
      return failure("itemId is required", 422);
    }

    const itemId = String(body.itemId);
    const supabase = getServiceClient();
    const { data, error } = await supabase.rpc("purchase_shop_item", {
      p_uid: uid,
      p_item_id: itemId,
    });

    if (error) {
      return failure(error.message, 400);
    }

    return success({ uid, itemId, ...(data as Record<string, unknown> | null) });
  } catch (error) {
    return failure(error instanceof Error ? error.message : "Unknown error", 500);
  }
});
