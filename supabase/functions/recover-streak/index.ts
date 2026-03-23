import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { getAuthUserId } from "../_shared/auth.ts";
import { failure, success } from "../_shared/response.ts";
import { getServiceClient } from "../_shared/supabase.ts";

serve(async (req) => {
  try {
    const uid = await getAuthUserId(req);
    const body = await req.json();

    if (!body.userTaskId) {
      return failure("userTaskId is required", 422);
    }

    const userTaskId = String(body.userTaskId);
    const supabase = getServiceClient();

    const { data: streak, error: streakError } = await supabase
      .from("streaks")
      .select("user_task_id,is_broken,recovery_deadline,recovery_cost")
      .eq("user_id", uid)
      .eq("user_task_id", userTaskId)
      .limit(1)
      .single();

    if (streakError || !streak) {
      return failure(streakError?.message ?? "Streak not found", 404);
    }

    if (!streak.is_broken) {
      return failure("Streak is not broken", 409);
    }

    const deadline = streak.recovery_deadline ? new Date(String(streak.recovery_deadline)) : null;
    if (deadline && deadline.getTime() < Date.now()) {
      return failure("Recovery window has expired", 410);
    }

    const cost = Number(streak.recovery_cost ?? 150);

    const { data: rpcData, error: rpcError } = await supabase.rpc("recover_streak", {
      p_uid: uid,
      p_user_task_id: userTaskId,
      p_cost: cost,
    });

    if (rpcError) {
      return failure(rpcError.message, 400);
    }

    const balance = Number((rpcData as { balance?: number } | null)?.balance ?? 0);

    return success({
      uid,
      userTaskId,
      recovered: true,
      cost,
      balance,
    });
  } catch (error) {
    return failure(error instanceof Error ? error.message : "Unknown error", 500);
  }
});
