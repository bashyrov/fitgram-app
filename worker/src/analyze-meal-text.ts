import type { AuthContext } from "./auth";
import { pickCache } from "./cache";
import type { Env } from "./env";
import { generateJSON, type DetectedItem, type DetectionResponse } from "./gemini";
import type { Logger } from "./log";
import { jsonResponse, problemResponse } from "./responses";
import {
    checkDailyAIQuota,
    recordUsage,
    releaseAIQuotaReservation,
    timeZoneOffsetMinutesFromRequest,
    type AIQuotaKind,
} from "./usage";

type MealType = DetectionResponse["suggestedMealType"];

interface TextMealRequest {
    text?: string;
    mealTypeHint?: MealType;
    meal_type_hint?: MealType;
    locale?: string;
    quotaKind?: AIQuotaKind;
    quota_kind?: AIQuotaKind;
}

interface TextMealResponse {
    overall: DetectedItem;
    items: DetectedItem[];
    suggestedMealType: MealType;
    confidence: number;
    rawAINotes: string | null;
}

/**
 * POST /api/v1/analyze-meal-text
 * JSON:
 *   text: voice transcript or manually entered dish name
 *   meal_type_hint: optional breakfast/lunch/dinner/snack
 *   locale: app language
 *
 * Returns both ready-to-save shapes:
 * - `overall`: one dish with total grams/macros
 * - `items`: ingredient/product breakdown with grams/macros per row
 */
