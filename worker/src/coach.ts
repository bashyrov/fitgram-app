/// <reference types="@cloudflare/workers-types" />

import type { Env } from "./env";
import type { AuthContext } from "./auth";
import { generateJSON, GeminiError } from "./gemini";
import type { Logger } from "./log";
import { jsonResponse, problemResponse } from "./responses";
import {
    checkDailyAIQuota,
    recordUsage,
    releaseAIQuotaReservation,
    timeZoneOffsetMinutesFromRequest,
} from "./usage";

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
            reservationID: quota.reservationID,
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
        await releaseAIQuotaReservation(env, log, quota.reservationID);
        return geminiErrorResponse(err, log, "initial-recommendations");
    }
}

function buildInitialRecsPrompt(req: RecommendationsRequest): string {
    return [
        "You are Ola, the warm AI nutrition coach for the Fitgram iOS app.",
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
    goals: {
        calorieGoalKcal: number;
        proteinGoalGrams: number;
        carbsGoalGrams?: number;
        fatGoalGrams?: number;
        waterGoalMl?: number;
        goalKind?: string;
        dietMacroPreset?: string;
    };
    today: {
        caloriesKcal: number;
        proteinGrams: number;
        carbsGrams: number;
        fatGrams: number;
        entryCount: number;
        hasLoggedToday: boolean;
    };
    week: {
        startAt?: string;
        endAt?: string;
        dailyCalorieAverages: number[];
        dailyProteinAverages: number[];
        dailyWaterMl?: number[];
        workoutCalories?: number[];
        workoutMinutes?: number[];
        frequentFoods?: string[];
        daysWithAnyEntry: number;
        daysHittingProteinGoal: number;
        daysWithinCalorieGoal: number;
        bestCalorieDayOffset?: number | null;
        weakestProteinDayOffset?: number | null;
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
    memory?: {
        kind: string;
        summary: string;
        confidence: number;
    }[];
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

interface DailyPlanFocusOut {
    title: string;
    value: string;
    detail: string;
}

interface DailyPlanResponse {
    moment: "morning" | "midday" | "evening" | "overshoot";
    headline: string;
    body: string;
    todayGoal: string;
    firstMealSuggestion: string;
    risk?: string | null;
    focuses: DailyPlanFocusOut[];
}

export async function handleDailyInsight(
    request: Request,
    env: Env,
    log: Logger,
    auth: AuthContext
): Promise<Response> {
    if (request.method !== "POST") {
        return problemResponse(405, "Method not allowed");
    }
    if (!auth.isPremium) {
        return problemResponse(403, "Daily Ola AI requires Fitgram Pro");
    }
    let ctx: CoachContext;
    try {
        ctx = (await request.json()) as CoachContext;
    } catch {
        return problemResponse(400, "Bad JSON body");
    }

    const prompt = buildDailyInsightPrompt(ctx);
    const startedAt = Date.now();
    const userID = auth.userID;
    const quota = await checkDailyAIQuota(env, log, userID, {
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
            reservationID: quota.reservationID,
        });
        const out: DailyInsightResponse = {
            insights: sanitiseInsights(parsed.insights),
        };
        return jsonResponse(out);
    } catch (err) {
        await releaseAIQuotaReservation(env, log, quota.reservationID);
        return geminiErrorResponse(err, log, "daily-insight");
    }
}

function buildDailyInsightPrompt(ctx: CoachContext): string {
    return [
        "You are Ola, a warm AI nutrition coach inside Fitgram.",
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
        "- Use memory only when it clearly helps; do not expose it as stored data.",
    ].join("\n");
}

/** -------- /api/v1/coach/daily-plan -------- **/

export async function handleDailyPlan(
    request: Request,
    env: Env,
    log: Logger,
    auth: AuthContext
): Promise<Response> {
    if (request.method !== "POST") {
        return problemResponse(405, "Method not allowed");
    }
    if (!auth.isPremium) {
        return problemResponse(403, "Daily Ola AI requires Fitgram Pro");
    }
    let ctx: CoachContext;
    try {
        ctx = (await request.json()) as CoachContext;
    } catch {
        return problemResponse(400, "Bad JSON body");
    }

    const prompt = buildDailyPlanPrompt(ctx);
    const startedAt = Date.now();
    const userID = auth.userID;
    const quota = await checkDailyAIQuota(env, log, userID, {
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
    try {
        const { parsed, usage } = await generateJSON<DailyPlanResponse>(env, log, prompt, {
            premium: false,
            maxOutputTokens: 1400,
        });
        await recordUsage(env, log, {
            userID,
            model: usage.model,
            endpoint: "/api/v1/coach/daily-plan",
            promptTokens: usage.promptTokens,
            outputTokens: usage.outputTokens,
            cached: false,
            durationMs: Date.now() - startedAt,
            reservationID: quota.reservationID,
        });
        const out = sanitiseDailyPlan(parsed, ctx);
        return jsonResponse(out);
    } catch (err) {
        await releaseAIQuotaReservation(env, log, quota.reservationID);
        return geminiErrorResponse(err, log, "daily-plan");
    }
}

function buildDailyPlanPrompt(ctx: CoachContext): string {
    return [
        "You are Ola, the personal nutrition coach inside Fitgram.",
        "Create ONE daily plan for the user. This plan appears on the Home screen",
        "after the app opens in the morning and should feel personal, calm, and practical.",
        "Use the user's goal, macro preset, today totals, personal-week data, water,",
        "workouts, streak, weight trend, and frequent foods. Do not invent medical claims.",
        languageInstruction(ctx.locale),
        "",
        `Context: ${JSON.stringify(ctx)}`,
        "",
        "Return ONLY a JSON object matching this exact shape, no markdown:",
        "{",
        '  "moment": "morning|midday|evening|overshoot",',
        '  "headline": "≤8 words",',
        '  "body": "1-2 direct sentences, ≤34 words total",',
        '  "todayGoal": "one concrete sentence with kcal + protein target",',
        '  "firstMealSuggestion": "one concrete first meal idea matching the goal",',
        '  "risk": "one risk from yesterday/week OR null",',
        '  "focuses": [',
        '    {"title": "≤3 words", "value": "short number/text", "detail": "≤12 words"}',
        "  ]",
        "}",
        "Constraints:",
        "- Exactly 3 or 4 focuses.",
        "- Include calories and protein as focuses. Include water or activity when useful.",
        "- If today calories exceed target by 12%+, moment must be overshoot and body must be reassuring.",
        "- If protein is behind after midday, explicitly suggest a protein fix.",
        "- firstMealSuggestion must be food-specific, not generic.",
        "- risk should be concrete: low protein, low water, overshoot, no logging, weak consistency, or null.",
        "- Never mention that you are an AI model.",
    ].join("\n");
}

/** -------- /api/v1/coach/weekly-debrief -------- **/

interface WeeklyDebriefResponse {
    headline: string;
    sections?: WeeklyDebriefSectionOut[];
    nextWeekRules?: string[];
    insights: CoachInsightOut[];
}

interface WeeklyDebriefSectionOut {
    id?: string;
    title: string;
    body: string;
    symbol?: string;
}

export async function handleWeeklyDebrief(
    request: Request,
    env: Env,
    log: Logger,
    auth: AuthContext
): Promise<Response> {
    if (request.method !== "POST") {
        return problemResponse(405, "Method not allowed");
    }
    if (!auth.isPremium) {
        return problemResponse(403, "Weekly Ola AI requires Fitgram Pro");
    }
    let ctx: CoachContext;
    try {
        ctx = (await request.json()) as CoachContext;
    } catch {
        return problemResponse(400, "Bad JSON body");
    }

    const prompt = buildWeeklyDebriefPrompt(ctx);
    const startedAt = Date.now();
    const userID = auth.userID;
    const quota = await checkDailyAIQuota(env, log, userID, {
        kind: "coach_debrief",
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
            reservationID: quota.reservationID,
        });
        const out: WeeklyDebriefResponse = sanitiseWeeklyDebrief(parsed, ctx);
        return jsonResponse(out);
    } catch (err) {
        await releaseAIQuotaReservation(env, log, quota.reservationID);
        return geminiErrorResponse(err, log, "weekly-debrief");
    }
}

function buildWeeklyDebriefPrompt(ctx: CoachContext): string {
    return [
        "You are Ola, summarising the user's personal 7-day Fitgram week.",
        "Generate a deep but compact coach report: headline, 5-7 sections,",
        "3 practical rules for next week, and 3-5 actionable insights.",
        "Explain why weight changed, what worked, what blocked progress,",
        "where protein/water/calories/workouts slipped, which days were strong,",
        "and what pattern repeated. Speak directly to the user and pull numbers",
        "from the context. Use memory only if it makes advice more personal.",
        languageInstruction(ctx.locale),
        "",
        `Context: ${JSON.stringify(ctx)}`,
        "",
        "Return ONLY this JSON shape:",
        '{',
        '  "headline": "2-4 words capturing how the week went",',
        '  "sections": [',
        '    {"id": "weight|calories|protein|water|activity|pattern|plan", "title": "≤5 words", "body": "1-2 sentences ≤34 words", "symbol": "SF Symbol name"}',
        '  ],',
        '  "nextWeekRules": ["short concrete rule", "short concrete rule", "short concrete rule"],',
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
        "- 5-7 sections. Always include calories, protein, water, activity, pattern. Include weight if weight data exists.",
        "- Exactly 3 nextWeekRules.",
        "- SF symbols should be valid iOS names like scalemass.fill, flame.fill, drop.fill, figure.run.circle.fill.",
        "- Keep every human-readable string in the requested language.",
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

function sanitiseDailyPlan(raw: unknown, ctx: CoachContext): DailyPlanResponse {
    const r = (raw ?? {}) as Record<string, unknown>;
    const calorieGoal = safeRound(ctx.goals.calorieGoalKcal);
    const proteinGoal = safeRound(ctx.goals.proteinGoalGrams);
    const consumed = safeRound(ctx.today.caloriesKcal);
    const protein = safeRound(ctx.today.proteinGrams);
    const remaining = Math.max(0, calorieGoal - consumed);
    const moment = sanitiseMoment(r.moment, ctx);
    const focuses = sanitisePlanFocuses(r.focuses, [
        {
            title: "Calories",
            value: `${consumed} / ${calorieGoal}`,
            detail: `${remaining} kcal left`,
        },
        {
            title: "Protein",
            value: `${protein} / ${proteinGoal} g`,
            detail: `${Math.max(0, proteinGoal - protein)} g left`,
        },
        {
            title: "Water",
            value: `${todayWater(ctx)} / ${safeRound(ctx.goals.waterGoalMl ?? 2500)} ml`,
            detail: "Small glasses count too",
        },
    ]);
    return {
        moment,
        headline: cleanShortString(r.headline, fallbackHeadline(moment, ctx.locale), 80),
        body: cleanShortString(r.body, fallbackBody(moment, remaining, ctx.locale), 220),
        todayGoal: cleanShortString(
            r.todayGoal,
            localizedDailyGoal(ctx.locale, calorieGoal, proteinGoal),
            180
        ),
        firstMealSuggestion: cleanShortString(
            r.firstMealSuggestion,
            localizedFirstMeal(ctx.locale),
            180
        ),
        risk: cleanNullableString(r.risk, 180),
        focuses,
    };
}

function sanitiseWeeklyDebrief(raw: unknown, ctx: CoachContext): WeeklyDebriefResponse {
    const r = (raw ?? {}) as Record<string, unknown>;
    const headline = cleanShortString(r.headline, localizedWeeklyHeadline(ctx.locale), 80);
    const sections = sanitiseWeeklySections(r.sections, fallbackWeeklySections(ctx));
    const nextWeekRules = sanitiseWeeklyRules(r.nextWeekRules, fallbackWeeklyRules(ctx));
    return {
        headline,
        sections,
        nextWeekRules,
        insights: sanitiseInsights(r.insights),
    };
}

function sanitiseWeeklySections(raw: unknown, fallback: WeeklyDebriefSectionOut[]): WeeklyDebriefSectionOut[] {
    if (!Array.isArray(raw)) return fallback;
    const sections = raw
        .map((row): WeeklyDebriefSectionOut | null => {
            const r = row as Record<string, unknown>;
            const title = String(r.title ?? "").trim().slice(0, 70);
            const body = String(r.body ?? "").trim().slice(0, 240);
            if (!title || !body) return null;
            return {
                id: String(r.id ?? title).trim().slice(0, 40),
                title,
                body,
                symbol: safeSFSymbol(String(r.symbol ?? "")),
            };
        })
        .filter((row): row is WeeklyDebriefSectionOut => row !== null)
        .slice(0, 7);
    return sections.length >= 5 ? sections : fallback;
}

function sanitiseWeeklyRules(raw: unknown, fallback: string[]): string[] {
    if (!Array.isArray(raw)) return fallback;
    const rules = raw
        .map((row) => String(row ?? "").trim().slice(0, 140))
        .filter((row) => row.length > 0)
        .slice(0, 3);
    return rules.length === 3 ? rules : fallback;
}

function safeSFSymbol(raw: string): string {
    const value = raw.trim();
    if (/^[a-z0-9.]+$/i.test(value) && value.length <= 40) return value;
    return "sparkles";
}

function fallbackWeeklySections(ctx: CoachContext): WeeklyDebriefSectionOut[] {
    const lang = languageCode(ctx.locale);
    const avgCalories = avg(ctx.week.dailyCalorieAverages);
    const avgProtein = avg(ctx.week.dailyProteinAverages);
    const avgWater = avg(ctx.week.dailyWaterMl ?? []);
    const workoutMinutes = (ctx.week.workoutMinutes ?? []).reduce((sum, value) => sum + safeRound(value), 0);
    const foods = (ctx.week.frequentFoods ?? []).slice(0, 3).join(", ");
    const weightDelta = ctx.weight.deltaKg30Days;
    const sections: WeeklyDebriefSectionOut[] = [];
    if (typeof weightDelta === "number") {
        sections.push({
            id: "weight",
            title: localised(lang, "Waga", "Weight", "Вага", "Вес", "Peso"),
            body: localised(
                lang,
                `Zmiana 30 dni: ${weightDelta.toFixed(1)} kg. Patrzymy na trend, nie jeden pomiar.`,
                `30-day change: ${weightDelta.toFixed(1)} kg. We look at the trend, not one weigh-in.`,
                `Зміна за 30 днів: ${weightDelta.toFixed(1)} кг. Дивимось на тренд, не на один замір.`,
                `Изменение за 30 дней: ${weightDelta.toFixed(1)} кг. Смотрим на тренд, не на одно взвешивание.`,
                `Cambio en 30 días: ${weightDelta.toFixed(1)} kg. Miramos la tendencia, no una medición.`
            ),
            symbol: "scalemass.fill",
        });
    }
    sections.push(
        {
            id: "calories",
            title: localised(lang, "Kalorie", "Calories", "Калорії", "Калории", "Calorías"),
            body: localised(
                lang,
                `Średnio ${avgCalories} kcal. Dni blisko celu: ${ctx.week.daysWithinCalorieGoal}/7.`,
                `Average ${avgCalories} kcal. Days close to target: ${ctx.week.daysWithinCalorieGoal}/7.`,
                `У середньому ${avgCalories} ккал. Днів близько до цілі: ${ctx.week.daysWithinCalorieGoal}/7.`,
                `В среднем ${avgCalories} ккал. Дней близко к цели: ${ctx.week.daysWithinCalorieGoal}/7.`,
                `Media de ${avgCalories} kcal. Días cerca del objetivo: ${ctx.week.daysWithinCalorieGoal}/7.`
            ),
            symbol: "flame.fill",
        },
        {
            id: "protein",
            title: localised(lang, "Białko", "Protein", "Білок", "Белок", "Proteína"),
            body: localised(
                lang,
                `Średnio ${avgProtein} g. Cel trafiony w ${ctx.week.daysHittingProteinGoal}/7 dni.`,
                `Average ${avgProtein} g. Target hit on ${ctx.week.daysHittingProteinGoal}/7 days.`,
                `У середньому ${avgProtein} г. Ціль виконана у ${ctx.week.daysHittingProteinGoal}/7 днів.`,
                `В среднем ${avgProtein} г. Цель выполнена в ${ctx.week.daysHittingProteinGoal}/7 дней.`,
                `Media de ${avgProtein} g. Objetivo logrado ${ctx.week.daysHittingProteinGoal}/7 días.`
            ),
            symbol: "bolt.heart.fill",
        },
        {
            id: "water",
            title: localised(lang, "Woda", "Water", "Вода", "Вода", "Agua"),
            body: localised(
                lang,
                `Średnio ${avgWater} ml. Przenieś jedną szklankę wcześniej, jeśli wieczorem spada energia.`,
                `Average ${avgWater} ml. Move one glass earlier if energy drops in the evening.`,
                `У середньому ${avgWater} мл. Перенеси одну склянку раніше, якщо ввечері падає енергія.`,
                `В среднем ${avgWater} мл. Перенеси один стакан раньше, если вечером падает энергия.`,
                `Media de ${avgWater} ml. Mueve un vaso antes si baja la energía por la noche.`
            ),
            symbol: "drop.fill",
        },
        {
            id: "activity",
            title: localised(lang, "Ruch", "Activity", "Активність", "Активность", "Actividad"),
            body: localised(
                lang,
                `Trening: ${workoutMinutes} min. Ruch traktujemy jako wsparcie rytmu, nie karę.`,
                `Training: ${workoutMinutes} min. Movement supports rhythm; it is not punishment.`,
                `Тренування: ${workoutMinutes} хв. Рух підтримує ритм, це не покарання.`,
                `Тренировки: ${workoutMinutes} мин. Движение поддерживает ритм, это не наказание.`,
                `Entrenamiento: ${workoutMinutes} min. El movimiento apoya el ritmo, no castiga.`
            ),
            symbol: "figure.run.circle.fill",
        },
        {
            id: "pattern",
            title: localised(lang, "Wzorzec", "Pattern", "Патерн", "Паттерн", "Patrón"),
            body: localised(
                lang,
                foods ? `Najczęściej: ${foods}. Powtarzalne posiłki ułatwiają kontrolę.` : "Za mało powtórek, żeby widzieć silny wzorzec.",
                foods ? `Most frequent: ${foods}. Repeatable meals make control easier.` : "Not enough repeated meals to see a strong pattern.",
                foods ? `Найчастіше: ${foods}. Повторювані страви полегшують контроль.` : "Замало повторів, щоб побачити сильний патерн.",
                foods ? `Чаще всего: ${foods}. Повторяемые блюда упрощают контроль.` : "Мало повторов, чтобы увидеть сильный паттерн.",
                foods ? `Más frecuente: ${foods}. Las comidas repetibles facilitan el control.` : "No hay suficientes comidas repetidas para ver un patrón fuerte."
            ),
            symbol: "point.3.connected.trianglepath.dotted",
        }
    );
    return sections.slice(0, 7);
}

function fallbackWeeklyRules(ctx: CoachContext): string[] {
    const lang = languageCode(ctx.locale);
    const proteinRule = ctx.week.daysHittingProteinGoal < 5
        ? localised(lang, "Zacznij dzień od 25-35 g białka.", "Start the day with 25-35 g protein.", "Починай день з 25-35 г білка.", "Начинай день с 25-35 г белка.", "Empieza el día con 25-35 g de proteína.")
        : localised(lang, "Powtórz białkowy rytm z najlepszych dni.", "Repeat the protein rhythm from your best days.", "Повтори білковий ритм найкращих днів.", "Повтори белковый ритм лучших дней.", "Repite el ritmo de proteína de tus mejores días.");
    const calorieRule = ctx.week.daysWithinCalorieGoal < 4
        ? localised(lang, "Trzymaj spokojny zakres kalorii, nie perfekcję.", "Hold a calm calorie range, not perfection.", "Тримай спокійний діапазон калорій, не ідеал.", "Держи спокойный диапазон калорий, не идеал.", "Mantén un rango de calorías, no perfección.")
        : localised(lang, "Skopiuj strukturę dni blisko celu.", "Copy the structure of days close to target.", "Скопіюй структуру днів близько до цілі.", "Скопируй структуру дней близко к цели.", "Copia la estructura de los días cerca del objetivo.");
    const waterRule = localised(lang, "Jedna szklanka wody przed południem.", "One glass of water before noon.", "Одна склянка води до полудня.", "Один стакан воды до полудня.", "Un vaso de agua antes del mediodía.");
    return [proteinRule, calorieRule, waterRule];
}

function localizedWeeklyHeadline(locale?: string): string {
    const lang = languageCode(locale);
    return localised(lang, "Twój tydzień", "Your week", "Твій тиждень", "Твоя неделя", "Tu semana");
}

function avg(values: number[]): number {
    if (!Array.isArray(values) || values.length === 0) return 0;
    return safeRound(values.reduce((sum, value) => sum + safeRound(value), 0) / values.length);
}

function sanitisePlanFocuses(raw: unknown, fallback: DailyPlanFocusOut[]): DailyPlanFocusOut[] {
    if (!Array.isArray(raw)) return fallback;
    const focuses = raw
        .map((row): DailyPlanFocusOut | null => {
            const r = row as Record<string, unknown>;
            const title = String(r.title ?? "").trim().slice(0, 40);
            const value = String(r.value ?? "").trim().slice(0, 40);
            const detail = String(r.detail ?? "").trim().slice(0, 90);
            if (!title || !value || !detail) return null;
            return { title, value, detail };
        })
        .filter((row): row is DailyPlanFocusOut => row !== null)
        .slice(0, 4);
    return focuses.length >= 3 ? focuses : fallback;
}

function sanitiseMoment(raw: unknown, ctx: CoachContext): DailyPlanResponse["moment"] {
    const value = String(raw ?? "");
    if (["morning", "midday", "evening", "overshoot"].includes(value)) {
        return value as DailyPlanResponse["moment"];
    }
    if (ctx.goals.calorieGoalKcal > 0 && ctx.today.caloriesKcal >= ctx.goals.calorieGoalKcal * 1.12) {
        return "overshoot";
    }
    if (ctx.hourOfDay < 12) return "morning";
    if (ctx.hourOfDay < 18) return "midday";
    return "evening";
}

function cleanShortString(raw: unknown, fallback: string, maxLength: number): string {
    const value = String(raw ?? "").trim();
    return (value || fallback).slice(0, maxLength);
}

function cleanNullableString(raw: unknown, maxLength: number): string | null {
    if (raw === null || raw === undefined) return null;
    const value = String(raw).trim();
    return value ? value.slice(0, maxLength) : null;
}

function safeRound(value: number): number {
    return Number.isFinite(value) ? Math.round(value) : 0;
}

function todayWater(ctx: CoachContext): number {
    const water = ctx.week.dailyWaterMl;
    if (!Array.isArray(water) || water.length === 0) return 0;
    return safeRound(water[Math.min(water.length - 1, 6)] ?? 0);
}

function fallbackHeadline(moment: DailyPlanResponse["moment"], locale?: string): string {
    const lang = languageCode(locale);
    switch (moment) {
        case "morning":
            return localised(lang, "Plan na dziś", "Your plan for today", "План на сьогодні", "План на сегодня", "Plan de hoy");
        case "midday":
            return localised(lang, "Trzymaj rytm", "Keep the rhythm", "Тримай ритм", "Держим ритм", "Mantén el ritmo");
        case "evening":
            return localised(lang, "Lekki wieczór", "Light evening", "Легкий вечір", "Легкий вечер", "Noche ligera");
        case "overshoot":
            return localised(lang, "Bez paniki", "No panic", "Без паніки", "Без паники", "Sin pánico");
    }
}

function fallbackBody(moment: DailyPlanResponse["moment"], remaining: number, locale?: string): string {
    const lang = languageCode(locale);
    switch (moment) {
        case "morning":
            return localised(
                lang,
                "Zacznij od białka, wtedy łatwiej poprowadzić dzień.",
                "Start with protein and keep the day easy to steer.",
                "Почни з білка, так день легше тримати під контролем.",
                "Начни с белка, так день проще держать под контролем.",
                "Empieza con proteína y será más fácil dirigir el día."
            );
        case "midday":
            return localised(
                lang,
                "Wybierz prosty kolejny posiłek i zamknij największą lukę.",
                "Choose a simple next meal and close the biggest gap first.",
                "Обери простий наступний прийом їжі й закрий найбільший пробіл.",
                "Выбери простой следующий прием пищи и закрой главный пробел.",
                "Elige una comida simple y cierra primero la brecha principal."
            );
        case "evening":
            return localised(
                lang,
                `Zostało ${remaining} kcal. Lekka kolacja wystarczy.`,
                `${remaining} kcal left. A light dinner is enough.`,
                `Залишилось ${remaining} ккал. Легкої вечері достатньо.`,
                `Осталось ${remaining} ккал. Легкого ужина достаточно.`,
                `Quedan ${remaining} kcal. Una cena ligera basta.`
            );
        case "overshoot":
            return localised(
                lang,
                "Jutro wróć do normalnego celu; nie tnij agresywnie.",
                "Return to the normal target tomorrow; do not overcorrect.",
                "Завтра повернись до звичайної цілі; не урізай різко.",
                "Завтра вернись к обычной цели; не режь резко.",
                "Mañana vuelve al objetivo normal; no recortes de golpe."
            );
    }
}

function localizedDailyGoal(locale: string | undefined, kcal: number, protein: number): string {
    const lang = languageCode(locale);
    return localised(
        lang,
        `Dzisiaj trzymamy ${kcal} kcal i celujemy w ${protein} g białka.`,
        `Today we keep ${kcal} kcal and aim for ${protein} g protein.`,
        `Сьогодні тримаємо ${kcal} ккал і ціль ${protein} г білка.`,
        `Сегодня держим ${kcal} ккал и цель ${protein} г белка.`,
        `Hoy mantenemos ${kcal} kcal y buscamos ${protein} g de proteína.`
    );
}

function localizedFirstMeal(locale?: string): string {
    const lang = languageCode(locale);
    return localised(
        lang,
        "Pierwszy posiłek: białko + warzywa albo owoce.",
        "First meal: protein plus vegetables or fruit.",
        "Перший прийом: білок + овочі або фрукти.",
        "Первый прием: белок + овощи или фрукты.",
        "Primera comida: proteína con verduras o fruta."
    );
}

function languageCode(locale?: string): string {
    return (locale ?? "en").toLowerCase().slice(0, 2);
}

function localised(lang: string, pl: string, en: string, uk: string, ru: string, es: string): string {
    switch (lang) {
        case "pl":
            return pl;
        case "uk":
            return uk;
        case "ru":
            return ru;
        case "es":
            return es;
        default:
            return en;
    }
}

function languageInstruction(locale?: string): string {
    switch (languageCode(locale)) {
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
