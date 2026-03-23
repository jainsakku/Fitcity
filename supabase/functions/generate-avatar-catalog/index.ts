import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { failure, success } from "../_shared/response.ts";
import { getServiceClient } from "../_shared/supabase.ts";

type AvatarAttr = {
  gender: "male" | "female" | "nb";
  bodyType: "lean" | "athletic" | "buff";
  skinTone: "fair" | "medium" | "tan" | "deep";
};

const BUCKET = "avatars-ai";
const DEFAULT_COUNT = 100;
const MAX_COUNT = 200;
const MODEL_CANDIDATES = [
  "gemini-2.5-flash-image-preview",
  "gemini-2.0-flash-exp-image-generation",
  "gemini-2.0-flash-preview-image-generation",
  "gemini-2.0-flash",
];

const GENDERS: AvatarAttr["gender"][] = ["male", "female", "nb"];
const BODY_TYPES: AvatarAttr["bodyType"][] = ["lean", "athletic", "buff"];
const SKIN_TONES: AvatarAttr["skinTone"][] = ["fair", "medium", "tan", "deep"];

let discoveredModels: string[] | null = null;

function toBytes(base64Data: string): Uint8Array {
  const decoded = atob(base64Data);
  const out = new Uint8Array(decoded.length);
  for (let i = 0; i < decoded.length; i += 1) {
    out[i] = decoded.charCodeAt(i);
  }
  return out;
}

function getAdminKey(req: Request): string {
  const incoming = req.headers.get("x-fitcity-admin-key") ?? "";
  const expected = Deno.env.get("FITCITY_ADMIN_KEY") ?? "";

  if (!incoming || !expected || incoming !== expected) {
    throw new Error("Unauthorized");
  }

  return incoming;
}

function buildAttr(index: number): AvatarAttr {
  return {
    gender: GENDERS[index % GENDERS.length],
    bodyType: BODY_TYPES[Math.floor(index / GENDERS.length) % BODY_TYPES.length],
    skinTone: SKIN_TONES[Math.floor(index / (GENDERS.length * BODY_TYPES.length)) % SKIN_TONES.length],
  };
}

function buildPrompt(attr: AvatarAttr, seed: string): string {
  return [
    "Create a stylized but realistic digital avatar portrait for a fitness app.",
    "Head and shoulders framing, centered, neutral gradient studio background.",
    "Non-celebrity, fictional person, no logos, no text, no watermark.",
    "Athletic look, crisp lighting, clean facial features, game-ready portrait.",
    `Gender expression: ${attr.gender}.`,
    `Body type cue: ${attr.bodyType}.`,
    `Skin tone: ${attr.skinTone}.`,
    `Seed token: ${seed}.`,
    "Output only image content.",
  ].join(" ");
}

async function generateGeminiImage(prompt: string): Promise<Uint8Array> {
  const apiKey = Deno.env.get("GEMINI_API_KEY");
  if (!apiKey) {
    throw new Error("Missing GEMINI_API_KEY");
  }

  const modelHints = await getModelCandidates(apiKey);
  let lastError = "No model attempts made";

  for (const model of modelHints) {
    const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;
    const response = await fetch(endpoint, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        contents: [{ role: "user", parts: [{ text: prompt }] }],
        generationConfig: {
          responseModalities: ["TEXT", "IMAGE"],
          temperature: 0.8,
        },
      }),
    });

    if (!response.ok) {
      const text = await response.text();
      lastError = `Model ${model} failed (${response.status}): ${text}`;
      // Try next candidate when model is unavailable/unsupported.
      if (response.status === 404 || response.status === 400) {
        continue;
      }
      continue;
    }

    const payload = await response.json();
    const parts = payload?.candidates?.[0]?.content?.parts;
    const imagePart = Array.isArray(parts)
      ? parts.find((part: unknown) => {
          const p = part as { inlineData?: { data?: string; mimeType?: string } };
          return typeof p.inlineData?.data === "string";
        })
      : null;

    const b64 = imagePart?.inlineData?.data;
    if (typeof b64 !== "string" || b64.length === 0) {
      lastError = `Model ${model} returned no image data`;
      continue;
    }

    return toBytes(b64);
  }

  throw new Error(`Gemini image generation failed: ${lastError}`);
}

