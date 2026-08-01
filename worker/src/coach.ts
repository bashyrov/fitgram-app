/// <reference types="@cloudflare/workers-types" />

import type { Env } from "./env";
import { generateJSON, GeminiError } from "./gemini";
import type { Logger } from "./log";
import { jsonResponse, problemResponse } from "./responses";
import { checkDailyAIQuota, recordUsage, timeZoneOffsetMinutesFromRequest } from "./usage";

const ALLOWED_ACTIONS = new Set([
    "openScanner",
    "openQuickDB",
    "openRecipes",
    "openWeightLog",
]);
const ALLOWED_TONES = new Set(["encouragement", "suggestion", "nudge", "celebration"]);

/** -------- /api/v1/user/initial-recommendations -------- **/

interface RecommendationsRequest {
    biologicalSex: "male" | "female" | "preferNotToSay";
    age: number;
    heightCm: number;
    weightKg: number;
    activityLevel: "sedentary" | "light" | "moderate" | "active" | "veryActive";
    goal: "lose" | "gain" | "maintain" | "healthCondition" | "justTracking";
    paceKgPerWeek?: number | null;
    dailyCalorieGoalKcal: number;
    proteinGoalGrams: number;
    fatGoalGrams: number;
    carbsGoalGrams: number;
    fiberGoalGrams: number;
    waterGoalMl: number;
    dietaryPreferences: string[];
    hitSafetyFloor: boolean;
    /** Optional caller-supplied id so the admin dashboard attributes
     *  per-user cost. Empty / missing → "anonymous". */
    userID?: string;
    /** ISO 639-1 (e.g. "en", "pl", "uk", "ru", "es"). Gemini answers
     *  in this language. Defaults to "en" when missing. */
    locale?: string;
}

interface RecommendationTip {
    icon: string;
    title: string;
    description: string;
}
interface Recommendations {
    summary: string;
    tips: RecommendationTip[];
    warnings: string[];
    nextSteps: string;
    source: string;
}

export async function handleInitialRecommendations(
    request: Request,
    env: Env,
    log: Logger
): Promise<Response> {
    if (request.method !== "POST") {
        return problemResponse(405, "Method not allowed");
    }
    let payload: RecommendationsRequest;
    try {
        payload = (await request.json()) as RecommendationsRequest;
    } catch {
        return problemResponse(400, "Bad JSON body");
    }

    const prompt = buildInitialRecsPrompt(payload);
    const startedAt = Date.now();
    const userID = payload.userID?.trim() || "anonymous";
    const quota = await checkDailyAIQuota(env, log, userID, {
        timeZoneOffsetMinutes: timeZoneOffsetMinutesFromRequest(request),
    });
    if (!quota.allowed) {
        return problemResponse(429, "Daily AI safety limit reached", {
            used: quota.used,
            cap: quota.cap,
            reason: quota.reason,
        });
    }
    try {
        const { parsed, usage } = await generateJSON<Recommendations>(env, log, prompt, {
            premium: false,
            maxOutputTokens: 1200,
        });
        await recordUsage(env, log, {
            userID,
            model: usage.model,
            endpoint: "/api/v1/user/initial-recommendations",
            promptTokens: usage.promptTokens,
            outputTokens: usage.outputTokens,
            cached: false,
            durationMs: Date.now() - startedAt,
        });
        const out: Recommendations = {
            summary: String(parsed.summary ?? "").trim(),
            tips: sanitiseTips(parsed.tips),
            warnings: sanitiseStrings(parsed.warnings),
            nextSteps: String(parsed.nextSteps ?? "").trim(),
            source: "worker_gemini_2_5_flash",
        };
        return jsonResponse(out);
    } catch (err) {
        return geminiErrorResponse(err, log, "initial-recommendations");
    }
}

function buildInitialRecsPrompt(req: RecommendationsRequest): string {
    return [
        "You are Ola, the warm AI nutrition coach for the Mealgram iOS app.",
        "The user has just completed onboarding. Generate 3-5 actionable tips,",
        "1-2 warnings only if they're genuinely needed, and a single next-step",
        "sentence. Keep tone friendly and direct — no marketing fluff, no medical",
        "disclaimers.",
        languageInstruction(req.locale),
        "",
        `Profile: ${JSON.stringify(req)}`,
        "",
        "Return ONLY a JSON object matching this exact shape (no markdown fences):",
        '{',
        '  "summary": "1-2 sentence opener tied to their goal",',
        '  "tips": [',
        '    {"icon": "single emoji", "title": "≤5 words", "description": "1-2 sentences, specific"}',
        '  ],',
        '  "warnings": ["short string", ...],',
        '  "nextSteps": "single sentence telling them what to do first"',
        '}',
        "Constraints:",
        "- 3-5 tips. Each title ≤5 words, each description ≤25 words.",
        "- Icons are single emoji (e.g. 🥚, 💧, 🚶, 🥦).",
        "- Reference their goal/pace/protein target/preferences explicitly.",
        "- Warnings array stays empty when no concern (e.g. caloric_floor not hit).",
        "- nextSteps is one concrete sentence (≤20 words).",
    ].join("\n");
}

