import type { Env } from "./env";
import { imageHash, pickCache } from "./cache";
import { detectFood, type DetectionResponse } from "./gemini";
import type { Logger } from "./log";
import { problemResponse, jsonResponse } from "./responses";
import type { AuthContext } from "./auth";

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

    const image = form.get("image");
    if (!(image instanceof File)) {
        return problemResponse(400, "Missing 'image' file part");
    }
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

    const cache = pickCache(env);
    const hash = await imageHash(buffer);
    const cacheKey = `scan:${premium ? "pro" : "flash"}:${hash}`;
    const cached = await cache.get<DetectionResponse>(cacheKey);
    if (cached) {
        log.info("Scan served from cache", { user: auth.userID, hash });
        return jsonResponse(toWireFormat(cached, true));
    }

    let detected: DetectionResponse;
    try {
        detected = await detectFood(env, log, buffer, mimeType, mealHint, { premium });
    } catch (err) {
        log.error("Detection failed", { user: auth.userID, err: String(err) });
        const status = (err as { status?: number }).status ?? 502;
        return problemResponse(status, "Detection failed");
    }

    const ttl = Number.parseInt(env.CACHE_TTL_SECONDS, 10) || 604_800;
    await cache.set(cacheKey, detected, ttl);
    log.info("Scan completed", { user: auth.userID, items: detected.items.length, hash });
    return jsonResponse(toWireFormat(detected, false));
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
