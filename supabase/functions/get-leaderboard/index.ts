import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { getAuthUserId } from "../_shared/auth.ts";
import { failure, success } from "../_shared/response.ts";
import { getRedisClient } from "../_shared/redis.ts";
import { getServiceClient } from "../_shared/supabase.ts";

function getWeekKey() {
  const now = new Date();
  const firstJan = new Date(Date.UTC(now.getUTCFullYear(), 0, 1));
  const day = Math.floor((now.getTime() - firstJan.getTime()) / 86400000) + 1;
  const week = Math.ceil(day / 7);
  return `${now.getUTCFullYear()}-W${week.toString().padStart(2, "0")}`;
}

function getMonthKey() {
  const now = new Date();
  const month = (now.getUTCMonth() + 1).toString().padStart(2, "0");
  return `${now.getUTCFullYear()}-${month}`;
}

serve(async (req) => {
  try {
    const uid = await getAuthUserId(req);
    const body = await req.json().catch(() => ({}));
    const timeFrame = String(body.timeFrame ?? "global");
    const limit = Math.max(1, Math.min(Number(body.limit ?? 50), 100));

    const key = timeFrame === "weekly"
      ? `leaderboard:weekly:${getWeekKey()}`
      : timeFrame === "monthly"
      ? `leaderboard:monthly:${getMonthKey()}`
      : "leaderboard:global";

    const supabase = getServiceClient();

    let rankings: Array<Record<string, unknown>> = [];
    let userRank: number | null = null;
    let userScore: number | null = null;
    let source: "redis" | "postgres" = "postgres";

    try {
      const redis = getRedisClient();
      const top = await redis.zrange<Record<string, string | number>>(key, 0, limit - 1, {
        rev: true,
        withScores: true,
      });

      const ranked = Array.isArray(top) ? top : [];
      const uids = ranked.map((entry) => String(entry.member ?? "")).filter((v) => v.length > 0);

      let profiles: Array<Record<string, unknown>> = [];
      if (uids.length > 0) {
        const { data } = await supabase
          .from("users")
          .select("uid,name,avatar_config,level")
          .in("uid", uids);
        profiles = (data ?? []) as Array<Record<string, unknown>>;
      }

      rankings = ranked.map((entry, i) => {
        const memberId = String(entry.member ?? "");
        const profile = profiles.find((p) => String(p.uid) === memberId) ?? {};
        return {
          rank: i + 1,
          uid: memberId,
          score: Number(entry.score ?? 0),
          name: profile.name ?? "Player",
          avatar_config: profile.avatar_config ?? null,
          level: profile.level ?? 1,
        };
      });

      const rankZero = await redis.zrank(key, uid, { rev: true });
      const score = await redis.zscore(key, uid);
      userRank = rankZero === null ? null : Number(rankZero) + 1;
      userScore = score === null ? null : Number(score);
      source = "redis";
    } catch {
      // Fallback for environments where Upstash is not configured.
      const { data: rows, error } = await supabase
        .from("users")
        .select("uid,name,avatar_config,level,status_total")
        .order("status_total", { ascending: false })
        .limit(limit);

      if (error) {
        return failure(error.message, 400);
      }

      const ranked = (rows ?? []) as Array<Record<string, unknown>>;
      rankings = ranked.map((row, i) => ({
        rank: i + 1,
        uid: row.uid,
        score: Number(row.status_total ?? 0),
        name: row.name ?? "Player",
        avatar_config: row.avatar_config ?? null,
        level: row.level ?? 1,
      }));

      const { data: meRows } = await supabase
        .from("users")
        .select("status_total")
        .eq("uid", uid)
        .limit(1);

      const myScore = Number((meRows?.[0] as Record<string, unknown> | undefined)?.status_total ?? 0);
      userScore = myScore;

      const { count } = await supabase
        .from("users")
        .select("uid", { count: "exact", head: true })
        .gt("status_total", myScore);

      userRank = (count ?? 0) + 1;
    }

    return success({
      timeFrame,
      limit,
      source,
      rankings,
      userRank,
      userScore,
    });
  } catch (error) {
    return failure(error instanceof Error ? error.message : "Unknown error", 500);
  }
});