/** -------- /api/v1/coach/daily-insight -------- **/

interface CoachContext {
    goals: { calorieGoalKcal: number; proteinGoalGrams: number };
    today: {
        caloriesKcal: number;
        proteinGrams: number;
        carbsGrams: number;
        fatGrams: number;
        entryCount: number;
        hasLoggedToday: boolean;
    };
    week: {
        dailyCalorieAverages: number[];
        dailyProteinAverages: number[];
        daysWithAnyEntry: number;
        daysHittingProteinGoal: number;
        daysWithinCalorieGoal: number;
    };
    streak: {
        current: number;
        longest: number;
        freezesAvailable: number;
        atRiskToday: boolean;
    };
    weight: {
        latestKg: number | null;
        deltaKg30Days: number | null;
    };
    hourOfDay: number;
    hasOngoingCulturalEvent: boolean;
    userID?: string;
    /** ISO 639-1 (en / pl / uk / ru / es). Gemini answers in this language. */
    locale?: string;
}

interface CoachInsightOut {
    tone: string;
    headline: string;
    body: string;
    actionTitle?: string | undefined;
    actionKind?: string | undefined;
}

interface DailyInsightResponse {
    insights: CoachInsightOut[];
}

export async function handleDailyInsight(
    request: Request,
    env: Env,
    log: Logger
): Promise<Response> {
    if (request.method !== "POST") {
        return problemResponse(405, "Method not allowed");
    }
    let ctx: CoachContext;
    try {
        ctx = (await request.json()) as CoachContext;
    } catch {
        return problemResponse(400, "Bad JSON body");
    }

    const prompt = buildDailyInsightPrompt(ctx);
    const startedAt = Date.now();
    const userID = ctx.userID?.trim() || "anonymous";
    const quota = await checkDailyAIQuota(env, log, userID, {
        timeZoneOffsetMinutes: timeZoneOffsetMinutesFromRequest(request),
    });
    if (!quota.allowed) {
        return problemResponse(429, "Daily AI safety limit reached", {
            used: quota.used,
            cap: quota.cap,
            reason: quota.reason,
        });
    }
    try {
        const { parsed, usage } = await generateJSON<DailyInsightResponse>(env, log, prompt, {
            premium: false,
            maxOutputTokens: 1200,
        });
        await recordUsage(env, log, {
            userID,
            model: usage.model,
            endpoint: "/api/v1/coach/daily-insight",
            promptTokens: usage.promptTokens,
            outputTokens: usage.outputTokens,
            cached: false,
            durationMs: Date.now() - startedAt,
        });
        const out: DailyInsightResponse = {
            insights: sanitiseInsights(parsed.insights),
        };
        return jsonResponse(out);
    } catch (err) {
        return geminiErrorResponse(err, log, "daily-insight");
    }
}

function buildDailyInsightPrompt(ctx: CoachContext): string {
    return [
        "You are Ola, a warm AI nutrition coach inside Mealgram.",
        "Given the user's current-day and 7-day snapshot, produce 2-4",
        "short coaching insights ordered by relevance. Pick concrete details",
        "from the data (streak length, calorie gap, protein shortfall,",
        "logging momentum) rather than generic advice.",
        languageInstruction(ctx.locale),
        "",
        `Context: ${JSON.stringify(ctx)}`,
        "",
        "Return ONLY this JSON shape (no markdown fences):",
        '{',
        '  "insights": [',
        '    {',
        '      "tone": "encouragement|suggestion|nudge|celebration",',
        '      "headline": "≤8 words",',
        '      "body": "1-2 sentences ≤30 words",',
        '      "actionTitle": "≤3 words OR null",',
        '      "actionKind": "openScanner|openQuickDB|openRecipes|openWeightLog OR null"',
        '    }',
        '  ]',
        '}',
        "Constraints:",
        "- 2-4 insights. Most relevant first.",
        "- Pick `tone` honestly. Celebration is for genuine milestones only.",
        "- actionTitle/actionKind are optional — drop them when no clear CTA fits.",
        "- Reference numbers from the context where helpful (e.g. '3-day streak').",
    ].join("\n");
}

/** -------- /api/v1/coach/weekly-debrief -------- **/

interface WeeklyDebriefResponse {
    headline: string;
    insights: CoachInsightOut[];
}

