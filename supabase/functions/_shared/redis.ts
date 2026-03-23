import { Redis } from "https://esm.sh/@upstash/redis@1.35.3";

export function getRedisClient() {
  const url = Deno.env.get("UPSTASH_REDIS_URL");
  const token = Deno.env.get("UPSTASH_REDIS_TOKEN");

  if (!url || !token) {
    throw new Error("Missing UPSTASH_REDIS_URL or UPSTASH_REDIS_TOKEN");
  }

  return new Redis({ url, token });
}
