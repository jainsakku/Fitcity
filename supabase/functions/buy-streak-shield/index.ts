import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { getAuthUserId } from "../_shared/auth.ts";
import { failure, success } from "../_shared/response.ts";
import { getServiceClient } from "../_shared/supabase.ts";

const SHIELD_COST = 150;

serve(async (req) => {
  try {
    const uid = await getAuthUserId(req);
    await req.json().catch(() => ({}));
    const supabase = getServiceClient();

    const { data: streakRows, error: streakError } = await supabase
      .from("streaks")
      .select("user_task_id,shield_active,count")
      .eq("user_id", uid)
      .gt("count", 0);

    if (streakError || !streakRows || streakRows.length === 0) {
      return failure(streakError?.message ?? "Streak not found", 404);
    }

    const alreadyActive = streakRows.some((row) => row.shield_active === true);
    if (alreadyActive) {
      return failure("Global shield is already active", 409);
    }

    const { data: rpcData, error: rpcError } = await supabase.rpc("buy_streak_shield", {
      p_uid: uid,
      p_user_task_id: null,
      p_cost: SHIELD_COST,
    });

    if (rpcError) {
      return failure(rpcError.message, 400);
    }

    const updatedBalance = Number((rpcData as { balance?: number } | null)?.balance ?? 0);
    const activatedCount = Number((rpcData as { activated_count?: number } | null)?.activated_count ?? 0);

    return success({
      uid,
      scope: "global",
      shieldActive: true,
      activatedCount,
      cost: SHIELD_COST,
      balance: updatedBalance,
    });
  } catch (error) {
    return failure(error instanceof Error ? error.message : "Unknown error", 500);
  }
});
