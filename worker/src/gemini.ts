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

/**
 * Combined return — the parsed detection plus the usage metadata Gemini
 * reports for that call. The usage block is what billing / cost
 * accounting uses; callers that don't care can ignore it.
 */
export interface DetectionResult {
    detection: DetectionResponse;
    usage: { model: string; promptTokens: number; outputTokens: number };
}

function buildSystemPrompt(locale: string): string {
    const lang = languageName(locale);
    return `You analyse a single photo of a meal and return strict JSON.

Audience: global. Write every dish "name" in ${lang}. Keep widely-known
brand and dish names in their original form even when the surrounding
text is ${lang} (e.g. "Big Mac", "Pad Thai", "Pierogi", "Sushi").

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
}

function languageName(locale: string): string {
    switch (locale.toLowerCase().slice(0, 2)) {
        case "pl": return "Polish";
        case "uk": return "Ukrainian";
        case "ru": return "Russian";
        case "es": return "Spanish";
        case "en":
        default:
            return "English";
    }
}

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
    finishReason?: string;
    safetyRatings?: unknown[];
}
interface GeminiUsageMetadata {
    promptTokenCount?: number;
    candidatesTokenCount?: number;
    totalTokenCount?: number;
}
interface GeminiResponse {
    candidates?: GeminiCandidate[];
    usageMetadata?: GeminiUsageMetadata;
}

interface ClaudeContentBlock {
    type: string;
    text?: string;
}
interface ClaudeUsage {
    input_tokens?: number;
    output_tokens?: number;
}
interface ClaudeResponse {
    content?: ClaudeContentBlock[];
    usage?: ClaudeUsage;
}
interface ClaudeMessageContent {
    type: "text" | "image";
    text?: string;
    source?: {
        type: "base64";
        media_type: string;
        data: string;
    };
}

export async function detectFood(
    env: Env,
    log: Logger,
    image: ArrayBuffer,
    mimeType: string,
    suggestedMealType: DetectionResponse["suggestedMealType"] | null,
    options: { premium?: boolean; locale?: string } = {}
): Promise<DetectionResult> {
    if (selectedAIProvider(env) === "claude" && env.ANTHROPIC_API_KEY) {
        return detectFoodWithClaude(env, log, image, mimeType, suggestedMealType, options);
    }

    if (!env.GEMINI_API_KEY) {
        throw new GeminiError(500, "No AI provider configured");
    }

    const model = options.premium ? env.GEMINI_PREMIUM_MODEL : env.GEMINI_VISION_MODEL;
    const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${env.GEMINI_API_KEY}`;

    const promptParts: GeminiPart[] = [{ text: buildSystemPrompt(options.locale ?? "en") }];
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
            temperature: 0.1,
            topP: 0.8,
            maxOutputTokens: 2048,
            responseMimeType: "application/json",
            ...geminiThinkingConfig(model),
        },
    };

    const response = await fetchWithOneRetry(endpoint, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
    }, log, "Gemini vision");
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
    const detection = parseResponse(text);
    const usage = {
        model,
        promptTokens: json.usageMetadata?.promptTokenCount ?? 0,
        outputTokens: json.usageMetadata?.candidatesTokenCount ?? 0,
    };
    return { detection, usage };
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

function sleep(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
}

async function fetchWithOneRetry(
    endpoint: string,
    init: RequestInit,
    log: Logger,
    scope: string
): Promise<Response> {
    try {
        const first = await fetch(endpoint, init);
        if (!shouldRetry(first.status)) return first;
        log.warn(`${scope} temporary failure, retrying once`, { status: first.status });
        await sleep(650);
        return await fetch(endpoint, init);
    } catch (err) {
        log.warn(`${scope} network failure, retrying once`, { err: String(err) });
        await sleep(650);
        try {
            return await fetch(endpoint, init);
        } catch (retryErr) {
            log.error(`${scope} retry failed`, { err: String(retryErr) });
            throw new GeminiError(503, "AI upstream temporarily unavailable");
        }
    }
}