export async function handleAnalyzeMealText(
    request: Request,
    env: Env,
    log: Logger,
    auth: AuthContext
): Promise<Response> {
    if (request.method !== "POST") {
        return problemResponse(405, "Method not allowed");
    }

    let payload: TextMealRequest;
    try {
        payload = (await request.json()) as TextMealRequest;
    } catch {
        return problemResponse(400, "Bad JSON body");
    }

    const text = String(payload.text ?? "").trim();
    if (text.length === 0) {
        return problemResponse(400, "Missing text");
    }

    const startedAt = Date.now();
    const quotaKind = normaliseQuotaKind(payload.quotaKind ?? payload.quota_kind);
    const endpointName = `/api/v1/analyze-meal-text:${quotaKind}`;
    const quota = await checkDailyAIQuota(env, log, auth.userID, {
        kind: quotaKind,
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
    const cache = pickCache(env);
    const locale = normaliseLocale(payload.locale);
    const cacheKey =
        quotaKind === "ai_product_nutrition"
            ? `product-nutrition:${normaliseCacheKey(text)}:${locale}`
            : null;
    if (cacheKey) {
        const cached = await cache.get<TextMealResponse>(cacheKey);
        if (cached) {
            await recordUsage(env, log, {
                userID: auth.userID,
                model: "cache.product-nutrition",
                endpoint: endpointName,
                promptTokens: 0,
                outputTokens: 0,
                cached: true,
                durationMs: Date.now() - startedAt,
                reservationID: quota.reservationID,
            });
            return jsonResponse(toWireFormat(cached, true));
        }
    }
    const prompt = buildPrompt({
        text,
        mealTypeHint: normaliseMealType(payload.mealTypeHint ?? payload.meal_type_hint),
        locale,
    });

    try {
        const { parsed, usage } = await generateJSON<TextMealResponse>(env, log, prompt, {
            premium: false,
            maxOutputTokens: 1400,
        });
        const response = sanitiseResponse(
            parsed,
            normaliseMealType(payload.mealTypeHint ?? payload.meal_type_hint),
            locale
        );
        await recordUsage(env, log, {
            userID: auth.userID,
            model: usage.model,
            endpoint: endpointName,
            promptTokens: usage.promptTokens,
            outputTokens: usage.outputTokens,
            cached: false,
            durationMs: Date.now() - startedAt,
            reservationID: quota.reservationID,
        });
        if (cacheKey) {
            await cache.set(cacheKey, response, 30 * 24 * 3600);
        }
        return jsonResponse(toWireFormat(response, true));
    } catch (err) {
        await releaseAIQuotaReservation(env, log, quota.reservationID);
        log.error("Meal text analysis failed", { user: auth.userID, err: String(err) });
        return jsonResponse(
            toWireFormat(
                localFallback(
                    text,
                    normaliseMealType(payload.mealTypeHint ?? payload.meal_type_hint),
                    locale
                ),
                false
            )
        );
    }
}

function normaliseQuotaKind(raw: unknown): AIQuotaKind {
    if (
        raw === "ai_draft_meal"
        || raw === "ai_logged_meal"
        || raw === "ai_product_nutrition"
    ) {
        return raw;
    }
    return "ai_meal_refresh";
}

function normaliseCacheKey(text: string): string {
    return text
        .toLowerCase()
        .normalize("NFD")
        .replace(/[\u0300-\u036f]/g, "")
        .replace(/(\d),(\d)/g, "$1.$2")
        .replace(/\s+/g, " ")
        .replace(/[^\p{L}\p{N}. ]/gu, "")
        .trim()
        .slice(0, 180);
}

function buildPrompt(req: { text: string; mealTypeHint: MealType; locale: string }): string {
    return [
        "You analyse a meal text transcript for the Fitgram calorie tracker.",
        "Return strict JSON only. Do not include markdown fences.",
        `Answer food and dish names in ${languageName(req.locale)}.`,
        "",
        "Critical parsing rules:",
        "- Understand Polish, Russian, Ukrainian, English, and Spanish food phrasing.",
        "- Treat decimal commas as decimals: 0,5 kg = 500 g.",
        "- Convert kilograms to grams.",
        "- Ignore leading speech words such as zjadlem, zjadłem, сьел, ate, comi, etc.",
        "- If the text contains separate products with amounts, preserve those exact grams in items.",
        "- If the user names one composed dish, estimate a plausible ingredient breakdown in items.",
        "- Overall quantity_grams must equal the sum of item quantity_grams unless one composed dish is named.",
        "- Macros must be physically plausible: calories ≈ 4*protein + 4*carbs + 9*fat within ±20%.",
        "- Never return zero macros for recognised foods.",
        "- Use typical plain-food nutrition when the user gives generic products.",
        "- Cheese/ser/сыр/сир/queso usually has low carbs, about 0-5 g per 100 g unless the text says sweetened dessert cheese.",
        "- Meat, fish, eggs, cheese, and tofu should not receive large invented carb values.",
        "",
        "Example:",
        'Text: "Zjadlem 0,5 kg ryzu i 200g sera"',
        "items:",
        '- Ryż, quantity_grams 500, with rice macros',
        '- Ser, quantity_grams 200, with cheese macros',
        "overall.quantity_grams: 700",
        "",
        `Meal type hint: ${req.mealTypeHint}`,
        `Text: ${JSON.stringify(req.text)}`,
        "",
        "Return this exact JSON shape:",
        "{",
        '  "overall": {',
        '    "name": "string",',
        '    "quantity_grams": 0.0,',
        '    "calories_kcal": 0.0,',
        '    "protein_grams": 0.0,',
        '    "carbs_grams": 0.0,',
        '    "fat_grams": 0.0,',
        '    "confidence": 0.0',
        "  },",
        '  "items": [',
        '    {',
        '      "name": "string",',
        '      "quantity_grams": 0.0,',
        '      "calories_kcal": 0.0,',
        '      "protein_grams": 0.0,',
        '      "carbs_grams": 0.0,',
        '      "fat_grams": 0.0,',
        '      "confidence": 0.0',
        "    }",
        "  ],",
        '  "suggested_meal_type": "breakfast" | "lunch" | "dinner" | "snack",',
        '  "confidence": 0.0,',
        '  "raw_ai_notes": null | "short string"',
        "}",
    ].join("\n");
}

function sanitiseResponse(parsed: TextMealResponse, fallbackMealType: MealType, locale: string): TextMealResponse {
    const parsedRaw = parsed as unknown as Record<string, unknown>;
    const rawItems = Array.isArray(parsedRaw.items) ? (parsedRaw.items as Record<string, unknown>[]) : [];
    const items = rawItems.map((item) => sanitiseItem(item, locale)).filter((item) => item.quantityGrams > 0);
    const totals = sumItems(items, locale);
    const overallRaw = isRecord(parsedRaw.overall) ? parsedRaw.overall : totals;
    const overall = sanitiseItem(overallRaw, locale);
    if (overall.quantityGrams <= 0 && totals.quantityGrams > 0) {
        overall.quantityGrams = totals.quantityGrams;
    }
    if (overall.caloriesKcal <= 0 && totals.caloriesKcal > 0) {
        overall.caloriesKcal = totals.caloriesKcal;
        overall.proteinGrams = totals.proteinGrams;
        overall.carbsGrams = totals.carbsGrams;
        overall.fatGrams = totals.fatGrams;
    }
    return {
        overall,
        items,
        suggestedMealType: normaliseMealType(parsedRaw.suggestedMealType ?? parsedRaw.suggested_meal_type) ?? fallbackMealType,
        confidence: clamp(Number(parsedRaw.confidence ?? overall.confidence), 0, 1),
        rawAINotes:
            typeof parsedRaw.rawAINotes === "string"
                ? parsedRaw.rawAINotes
                : typeof parsedRaw.raw_ai_notes === "string"
                  ? parsedRaw.raw_ai_notes
                  : null,
    };
}

function sanitiseItem(raw: Partial<DetectedItem> | Record<string, unknown>, locale: string): DetectedItem {
    const row = raw as Record<string, unknown>;
    return {
        name: String(row.name ?? fallbackMealName(locale)).trim() || fallbackMealName(locale),
        quantityGrams: nonNegative(row.quantityGrams ?? row.quantity_grams),
        caloriesKcal: nonNegative(row.caloriesKcal ?? row.calories_kcal),
        proteinGrams: nonNegative(row.proteinGrams ?? row.protein_grams),
        carbsGrams: nonNegative(row.carbsGrams ?? row.carbs_grams),
        fatGrams: nonNegative(row.fatGrams ?? row.fat_grams),
        confidence: clamp(Number(row.confidence ?? 0.65), 0, 1),
    };
}

function sumItems(items: DetectedItem[], locale = "en"): DetectedItem {
    return {
        name: items.map((item) => item.name).join(" + ") || fallbackMealName(locale),
        quantityGrams: items.reduce((sum, item) => sum + item.quantityGrams, 0),
        caloriesKcal: items.reduce((sum, item) => sum + item.caloriesKcal, 0),
        proteinGrams: items.reduce((sum, item) => sum + item.proteinGrams, 0),
        carbsGrams: items.reduce((sum, item) => sum + item.carbsGrams, 0),
        fatGrams: items.reduce((sum, item) => sum + item.fatGrams, 0),
        confidence: items.reduce((max, item) => Math.max(max, item.confidence), 0.55),
    };
}

function toWireFormat(response: TextMealResponse, aiSucceeded: boolean): Record<string, unknown> {
    return {
        overall: toWireItem(response.overall),
        items: response.items.map(toWireItem),
        suggested_meal_type: response.suggestedMealType,
        confidence: response.confidence,
        raw_ai_notes: response.rawAINotes,
        ai_succeeded: aiSucceeded,
    };
}

function toWireItem(item: DetectedItem): Record<string, unknown> {
    return {
        name: item.name,
        quantity_grams: item.quantityGrams,
        calories_kcal: item.caloriesKcal,
        protein_grams: item.proteinGrams,
        carbs_grams: item.carbsGrams,
        fat_grams: item.fatGrams,
        confidence: item.confidence,
    };
}

function normaliseMealType(raw: unknown): MealType {
    if (raw === "breakfast" || raw === "lunch" || raw === "dinner" || raw === "snack") {
        return raw;
    }
    return "snack";
}

function isRecord(value: unknown): value is Record<string, unknown> {
    return typeof value === "object" && value !== null;
}

function nonNegative(value: unknown): number {
    const number = Number(value ?? 0);
    return Number.isFinite(number) ? Math.max(0, number) : 0;
}

function clamp(value: number, lower: number, upper: number): number {
    if (Number.isNaN(value)) return lower;
    return Math.min(upper, Math.max(lower, value));
}

interface FoodReference {
    name: string;
    aliases: string[];
    kcal: number;
    protein: number;
    carbs: number;
    fat: number;
}

const FOOD_REFERENCES: FoodReference[] = [
    {
        name: "Ryż",
        aliases: ["ryz", "ryż", "ryzu", "ryżu", "rice"],
        kcal: 130,
        protein: 2.7,
        carbs: 28.2,
        fat: 0.3,
    },
    {
        name: "Ser",
        aliases: ["ser", "sera", "cheese", "twarog", "twaróg"],
        kcal: 350,
        protein: 25,
        carbs: 2,
        fat: 27,
    },
    {
        name: "Pierś z kurczaka",
        aliases: ["kurczak", "kurczaka", "piers", "pierś", "gurdka", "grudka", "chicken"],
        kcal: 165,
        protein: 31,
        carbs: 0,
        fat: 3.6,
    },
    {
        name: "Makaron",
        aliases: ["makaron", "makaronu", "pasta"],
        kcal: 157,
        protein: 5.8,
        carbs: 30.9,
        fat: 0.9,
    },
    {
        name: "Jajko",
        aliases: ["jajko", "jajka", "egg", "eggs"],
        kcal: 143,
        protein: 12.6,
        carbs: 0.7,
        fat: 9.5,
    },
    {
        name: "Banan",
        aliases: ["banan", "banana"],
        kcal: 89,
        protein: 1.1,
        carbs: 22.8,
        fat: 0.3,
    },
];

function localFallback(text: string, fallbackMealType: MealType, locale: string): TextMealResponse {
    const items = parseLocalItems(text, locale);
    const safeItems = items.length > 0 ? items : [makeItem(cleanDishName(text) || fallbackMealName(locale), 100, null)];
    const totals = sumItems(safeItems, locale);
    return {
        overall: {
            ...totals,
            name: totals.name,
            confidence: Math.max(0.55, totals.confidence),
        },
        items: safeItems,
        suggestedMealType: fallbackMealType,
        confidence: safeItems.length > 0 ? 0.62 : 0.45,
        rawAINotes: fallbackAINote(locale),
    };
}

function parseLocalItems(text: string, locale: string): DetectedItem[] {
    const normalised = cleanSpeechPrefix(text)
        .replace(/(\d),(\d)/g, "$1.$2")
        .replace(/\s+/g, " ")
        .trim();
    const pattern =
        /(\d+(?:\.\d+)?)\s*(kg|kilo|kilogram(?:y|ów|ow)?|g|gr|gram(?:y|ów|ow)?)\s+([^,;+]+?)(?=\s+(?:i|oraz|plus|\+)\s+\d|[,;+]|$)/giu;
    const items: DetectedItem[] = [];
    for (const match of normalised.matchAll(pattern)) {
        const amount = Number(match[1]);
        if (!Number.isFinite(amount) || amount <= 0) continue;
        const unit = (match[2] ?? "g").toLowerCase();
        const grams = unit.startsWith("kg") || unit.startsWith("kilo") ? amount * 1_000 : amount;
        const rawName = cleanDishName(match[3] ?? "");
        const reference = findReference(rawName);
        items.push(makeItem(referenceName(reference, locale) ?? titleCase(rawName || fallbackProductName(locale)), grams, reference));
    }
    return items;
}

function makeItem(name: string, grams: number, reference: FoodReference | null): DetectedItem {
    const base = reference ?? { kcal: 180, protein: 8, carbs: 18, fat: 7 };
    const factor = grams / 100;
    return {
        name,
        quantityGrams: round(grams),
        caloriesKcal: round(base.kcal * factor),
        proteinGrams: round(base.protein * factor),
        carbsGrams: round(base.carbs * factor),
        fatGrams: round(base.fat * factor),
        confidence: reference ? 0.72 : 0.5,
    };
}

function findReference(rawName: string): FoodReference | null {
    const normalised = normaliseText(rawName);
    return (
        FOOD_REFERENCES.find((food) =>
            food.aliases.some((alias) => normalised.includes(normaliseText(alias)))
        ) ?? null
    );
}

function cleanSpeechPrefix(text: string): string {
    return text.replace(
        /^(zjadlem|zjadłem|zjadlam|zjadłam|jadlem|jadłem|jadlam|jadłam|сьел|съел|съела|з'їв|зїла|ate|i ate)\s+/iu,
        ""
    );
}

function cleanDishName(text: string): string {
    return text
        .replace(/\b(i|oraz|plus|and|та|и)\b/giu, " ")
        .replace(/\s+/g, " ")
        .trim();
}

function normaliseText(text: string): string {
    return text
        .toLowerCase()
        .normalize("NFD")
        .replace(/[\u0300-\u036f]/g, "")
        .replace(/[^a-zа-яіїєґąćęłńóśźż0-9 ]/giu, " ")
        .replace(/\s+/g, " ")
        .trim();
}

function titleCase(text: string): string {
    const lower = text.toLowerCase();
    return lower.charAt(0).toUpperCase() + lower.slice(1);
}

function round(value: number): number {
    return Math.round(value * 10) / 10;
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

function normaliseLocale(locale: unknown): string {
    const raw = String(locale ?? "en").toLowerCase().slice(0, 2);
    return ["pl", "uk", "ru", "es", "en"].includes(raw) ? raw : "en";
}

function fallbackMealName(locale: string): string {
    switch (normaliseLocale(locale)) {
        case "pl": return "Posiłek";
        case "uk": return "Страва";
        case "ru": return "Блюдо";
        case "es": return "Comida";
        case "en":
        default: return "Meal";
    }
}

function fallbackProductName(locale: string): string {
    switch (normaliseLocale(locale)) {
        case "pl": return "Produkt";
        case "uk": return "Продукт";
        case "ru": return "Продукт";
        case "es": return "Producto";
        case "en":
        default: return "Product";
    }
}

function fallbackAINote(locale: string): string {
    switch (normaliseLocale(locale)) {
        case "pl": return "Użyto analizy lokalnej, bo AI jest chwilowo niedostępne.";
        case "uk": return "Використано локальний аналіз, бо AI тимчасово недоступний.";
        case "ru": return "Использован локальный анализ, потому что AI временно недоступен.";
        case "es": return "Se usó el análisis local porque la IA no está disponible temporalmente.";
        case "en":
        default: return "Local analysis was used because AI is temporarily unavailable.";
    }
}

function referenceName(reference: FoodReference | null | undefined, locale: string): string | null {
    if (!reference) return null;
    const key = normaliseText(reference.name);
    const names: Record<string, Record<string, string>> = {
        ryz: { pl: "Ryż", uk: "Рис", ru: "Рис", es: "Arroz", en: "Rice" },
        ser: { pl: "Ser", uk: "Сир", ru: "Сыр", es: "Queso", en: "Cheese" },
        "piers z kurczaka": {
            pl: "Pierś z kurczaka",
            uk: "Куряча грудка",
            ru: "Куриная грудка",
            es: "Pechuga de pollo",
            en: "Chicken breast",
        },
        makaron: { pl: "Makaron", uk: "Паста", ru: "Макароны", es: "Pasta", en: "Pasta" },
        jajko: { pl: "Jajko", uk: "Яйце", ru: "Яйцо", es: "Huevo", en: "Egg" },
        banan: { pl: "Banan", uk: "Банан", ru: "Банан", es: "Plátano", en: "Banana" },
    };
    return names[key]?.[normaliseLocale(locale)] ?? reference.name;
}
