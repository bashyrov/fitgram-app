import type { Env } from "./env";
import type { Logger } from "./log";

/**
 * Thin client around Google Gemini's `generateContent` REST endpoint. Used
 * here only for vision: image → structured JSON describing each food item
 * the model spots on a plate.
 *
 * Polish-tuned system prompt: lists fast-food chains and home dishes the
 * model is most likely to misclassify if we let it default to American
 * food, plus explicit JSON-only contract so we don't have to do prose
 * extraction.
 */
export interface DetectedItem {
    name: string;
    quantityGrams: number;
    caloriesKcal: number;
    proteinGrams: number;
    carbsGrams: number;
    fatGrams: number;
    confidence: number;
}

export interface DetectionResponse {
    items: DetectedItem[];
    suggestedMealType: "breakfast" | "lunch" | "dinner" | "snack";
    confidence: number;
    rawAINotes: string | null;
}

const SYSTEM_PROMPT = `You analyse a single photo of a meal and return strict JSON.

Audience: Polish users. Prefer Polish names for traditional dishes
("schabowy", "pierogi", "żurek", "kotlet mielony", "rosół"), Polish
fast-food chains (Pasibus, Bobby Burger, Max Premium, Sphinx, Żabka,
Pizza Hut PL menus), and Polish bakery items.

Estimate portion in grams from the visual size relative to typical plates.
Macros must be physically plausible (calories ≈ 4·protein + 4·carbs + 9·fat
within ±15%). Confidence is 0..1 per item and overall.

Suggested meal type heuristics:
- breakfast: porridge, eggs, bread + sweet toppings, pancakes
- lunch: hot main course with side, soup
- dinner: lighter cooked dish, leftovers
- snack: single small item or beverage

If no recognisable food is present, return an empty items array, neutral
confidence (0.2), and a short note explaining what was visible.

Respond ONLY with JSON matching this schema (no markdown fences):
{
  "items": [
    {
      "name": "string",
      "quantity_grams": 0.0,
      "calories_kcal": 0.0,
      "protein_grams": 0.0,
      "carbs_grams": 0.0,
      "fat_grams": 0.0,
      "confidence": 0.0
    }
  ],
  "suggested_meal_type": "breakfast" | "lunch" | "dinner" | "snack",
  "confidence": 0.0,
  "raw_ai_notes": null | "string"
}`;

interface GeminiPart {
    text?: string;
    inline_data?: { mime_type: string; data: string };
}
interface GeminiContent {
    role?: string;
    parts: GeminiPart[];
}
interface GeminiCandidate {
    content?: { parts?: GeminiPart[] };
}
interface GeminiResponse {
    candidates?: GeminiCandidate[];
}

export async function detectFood(
    env: Env,
    log: Logger,
    image: ArrayBuffer,
    mimeType: string,
    suggestedMealType: DetectionResponse["suggestedMealType"] | null,
    options: { premium?: boolean } = {}
): Promise<DetectionResponse> {
    const model = options.premium ? env.GEMINI_PREMIUM_MODEL : env.GEMINI_VISION_MODEL;
    const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${env.GEMINI_API_KEY}`;

    const promptParts: GeminiPart[] = [{ text: SYSTEM_PROMPT }];
    if (suggestedMealType) {
        promptParts.push({
            text: `Time-of-day hint (not authoritative): the user is currently around their typical ${suggestedMealType} time.`,
        });
    }
    promptParts.push({
        inline_data: {
            mime_type: mimeType,
            data: arrayBufferToBase64(image),
        },
    });

    const body = {
        contents: [{ role: "user", parts: promptParts } satisfies GeminiContent],
        generationConfig: {
            temperature: 0.2,
            topP: 0.9,
            maxOutputTokens: 1024,
            responseMimeType: "application/json",
        },
    };

    const response = await fetch(endpoint, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
    });
    if (!response.ok) {
        const text = await response.text();
        log.error("Gemini call failed", { status: response.status, body: text.slice(0, 400) });
        throw new GeminiError(response.status, "Gemini upstream returned non-2xx");
    }

    const json = (await response.json()) as GeminiResponse;
    const candidate = json.candidates?.[0];
    const text = candidate?.content?.parts?.[0]?.text ?? null;
    if (!text) {
        log.error("Gemini returned empty content", { json });
        throw new GeminiError(502, "Empty model response");
    }
    return parseResponse(text);
}

function parseResponse(raw: string): DetectionResponse {
    // Gemini occasionally wraps JSON in ```json ... ``` despite the response
    // mime type; strip those defensively before parsing.
    const trimmed = raw.trim().replace(/^```(?:json)?/i, "").replace(/```$/, "").trim();
    const parsed = JSON.parse(trimmed) as Record<string, unknown>;
    const itemsRaw = Array.isArray(parsed.items) ? (parsed.items as Record<string, unknown>[]) : [];
    const items: DetectedItem[] = itemsRaw.map((row) => ({
        name: String(row.name ?? "Nieznane danie"),
        quantityGrams: Number(row.quantity_grams ?? 0),
        caloriesKcal: Number(row.calories_kcal ?? 0),
        proteinGrams: Number(row.protein_grams ?? 0),
        carbsGrams: Number(row.carbs_grams ?? 0),
        fatGrams: Number(row.fat_grams ?? 0),
        confidence: clamp(Number(row.confidence ?? 0.5), 0, 1),
    }));
    const mealType = normaliseMealType(parsed.suggested_meal_type);
    return {
        items,
        suggestedMealType: mealType,
        confidence: clamp(Number(parsed.confidence ?? 0.5), 0, 1),
        rawAINotes: typeof parsed.raw_ai_notes === "string" ? (parsed.raw_ai_notes as string) : null,
    };
}

function normaliseMealType(raw: unknown): DetectionResponse["suggestedMealType"] {
    if (raw === "breakfast" || raw === "lunch" || raw === "dinner" || raw === "snack") {
        return raw;
    }
    return "snack";
}

function clamp(value: number, lower: number, upper: number): number {
    if (Number.isNaN(value)) return lower;
    return Math.min(upper, Math.max(lower, value));
}

function arrayBufferToBase64(buffer: ArrayBuffer): string {
    const bytes = new Uint8Array(buffer);
    let binary = "";
    const chunkSize = 0x8000;
    for (let i = 0; i < bytes.length; i += chunkSize) {
        binary += String.fromCharCode(...bytes.subarray(i, i + chunkSize));
    }
    return btoa(binary);
}

export class GeminiError extends Error {
    constructor(
        public status: number,
        message: string
    ) {
        super(message);
        this.name = "GeminiError";
    }
}