async function getModelCandidates(apiKey: string): Promise<string[]> {
  if (discoveredModels != null) {
    return discoveredModels;
  }

  const configured = Deno.env.get("GEMINI_IMAGE_MODEL");
  const seen = new Set<string>();
  const ordered: string[] = [];

  if (configured && configured.trim().length > 0) {
    const model = configured.trim();
    seen.add(model);
    ordered.push(model);
  }

  // Pull available models from Gemini API and prioritize ones that likely support image generation.
  try {
    const listEndpoint = `https://generativelanguage.googleapis.com/v1beta/models?key=${apiKey}`;
    const response = await fetch(listEndpoint);
    if (response.ok) {
      const payload = await response.json();
      const models = Array.isArray(payload?.models) ? payload.models : [];
      const generated = models
        .map((m: unknown) => {
          const model = m as { name?: string; supportedGenerationMethods?: string[] };
          const name = model.name ?? "";
          const short = name.startsWith("models/") ? name.substring(7) : name;
          const methods = Array.isArray(model.supportedGenerationMethods)
            ? model.supportedGenerationMethods
            : [];
          const supportsGenerateContent = methods.includes("generateContent");
          return { short, supportsGenerateContent };
        })
        .filter((m: { short: string; supportsGenerateContent: boolean }) => {
          if (!m.supportsGenerateContent) return false;
          const s = m.short.toLowerCase();
          return s.includes("image") || s.includes("flash");
        })
        .map((m: { short: string }) => m.short);

      for (const model of generated) {
        if (!seen.has(model)) {
          seen.add(model);
          ordered.push(model);
        }
      }
    }
  } catch {
    // Keep fallback candidates if model listing fails.
  }

  for (const model of MODEL_CANDIDATES) {
    if (!seen.has(model)) {
      seen.add(model);
      ordered.push(model);
    }
  }

  discoveredModels = ordered;
  return discoveredModels;
}

serve(async (req) => {
  try {
    if (req.method !== "POST") {
      return failure("Use POST", 405);
    }

    getAdminKey(req);

    const body = await req.json().catch(() => ({}));
    const requestedCount = Number(body.count ?? DEFAULT_COUNT);
    const count = Math.min(MAX_COUNT, Math.max(1, Number.isFinite(requestedCount) ? requestedCount : DEFAULT_COUNT));

    const supabase = getServiceClient();
    const batchId = new Date().toISOString().replace(/[:.]/g, "-");

    const created: Array<Record<string, string>> = [];
    const failed: Array<Record<string, string>> = [];

    for (let i = 0; i < count; i += 1) {
      const seq = String(i + 1).padStart(3, "0");
      const attr = buildAttr(i);
      const seed = `${batchId}-${seq}`;
      const prompt = buildPrompt(attr, seed);
      const path = `${batchId}/${seq}-${attr.gender}-${attr.bodyType}-${attr.skinTone}.png`;

      try {
        const bytes = await generateGeminiImage(prompt);

        const { error: uploadError } = await supabase.storage
          .from(BUCKET)
          .upload(path, bytes, {
            contentType: "image/png",
            upsert: true,
          });

        if (uploadError) {
          throw new Error(uploadError.message);
        }

        const { data: publicData } = supabase.storage.from(BUCKET).getPublicUrl(path);
        const publicUrl = publicData.publicUrl;

        const selectedModel = Deno.env.get("GEMINI_IMAGE_MODEL") ?? "auto-discovery";
        const { error: insertError } = await supabase.from("avatar_catalog").upsert(
          {
            file_path: path,
            public_url: publicUrl,
            gender: attr.gender,
            body_type: attr.bodyType,
            skin_tone: attr.skinTone,
            source_model: selectedModel,
          },
          { onConflict: "file_path" },
        );

        if (insertError) {
          throw new Error(insertError.message);
        }

        created.push({ path, gender: attr.gender, body_type: attr.bodyType, skin_tone: attr.skinTone, public_url: publicUrl });
      } catch (error) {
        failed.push({
          path,
          error: error instanceof Error ? error.message : "Unknown error",
        });
      }
    }

    return success({
      batch_id: batchId,
      requested: count,
      created_count: created.length,
      failed_count: failed.length,
      created,
      failed,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown error";
    const status = message === "Unauthorized" ? 401 : 500;
    return failure(message, status);
  }
});
