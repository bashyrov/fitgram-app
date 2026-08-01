import type { Env } from "./env";
import { imageHash, pickCache } from "./cache";
import { detectFood, type DetectionResponse } from "./gemini";
import type { Logger } from "./log";
import { problemResponse, jsonResponse } from "./responses";
import type { AuthContext } from "./auth";
import { checkDailyAIQuota, recordUsage, timeZoneOffsetMinutesFromRequest } from "./usage";

const MAX_IMAGE_BYTES = 6 * 1024 * 1024; // 6 MB safety cap

/**
 * POST /api/v1/scan-food
 * multipart/form-data:
 *   image: the JPEG/PNG bytes
 *   meal_type_hint (optional): "breakfast" | "lunch" | "dinner" | "snack"
 *   premium (optional): "true" to use Gemini Pro instead of Flash
 *
 * Returns: DetectionResponse (with snake_case field names — matches what
 * the iOS client decodes via JSONDecoder.mealgram).
 */
export async function handleScanFood(
    request: Request,
    env: Env,
    log: Logger,
    auth: AuthContext
): Promise<Response> {
    if (request.method !== "POST") {
        return problemResponse(405, "Method not allowed");
    }
    const contentType = request.headers.get("Content-Type") ?? "";
    if (!contentType.toLowerCase().startsWith("multipart/form-data")) {
        return problemResponse(415, "Expected multipart/form-data");
    }

    let form: FormData;
    try {
        form = await request.formData();
    } catch (err) {
        return problemResponse(400, `Bad multipart body: ${(err as Error).message}`);
    }

    const imageRaw = form.get("image") as unknown;
    if (imageRaw === null || typeof imageRaw === "string" || !isBlob(imageRaw)) {
        return problemResponse(400, "Missing 'image' file part");
    }
    const image = imageRaw;
    if (image.size === 0 || image.size > MAX_IMAGE_BYTES) {
        return problemResponse(413, "Image must be 1..6 MB");
    }
    const mimeType = image.type || "image/jpeg";
    const buffer = await image.arrayBuffer();

    const hint = form.get("meal_type_hint");
    const mealHint =
        hint === "breakfast" || hint === "lunch" || hint === "dinner" || hint === "snack"
            ? (hint as DetectionResponse["suggestedMealType"])
            : null;
    const premium = form.get("premium") === "true";
    const localeRaw = form.get("locale");
    const locale = typeof localeRaw === "string" && localeRaw.length > 0 ? localeRaw : "en";

    const cache = pickCache(env);
    const hash = await imageHash(buffer);
    // Locale is part of the cache key — different language → different
    // dish names returned, so we can't share cache hits across locales.
    const cacheKey = `scan:${premium ? "pro" : "flash"}:${locale.slice(0, 2)}:${hash}`;
    const startedAt = Date.now();
    const modelHint = premium ? env.GEMINI_PREMIUM_MODEL : env.GEMINI_VISION_MODEL;
    const quota = await checkDailyAIQuota(env, log, auth.userID, {
        isPremium: auth.isPremium,
        timeZoneOffsetMinutes: timeZoneOffsetMinutesFromRequest(request),
    });
    if (!quota.allowed) {
        return problemResponse(429, "Daily AI safety limit reached", {
            used: quota.used,
            cap: quota.cap,
            reason: quota.reason,
        });
    }
    const cached = await cache.get<DetectionResponse>(cacheKey);
    if (cached) {
        log.info("Scan served from cache", { user: auth.userID, hash });
        await recordUsage(env, log, {
            userID: auth.userID,
            model: modelHint,
            endpoint: "/api/v1/scan-food",
            promptTokens: 0,
            outputTokens: 0,
            cached: true,
            durationMs: Date.now() - startedAt,
        });
        return jsonResponse(toWireFormat(cached, true));
    }

    let detection: DetectionResponse;
    let usage: { model: string; promptTokens: number; outputTokens: number };
    try {
        const result = await detectFood(env, log, buffer, mimeType, mealHint, {
            premium,
            locale,
        });
        detection = result.detection;
        usage = result.usage;
    } catch (err) {
        log.error("Detection failed", { user: auth.userID, err: String(err) });
        const status = (err as { status?: number }).status ?? 502;
        return problemResponse(status, "Detection failed");
    }

    const ttl = Number.parseInt(env.CACHE_TTL_SECONDS, 10) || 604_800;
    await cache.set(cacheKey, detection, ttl);
    await recordUsage(env, log, {
        userID: auth.userID,
        model: usage.model,
        endpoint: "/api/v1/scan-food",
        promptTokens: usage.promptTokens,
        outputTokens: usage.outputTokens,
        cached: false,
        durationMs: Date.now() - startedAt,
    });
    log.info("Scan completed", {
        user: auth.userID,
        items: detection.items.length,
        hash,
        promptTokens: usage.promptTokens,
        outputTokens: usage.outputTokens,
    });
    return jsonResponse(toWireFormat(detection, false));
}

function isBlob(value: unknown): value is Blob {
    return (
        typeof value === "object" &&
        value !== null &&
        typeof (value as { arrayBuffer?: unknown }).arrayBuffer === "function" &&
        typeof (value as { size?: unknown }).size === "number" &&
        typeof (value as { type?: unknown }).type === "string"
    );
}

function toWireFormat(detected: DetectionResponse, fromCache: boolean): Record<string, unknown> {
    return {
        items: detected.items.map((item) => ({
            name: item.name,
            quantity_grams: item.quantityGrams,
            calories_kcal: item.caloriesKcal,
            protein_grams: item.proteinGrams,
            carbs_grams: item.carbsGrams,
            fat_grams: item.fatGrams,
            confidence: item.confidence,
        })),
        suggested_meal_type: detected.suggestedMealType,
        confidence: detected.confidence,
        raw_ai_notes: detected.rawAINotes,
        from_cache: fromCache,
    };
}
