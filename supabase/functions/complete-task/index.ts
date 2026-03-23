import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { getAuthUserId } from "../_shared/auth.ts";
import { failure, success } from "../_shared/response.ts";
import { getServiceClient } from "../_shared/supabase.ts";

function verificationWeight(type: string): number {
  switch (type) {
    case "auto":
      return 1.0;
    case "photo":
      return 0.95;
    case "buddy":
      return 0.9;
    default:
      return 0.8;
  }
}

function streakMultiplier(streakCount: number): number {
  if (streakCount >= 30) return 2.0;
  if (streakCount >= 14) return 1.7;
  if (streakCount >= 7) return 1.4;
  if (streakCount >= 3) return 1.2;
  return 1.0;
}

function healthMessage(bodyAgeImpact: number, lifespanImpact: number): string {
  if (bodyAgeImpact >= 0.08) {
    return "Excellent consistency. Your body age trend is improving quickly.";
  }
  if (lifespanImpact >= 0.02) {
    return "Strong session. You added meaningful long-term health value.";
  }
  return "Nice work. Small daily wins compound into major health gains.";
}

serve(async (req) => {
  try {
    const uid = await getAuthUserId(req);
    const body = await req.json();

    if (!body.userTaskId) {
      return failure("userTaskId is required", 422);
    }

    const userTaskId = String(body.userTaskId);
    const completionDate = new Date().toISOString().slice(0, 10);
    const verificationType = typeof body.verificationType === "string" ? body.verificationType : "honor";
    const healthConnectData = typeof body.healthConnectData === "object" && body.healthConnectData !== null
      ? body.healthConnectData
      : null;

    const supabase = getServiceClient();

    const { data: dashboard, error: dashboardError } = await supabase
      .from("v_user_dashboard")
      .select("user_task_id,task_id,task_name,effective_difficulty,streak_count,longest_count,last_completed_date,body_age_impact,lifespan_impact,calories_burned")
      .eq("user_id", uid)
      .eq("user_task_id", userTaskId)
      .limit(1)
      .single();

    if (dashboardError || !dashboard) {
      return failure(dashboardError?.message ?? "Task not found for this user", 404);
    }

    const { data: existing } = await supabase
      .from("task_completions")
      .select("id")
      .eq("user_id", uid)
      .eq("user_task_id", userTaskId)
      .eq("completion_date", completionDate)
      .limit(1);

    if (existing && existing.length > 0) {
      return failure("Task already completed today", 409);
    }

    const lastCompleted = dashboard.last_completed_date
      ? new Date(`${dashboard.last_completed_date}T00:00:00.000Z`)
      : null;
    const today = new Date(`${completionDate}T00:00:00.000Z`);
    const yesterday = new Date(today);
    yesterday.setUTCDate(yesterday.getUTCDate() - 1);

    const currentStreak = Number(dashboard.streak_count ?? 0);
    const nextStreak = lastCompleted && lastCompleted.toISOString().slice(0, 10) === yesterday.toISOString().slice(0, 10)
      ? currentStreak + 1
      : 1;
    const longest = Math.max(nextStreak, Number(dashboard.longest_count ?? 0));

    const effectiveDifficulty = Number(dashboard.effective_difficulty ?? 3);
    const streakMult = streakMultiplier(nextStreak);
    const verifyWeight = verificationWeight(verificationType);
    const statusEarned = Math.round(10 * effectiveDifficulty * streakMult * verifyWeight);
    const coinsEarned = Math.max(1, Math.round(statusEarned / 10));
    const bodyAgeImpact = Number(dashboard.body_age_impact ?? 0.05);
    const lifespanImpact = Number(dashboard.lifespan_impact ?? 0.01);
    const caloriesBurned = Number(dashboard.calories_burned ?? 0);

    const { data: rpcData, error: rpcError } = await supabase.rpc("process_task_completion", {
      p_uid: uid,
      p_user_task_id: userTaskId,
      p_task_catalog_id: dashboard.task_id,
      p_streak_count: nextStreak,
      p_longest_streak: longest,
      p_status_earned: statusEarned,
      p_coins_earned: coinsEarned,
      p_body_age_impact: bodyAgeImpact,
      p_lifespan_impact: lifespanImpact,
      p_verification_type: verificationType,
      p_health_connect_data: healthConnectData,
      p_streak_multiplier: streakMult,
      p_completion_date: completionDate,
    });

    if (rpcError) {
      return failure(rpcError.message, 400);
    }

    if (caloriesBurned > 0) {
      // Raid contribution should not block primary completion flow.
      await supabase.rpc("contribute_to_active_raids", {
        p_uid: uid,
        p_amount: Math.round(caloriesBurned),
      });
    }

    const newCoins = Number((rpcData as { new_coins?: number } | null)?.new_coins ?? 0);

    return success({
      uid,
      userTaskId,
      taskName: dashboard.task_name,
      streakCount: nextStreak,
      statusEarned,
      coinsEarned,
      newCoins,
      bodyAgeImpact,
      lifespanImpact,
      healthMessage: healthMessage(bodyAgeImpact, lifespanImpact),
      completionDate,
    });
  } catch (error) {
    return failure(error instanceof Error ? error.message : "Unknown error", 500);
  }
});