export async function handleWeeklyDebrief(
    request: Request,
    env: Env,
    log: Logger
): Promise<Response> {
    if (request.method !== "POST") {
        return problemResponse(405, "Method not allowed");
    }
    let ctx: CoachContext;
    try {
        ctx = (await request.json()) as CoachContext;
    } catch {
        return problemResponse(400, "Bad JSON body");
    }

    const prompt = buildWeeklyDebriefPrompt(ctx);
    const startedAt = Date.now();
    const userID = ctx.userID?.trim() || "anonymous";
    const quota = await checkDailyAIQuota(env, log, userID, {
        kind: "coach_debrief",
        isPremium: Boolean((ctx as { isPremium?: boolean; is_premium?: boolean }).isPremium)
            || Boolean((ctx as { isPremium?: boolean; is_premium?: boolean }).is_premium),
        timeZoneOffsetMinutes: timeZoneOffsetMinutesFromRequest(request),
    });
    if (!quota.allowed) {
        return problemResponse(429, "Daily AI safety limit reached", {
            used: quota.used,
            cap: quota.cap,
            reason: quota.reason,
        });
    }
    try {
        const { parsed, usage } = await generateJSON<WeeklyDebriefResponse>(env, log, prompt, {
            premium: false,
            maxOutputTokens: 1200,
        });
        await recordUsage(env, log, {
            userID,
            model: usage.model,
            endpoint: "/api/v1/coach/weekly-debrief",
            promptTokens: usage.promptTokens,
            outputTokens: usage.outputTokens,
            cached: false,
            durationMs: Date.now() - startedAt,
        });
        const out: WeeklyDebriefResponse = {
            headline: String(parsed.headline ?? "").trim() || "Twój tydzień",
            insights: sanitiseInsights(parsed.insights),
        };
        return jsonResponse(out);
    } catch (err) {
        return geminiErrorResponse(err, log, "weekly-debrief");
    }
}

function buildWeeklyDebriefPrompt(ctx: CoachContext): string {
    return [
        "You are Ola, summarising the user's last 7 days inside Mealgram.",
        "Generate a short headline + 3-5 insights summarising the week.",
        "Speak directly to the user. Pull numbers from the context.",
        languageInstruction(ctx.locale),
        "",
        `Context: ${JSON.stringify(ctx)}`,
        "",
        "Return ONLY this JSON shape:",
        '{',
        '  "headline": "2-4 words capturing how the week went",',
        '  "insights": [',
        '    {',
        '      "tone": "encouragement|suggestion|nudge|celebration",',
        '      "headline": "≤8 words",',
        '      "body": "1-2 sentences ≤30 words",',
        '      "actionTitle": "≤3 words OR null",',
        '      "actionKind": "openScanner|openQuickDB|openRecipes|openWeightLog OR null"',
        '    }',
        '  ]',
        '}',
    ].join("\n");
}

/** -------- shared sanitisers -------- **/

function sanitiseTips(raw: unknown): RecommendationTip[] {
    if (!Array.isArray(raw)) return [];
    return raw
        .map((row): RecommendationTip => {
            const r = row as Record<string, unknown>;
            return {
                icon: String(r.icon ?? "💡").slice(0, 4),
                title: String(r.title ?? "").trim(),
                description: String(r.description ?? "").trim(),
            };
        })
        .filter((tip) => tip.title.length > 0 && tip.description.length > 0)
        .slice(0, 6);
}

function sanitiseStrings(raw: unknown): string[] {
    if (!Array.isArray(raw)) return [];
    return raw
        .map((item) => String(item ?? "").trim())
        .filter((s) => s.length > 0)
        .slice(0, 4);
}

function sanitiseInsights(raw: unknown): CoachInsightOut[] {
    if (!Array.isArray(raw)) return [];
    return raw
        .map((row): CoachInsightOut | null => {
            const r = row as Record<string, unknown>;
            const tone = String(r.tone ?? "encouragement");
            const safeTone = ALLOWED_TONES.has(tone) ? tone : "encouragement";
            const headline = String(r.headline ?? "").trim();
            const body = String(r.body ?? "").trim();
            if (!headline || !body) return null;
            const action = String(r.actionKind ?? "");
            const safeAction = ALLOWED_ACTIONS.has(action) ? action : undefined;
            return {
                tone: safeTone,
                headline,
                body,
                actionTitle: typeof r.actionTitle === "string" ? r.actionTitle.trim() : undefined,
                actionKind: safeAction,
            };
        })
        .filter((row): row is CoachInsightOut => row !== null)
        .slice(0, 5);
}

function languageInstruction(locale?: string): string {
    switch ((locale ?? "en").toLowerCase().slice(0, 2)) {
        case "pl":
            return "Write all human-readable text in Polish. Headlines, bodies, action labels — Polish.";
        case "uk":
            return "Write all human-readable text in Ukrainian. Headlines, bodies, action labels — Ukrainian.";
        case "ru":
            return "Write all human-readable text in Russian. Headlines, bodies, action labels — Russian.";
        case "es":
            return "Write all human-readable text in Spanish. Headlines, bodies, action labels — Spanish.";
        case "en":
        default:
            return "Write all human-readable text in English.";
    }
}

function geminiErrorResponse(err: unknown, log: Logger, scope: string): Response {
    if (err instanceof GeminiError) {
        log.error(`coach ${scope} gemini failure`, { status: err.status });
        return problemResponse(err.status, "Coach upstream failure");
    }
    log.error(`coach ${scope} unexpected`, { err: String(err) });
    return problemResponse(500, "Coach internal error");
}
