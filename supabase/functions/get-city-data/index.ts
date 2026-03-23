import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { getAuthUserId } from "../_shared/auth.ts";
import { failure, success } from "../_shared/response.ts";

serve(async (req) => {
  try {
    await getAuthUserId(req);
    const body = await req.json().catch(() => ({}));

    return success({
      plotX: body.plotX ?? 0,
      plotY: body.plotY ?? 0,
      radius: body.radius ?? 2,
      districts: {},
      message: "get-city-data scaffold ready",
    });
  } catch (error) {
    return failure(error instanceof Error ? error.message : "Unknown error", 500);
  }
});
