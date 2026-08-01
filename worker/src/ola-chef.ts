import type { AuthContext } from "./auth";
import type { Env } from "./env";
import { generateJSON } from "./gemini";
import type { Logger } from "./log";
import { jsonResponse, problemResponse } from "./responses";
import { checkDailyAIQuota, recordUsage, timeZoneOffsetMinutesFromRequest } from "./usage";

type MealType = "breakfast" | "lunch" | "dinner" | "snack";

interface OlaChefRequest {
    targetCalories?: number;
    target_calories?: number;
    mealType?: MealType;
    meal_type?: MealType;
    preferences?: string[];
    locale?: string;
    excludeDishNames?: string[];
    exclude_dish_names?: string[];
}

interface OlaChefIngredient {
    name: string;
    grams: number;
    caloriesKcal: number;
    proteinGrams: number;
    carbsGrams: number;
    fatGrams: number;
}

interface OlaChefSuggestion {
    id: string;
    name: string;
    cuisine: string;
    servingGrams: number;
    caloriesKcal: number;
    proteinGrams: number;
    carbsGrams: number;
    fatGrams: number;
    prepMinutes: number;
    ingredients: OlaChefIngredient[];
    steps: string[];
    confidence: number;
}

interface OlaChefResponse {
    suggestions: OlaChefSuggestion[];
    rawAINotes: string | null;
}

