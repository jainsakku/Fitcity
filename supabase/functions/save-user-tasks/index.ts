import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { getAuthUserId } from "../_shared/auth.ts";
import { failure, success } from "../_shared/response.ts";
import { getServiceClient } from "../_shared/supabase.ts";

serve(async (req) => {
  try {
    const uid = await getAuthUserId(req);
    const body = await req.json().catch(() => ({}));
    const tasks = Array.isArray(body.tasks) ? body.tasks : [];

    if (tasks.length < 3 || tasks.length > 6) {
      return failure("tasks must contain 3 to 6 items", 422);
    }

    const supabase = getServiceClient();

    await supabase.from("user_tasks").delete().eq("user_id", uid);

    for (const task of tasks) {
      const taskCatalogId = task.task_catalog_id;
      const frequency = Number(task.frequency ?? 3);

      if (typeof taskCatalogId !== "string") {
        return failure("task_catalog_id must be a string", 422);
      }

      const { data: inserted, error: insertError } = await supabase
        .from("user_tasks")
        .insert({
          user_id: uid,
          task_catalog_id: taskCatalogId,
          frequency: Math.min(7, Math.max(1, frequency)),
        })
        .select("id")
        .single();

      if (insertError) {
        return failure(insertError.message, 400);
      }

      // Keep behavior stable even if trigger migration has not been applied yet.
      await supabase.from("streaks").upsert({
        user_id: uid,
        user_task_id: inserted.id,
      });
    }

    await supabase
      .from("users")
      .update({ onboarding_completed: true })
      .eq("uid", uid);

    return success({ saved: true, count: tasks.length });
  } catch (error) {
    return failure(error instanceof Error ? error.message : "Unknown error", 500);
  }
});