function shouldRetry(status: number): boolean {
    return status === 429 || status === 502 || status === 503 || status === 504;
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

/**
 * Text-only Gemini call. Used by the Coach surfaces (daily insight,
 * weekly debrief, onboarding recommendations) where there's no image.
 * Returns the parsed JSON plus the same usage metadata as the vision
 * call so we can record cost.
 */
export interface TextGenerationResult<T> {
    parsed: T;
    usage: { model: string; promptTokens: number; outputTokens: number };
}

export async function generateJSON<T>(
    env: Env,
    log: Logger,
    prompt: string,
    options: { premium?: boolean; maxOutputTokens?: number } = {}
): Promise<TextGenerationResult<T>> {
    if (selectedAIProvider(env) === "claude" && env.ANTHROPIC_API_KEY) {
        return generateJSONWithClaude<T>(env, log, prompt, options);
    }

    if (!env.GEMINI_API_KEY) {
        throw new GeminiError(500, "No AI provider configured");
    }

    const model = options.premium ? env.GEMINI_PREMIUM_MODEL : env.GEMINI_VISION_MODEL;
    const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${env.GEMINI_API_KEY}`;

    const body = {
        contents: [{ role: "user", parts: [{ text: prompt }] } satisfies GeminiContent],
        generationConfig: {
            temperature: 0.1,
            topP: 0.8,
            maxOutputTokens: options.maxOutputTokens ?? 2048,
            responseMimeType: "application/json",
            ...geminiThinkingConfig(model),
        },
    };

    const response = await fetchWithOneRetry(endpoint, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
    }, log, "Gemini text");
    if (!response.ok) {
        const text = await response.text();
        log.error("Gemini text call failed", {
            status: response.status,
            body: text.slice(0, 400),
        });
        throw new GeminiError(response.status, "Gemini upstream returned non-2xx");
    }

    const json = (await response.json()) as GeminiResponse;
    const candidate = json.candidates?.[0];
    const text = candidate?.content?.parts?.[0]?.text ?? null;
    if (!text) {
        log.error("Gemini returned empty text content", {
            finishReason: candidate?.finishReason,
            usage: json.usageMetadata,
        });
        throw new GeminiError(502, "Empty model response");
    }
    const trimmed = text
        .trim()
        .replace(/^```(?:json)?/i, "")
        .replace(/```$/, "")
        .trim();
    let parsed: T;
    try {
        parsed = JSON.parse(trimmed) as T;
    } catch (err) {
        log.error("Gemini JSON parse failed", {
            err: String(err),
            preview: trimmed.slice(0, 400),
            finishReason: candidate?.finishReason,
            usage: json.usageMetadata,
            textLength: trimmed.length,
        });
        throw new GeminiError(502, "Model returned unparseable JSON");
    }
    return {
        parsed,
        usage: {
            model,
            promptTokens: json.usageMetadata?.promptTokenCount ?? 0,
            outputTokens: json.usageMetadata?.candidatesTokenCount ?? 0,
        },
    };
}

async function detectFoodWithClaude(
    env: Env,
    log: Logger,
    image: ArrayBuffer,
    mimeType: string,
    suggestedMealType: DetectionResponse["suggestedMealType"] | null,
    options: { premium?: boolean; locale?: string } = {}
): Promise<DetectionResult> {
    const model = env.CLAUDE_VISION_MODEL || env.CLAUDE_TEXT_MODEL || "claude-sonnet-4-20250514";
    const textParts = [buildSystemPrompt(options.locale ?? "en")];
    if (suggestedMealType) {
        textParts.push(
            `Time-of-day hint (not authoritative): the user is currently around their typical ${suggestedMealType} time.`
        );
    }

    const { text, usage } = await callClaude(env, log, {
        model,
        maxOutputTokens: 1400,
        content: [
            { type: "text", text: textParts.join("\n\n") },
            {
                type: "image",
                source: {
                    type: "base64",
                    media_type: mimeType,
                    data: arrayBufferToBase64(image),
                },
            },
        ],
        scope: "vision",
    });

    return {
        detection: parseResponse(text),
        usage: {
            model,
            promptTokens: usage.input_tokens ?? 0,
            outputTokens: usage.output_tokens ?? 0,
        },
    };
}

async function generateJSONWithClaude<T>(
    env: Env,
    log: Logger,
    prompt: string,
    options: { premium?: boolean; maxOutputTokens?: number } = {}
): Promise<TextGenerationResult<T>> {
    const model = env.CLAUDE_TEXT_MODEL || "claude-sonnet-4-20250514";
    const { text, usage } = await callClaude(env, log, {
        model,
        maxOutputTokens: options.maxOutputTokens ?? 768,
        content: [{ type: "text", text: prompt }],
        scope: "text",
    });
    const trimmed = text
        .trim()
        .replace(/^```(?:json)?/i, "")
        .replace(/```$/, "")
        .trim();
    let parsed: T;
    try {
        parsed = JSON.parse(trimmed) as T;
    } catch (err) {
        log.error("Claude JSON parse failed", {
            err: String(err),
            preview: trimmed.slice(0, 400),
            textLength: trimmed.length,
        });
        throw new GeminiError(502, "Model returned unparseable JSON");
    }
    return {
        parsed,
        usage: {
            model,
            promptTokens: usage.input_tokens ?? 0,
            outputTokens: usage.output_tokens ?? 0,
        },
    };
}

async function callClaude(
    env: Env,
    log: Logger,
    request: {
        model: string;
        maxOutputTokens: number;
        content: ClaudeMessageContent[];
        scope: string;
    }
): Promise<{ text: string; usage: ClaudeUsage }> {
    if (!env.ANTHROPIC_API_KEY) {
        throw new GeminiError(500, "Claude API key missing");
    }

    const headers: Record<string, string> = {
        "Content-Type": "application/json",
        "anthropic-version": "2023-06-01",
    };
    switch (claudeAuthMode(env)) {
        case "bearer":
            headers.Authorization = `Bearer ${env.ANTHROPIC_API_KEY}`;
            break;
        case "both":
            headers["x-api-key"] = env.ANTHROPIC_API_KEY;
            headers.Authorization = `Bearer ${env.ANTHROPIC_API_KEY}`;
            break;
        case "x-api-key":
        default:
            headers["x-api-key"] = env.ANTHROPIC_API_KEY;
            break;
    }

    const response = await fetch(claudeMessagesEndpoint(env), {
        method: "POST",
        headers,
        body: JSON.stringify({
            model: request.model,
            max_tokens: request.maxOutputTokens,
            messages: [{ role: "user", content: request.content }],
        }),
    });

    if (!response.ok) {
        const body = await response.text();
        log.error("Claude call failed", {
            scope: request.scope,
            status: response.status,
            body: body.slice(0, 400),
        });
        throw new GeminiError(response.status, "Claude upstream returned non-2xx");
    }

    const json = (await response.json()) as ClaudeResponse;
    const text = json.content?.find((part) => part.type === "text")?.text ?? null;
    if (!text) {
        log.error("Claude returned empty content", { scope: request.scope, usage: json.usage });
        throw new GeminiError(502, "Empty model response");
    }

    return { text, usage: json.usage ?? {} };
}

function claudeMessagesEndpoint(env: Env): string {
    const base = (env.ANTHROPIC_BASE_URL || "https://api.anthropic.com").replace(/\/+$/, "");
    return `${base}/v1/messages`;
}

function claudeAuthMode(env: Env): "x-api-key" | "bearer" | "both" {
    const raw = env.ANTHROPIC_AUTH_MODE?.toLowerCase();
    if (raw === "bearer" || raw === "both" || raw === "x-api-key") {
        return raw;
    }
    if (env.ANTHROPIC_BASE_URL && !env.ANTHROPIC_BASE_URL.includes("api.anthropic.com")) {
        return "bearer";
    }
    return "x-api-key";
}

function selectedAIProvider(env: Env): "gemini" | "claude" {
    return env.AI_PROVIDER?.toLowerCase() === "claude" ? "claude" : "gemini";
}

function geminiThinkingConfig(model: string): Record<string, unknown> {
    if (model.includes("2.5-flash")) {
        return { thinkingConfig: { thinkingBudget: 0 } };
    }
    return {};
}