export async function handleOlaChefSuggestions(
    request: Request,
    env: Env,
    log: Logger,
    auth: AuthContext
): Promise<Response> {
    if (request.method !== "POST") {
        return problemResponse(405, "Method not allowed");
    }

    let payload: OlaChefRequest;
    try {
        payload = (await request.json()) as OlaChefRequest;
    } catch {
        return problemResponse(400, "Bad JSON body");
    }

    const targetCalories = clamp(
        Number(payload.targetCalories ?? payload.target_calories ?? 600),
        200,
        1200
    );
    const mealType = normaliseMealType(payload.mealType ?? payload.meal_type);
    const locale = String(payload.locale ?? "pl");
    const preferences = Array.isArray(payload.preferences) ? payload.preferences.slice(0, 8) : [];
    const excludeDishNames = Array.isArray(payload.excludeDishNames)
        ? payload.excludeDishNames
        : Array.isArray(payload.exclude_dish_names)
          ? payload.exclude_dish_names
          : [];

    const startedAt = Date.now();
    const quota = await checkDailyAIQuota(env, log, auth.userID, {
        kind: "ola_chef",
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
    const prompt = buildPrompt({ targetCalories, mealType, locale, preferences, excludeDishNames });

    try {
        const { parsed, usage } = await generateJSON<OlaChefResponse>(env, log, prompt, {
            premium: true,
            maxOutputTokens: 2400,
        });
        const response = sanitiseResponse(parsed, targetCalories);
        await recordUsage(env, log, {
            userID: auth.userID,
            model: usage.model,
            endpoint: "/api/v1/ola-chef/suggestions",
            promptTokens: usage.promptTokens,
            outputTokens: usage.outputTokens,
            cached: false,
            durationMs: Date.now() - startedAt,
        });
        return jsonResponse(toWireFormat(response));
    } catch (err) {
        log.error("Ola Chef suggestions failed", { user: auth.userID, err: String(err) });
        return problemResponse(502, "Ola Chef AI unavailable");
    }
}

function buildPrompt(req: {
    targetCalories: number;
    mealType: MealType;
    locale: string;
    preferences: string[];
    excludeDishNames: string[];
}): string {
    return [
        "You generate realistic meals for Mealgram's feature called Kuchnia Oli.",
        "Return strict JSON only. Do not include markdown fences.",
        `Write dish names, ingredient names, and recipe steps in ${languageName(req.locale)}.`,
        "",
        "Hard requirements:",
        "- Return 4 to 6 distinct real-world meals, not synthetic templates.",
        "- Do not create the same dish under different cuisines.",
        "- Avoid excluded dish names and near-duplicates.",
        "- Use concrete ingredients only. Never use placeholders like main protein, vegetables, sauce, starch.",
        "- Ingredient calories and macros must match their grams.",
        "- Meal total macros must equal the sum of ingredients within ±10%.",
        "- Target calories should be within ±12% of the user's target.",
        "- If a dish is from a national cuisine, it must genuinely fit that cuisine.",
        "- Keep preparation steps short, practical, and safe.",
        "",
        `Target calories: ${Math.round(req.targetCalories)} kcal`,
        `Meal type: ${req.mealType}`,
        `Preferences: ${req.preferences.join(", ") || "balanced"}`,
        `Excluded names: ${req.excludeDishNames.slice(0, 24).join(", ") || "none"}`,
        "",
        "Return this exact JSON shape:",
        "{",
        '  "suggestions": [',
        "    {",
        '      "id": "stable-slug",',
        '      "name": "string",',
        '      "cuisine": "string",',
        '      "serving_grams": 0.0,',
        '      "calories_kcal": 0.0,',
        '      "protein_grams": 0.0,',
        '      "carbs_grams": 0.0,',
        '      "fat_grams": 0.0,',
        '      "prep_minutes": 0,',
        '      "ingredients": [',
        "        {",
        '          "name": "string",',
        '          "grams": 0.0,',
        '          "calories_kcal": 0.0,',
        '          "protein_grams": 0.0,',
        '          "carbs_grams": 0.0,',
        '          "fat_grams": 0.0',
        "        }",
        "      ],",
        '      "steps": ["string"],',
        '      "confidence": 0.0',
        "    }",
        "  ],",
        '  "raw_ai_notes": null | "short string"',
        "}",
    ].join("\n");
}

function sanitiseResponse(parsed: OlaChefResponse, targetCalories: number): OlaChefResponse {
    const raw = parsed as unknown as Record<string, unknown>;
    const rows = Array.isArray(raw.suggestions) ? (raw.suggestions as Record<string, unknown>[]) : [];
    const seen = new Set<string>();
    const suggestions: OlaChefSuggestion[] = [];
    for (const row of rows) {
        const suggestion = sanitiseSuggestion(row);
        if (!suggestion) continue;
        const key = normaliseKey(suggestion.name);
        if (seen.has(key)) continue;
        if (Math.abs(suggestion.caloriesKcal - targetCalories) / targetCalories > 0.22) continue;
        seen.add(key);
        suggestions.push(suggestion);
        if (suggestions.length >= 6) break;
    }
    return {
        suggestions,
        rawAINotes:
            typeof raw.rawAINotes === "string"
                ? raw.rawAINotes
                : typeof raw.raw_ai_notes === "string"
                  ? raw.raw_ai_notes
                  : null,
    };
}

function sanitiseSuggestion(row: Record<string, unknown>): OlaChefSuggestion | null {
    const ingredientsRaw = Array.isArray(row.ingredients) ? (row.ingredients as Record<string, unknown>[]) : [];
    const ingredients = ingredientsRaw.map(sanitiseIngredient).filter(Boolean) as OlaChefIngredient[];
    if (ingredients.length < 2) return null;
    const totals = sumIngredients(ingredients);
    const name = String(row.name ?? "").trim();
    if (name.length < 3) return null;
    return {
        id: normaliseKey(String(row.id ?? name)) || crypto.randomUUID(),
        name,
        cuisine: String(row.cuisine ?? "AI").trim() || "AI",
        servingGrams: nonNegative(row.servingGrams ?? row.serving_grams) || totals.grams,
        caloriesKcal: nonNegative(row.caloriesKcal ?? row.calories_kcal) || totals.caloriesKcal,
        proteinGrams: nonNegative(row.proteinGrams ?? row.protein_grams) || totals.proteinGrams,
        carbsGrams: nonNegative(row.carbsGrams ?? row.carbs_grams) || totals.carbsGrams,
        fatGrams: nonNegative(row.fatGrams ?? row.fat_grams) || totals.fatGrams,
        prepMinutes: Math.max(5, Math.round(nonNegative(row.prepMinutes ?? row.prep_minutes) || 20)),
        ingredients,
        steps: sanitiseSteps(row.steps),
        confidence: clamp(Number(row.confidence ?? 0.78), 0, 1),
    };
}

function sanitiseIngredient(row: Record<string, unknown>): OlaChefIngredient | null {
    const name = String(row.name ?? "").trim();
    const grams = nonNegative(row.grams);
    if (name.length < 2 || grams <= 0) return null;
    return {
        name,
        grams,
        caloriesKcal: nonNegative(row.caloriesKcal ?? row.calories_kcal),
        proteinGrams: nonNegative(row.proteinGrams ?? row.protein_grams),
        carbsGrams: nonNegative(row.carbsGrams ?? row.carbs_grams),
        fatGrams: nonNegative(row.fatGrams ?? row.fat_grams),
    };
}

function sanitiseSteps(raw: unknown): string[] {
    if (!Array.isArray(raw)) return [];
    return raw.map((step) => String(step).trim()).filter((step) => step.length > 0).slice(0, 6);
}

function sumIngredients(ingredients: OlaChefIngredient[]) {
    return {
        grams: ingredients.reduce((sum, item) => sum + item.grams, 0),
        caloriesKcal: ingredients.reduce((sum, item) => sum + item.caloriesKcal, 0),
        proteinGrams: ingredients.reduce((sum, item) => sum + item.proteinGrams, 0),
        carbsGrams: ingredients.reduce((sum, item) => sum + item.carbsGrams, 0),
        fatGrams: ingredients.reduce((sum, item) => sum + item.fatGrams, 0),
    };
}

function toWireFormat(response: OlaChefResponse): Record<string, unknown> {
    return {
        suggestions: response.suggestions.map((suggestion) => ({
            id: suggestion.id,
            name: suggestion.name,
            cuisine: suggestion.cuisine,
            serving_grams: suggestion.servingGrams,
            calories_kcal: suggestion.caloriesKcal,
            protein_grams: suggestion.proteinGrams,
            carbs_grams: suggestion.carbsGrams,
            fat_grams: suggestion.fatGrams,
            prep_minutes: suggestion.prepMinutes,
            ingredients: suggestion.ingredients.map((ingredient) => ({
                name: ingredient.name,
                grams: ingredient.grams,
                calories_kcal: ingredient.caloriesKcal,
                protein_grams: ingredient.proteinGrams,
                carbs_grams: ingredient.carbsGrams,
                fat_grams: ingredient.fatGrams,
            })),
            steps: suggestion.steps,
            confidence: suggestion.confidence,
        })),
        raw_ai_notes: response.rawAINotes,
    };
}

function normaliseMealType(raw: unknown): MealType {
    if (raw === "breakfast" || raw === "lunch" || raw === "dinner" || raw === "snack") {
        return raw;
    }
    return "snack";
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

function normaliseKey(value: string): string {
    return value
        .toLowerCase()
        .normalize("NFD")
        .replace(/[\u0300-\u036f]/g, "")
        .replace(/[^a-z0-9а-яіїєґё]+/gi, "-")
        .replace(/^-+|-+$/g, "");
}

function nonNegative(value: unknown): number {
    const number = Number(value ?? 0);
    return Number.isFinite(number) ? Math.max(0, number) : 0;
}

function clamp(value: number, lower: number, upper: number): number {
    if (Number.isNaN(value)) return lower;
    return Math.min(upper, Math.max(lower, value));
}
