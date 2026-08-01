/// <reference types="@cloudflare/workers-types" />

import type { Env } from "./env";
import type { Logger } from "./log";

/**
 * Per-request accounting. Every Gemini call (and every cache hit that
 * shortcuts a Gemini call) writes one row into the `ai_usage` D1 table.
 *
 * Cost is computed from token counts using the published Gemini 2.5
 * pricing — keep this table in sync with whatever Google has live:
 *
 *   gemini-2.5-flash   in: $0.075 / 1M   out: $0.30 / 1M
 *   gemini-2.5-pro     in: $1.25  / 1M   out: $5.00 / 1M
 *
 * Cache hits write `cached=1, cost_usd=0` so we can still count requests
 * but don't double-charge ourselves.
 */
const PRICE_PER_MILLION: Record<string, { input: number; output: number }> = {
    "gemini-2.5-flash": { input: 0.075, output: 0.3 },
    "gemini-2.5-pro": { input: 1.25, output: 5.0 },
    // Fallback for older / variant model names.
    "gemini-1.5-flash": { input: 0.075, output: 0.3 },
    "gemini-1.5-pro": { input: 1.25, output: 5.0 },
};

export interface UsageRecord {
    userID: string;
    model: string;
    endpoint: string;
    promptTokens: number;
    outputTokens: number;
    cached: boolean;
    durationMs: number;
}

const FALLBACK_PRICE = { input: 0.075, output: 0.3 };
export const DAILY_AI_REQUEST_SAFETY_CAP = 60;
const FREE_DAILY_LIMITS: Partial<Record<AIQuotaKind, number>> = {
    ai_logged_meal: 3,
    ai_meal_refresh: 3,
    ai_product_nutrition: 2,
    ola_chef: 1,
    coach_debrief: 0,
};

export type AIQuotaKind =
    | "ai_draft_meal"
    | "ai_logged_meal"
    | "ai_meal_refresh"
    | "ai_product_nutrition"
    | "ola_chef"
    | "coach_debrief";

export function estimateCostUSD(
    model: string,
    promptTokens: number,
    outputTokens: number
): number {
    const price = PRICE_PER_MILLION[model] ?? FALLBACK_PRICE;
    const inputCost = (promptTokens / 1_000_000) * price.input;
    const outputCost = (outputTokens / 1_000_000) * price.output;
    // Round to 6 decimals; we get fractions of a cent per call.
    return Math.round((inputCost + outputCost) * 1_000_000) / 1_000_000;
}

/**
 * Best-effort write to the `ai_usage` table. Never throws — accounting
 * failures must not block the actual feature response.
 */
export async function recordUsage(env: Env, log: Logger, record: UsageRecord): Promise<void> {
    const db = env.USAGE_DB;
    if (!db) {
        log.warn("USAGE_DB binding missing — skipping usage write", {
            user: record.userID,
            endpoint: record.endpoint,
        });
        return;
    }
    const cost = record.cached
        ? 0
        : estimateCostUSD(record.model, record.promptTokens, record.outputTokens);
    try {
        await db
            .prepare(
                `INSERT INTO ai_usage (
                    ts, user_id, model, endpoint,
                    prompt_tokens, output_tokens, cost_usd, cached, duration_ms
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`
            )
            .bind(
                Date.now(),
                record.userID,
                record.model,
                record.endpoint,
                record.promptTokens,
                record.outputTokens,
                cost,
                record.cached ? 1 : 0,
                record.durationMs
            )
            .run();
    } catch (err) {
        log.error("usage write failed", { err: String(err) });
    }
}

export interface DailyAIQuotaCheck {
    allowed: boolean;
    used: number;
    cap: number;
    reason?: "safety" | "free_tier";
}

/**
 * Hard server-side abuse guard. App-side counters improve UX, but this is the
 * real cost protection for direct API calls or accidental request loops.
 */
export async function checkDailyAIQuota(
    env: Env,
    log: Logger,
    userID: string,
    options: {
        kind?: AIQuotaKind;
        isPremium?: boolean;
        timeZoneOffsetMinutes?: number | undefined;
    } = {}
): Promise<DailyAIQuotaCheck> {
    const db = env.USAGE_DB;
    if (!db) {
        log.warn("USAGE_DB binding missing — skipping AI quota check", { user: userID });
        return { allowed: true, used: 0, cap: DAILY_AI_REQUEST_SAFETY_CAP };
    }
    try {
        const since = dayStartTimestamp(Date.now(), options.timeZoneOffsetMinutes);
        const safetyRow = await db
            .prepare(
                `SELECT COUNT(*) AS requests
                 FROM ai_usage
                 WHERE user_id = ? AND ts >= ?`
            )
            .bind(userID, since)
            .first<{ requests: number }>();
        const safetyUsed = safetyRow?.requests ?? 0;
        if (safetyUsed >= DAILY_AI_REQUEST_SAFETY_CAP) {
            return {
                allowed: false,
                used: safetyUsed,
                cap: DAILY_AI_REQUEST_SAFETY_CAP,
                reason: "safety",
            };
        }

        if (!options.isPremium && options.kind) {
            const cap = FREE_DAILY_LIMITS[options.kind];
            if (cap === undefined) {
                return { allowed: true, used: safetyUsed, cap: DAILY_AI_REQUEST_SAFETY_CAP };
            }
            const endpoints = endpointsForKind(options.kind);
            const placeholders = endpoints.map(() => "?").join(", ");
            const freeRow = await db
                .prepare(
                    `SELECT COUNT(*) AS requests
                     FROM ai_usage
                     WHERE user_id = ? AND ts >= ? AND endpoint IN (${placeholders})`
                )
                .bind(userID, since, ...endpoints)
                .first<{ requests: number }>();
            const used = freeRow?.requests ?? 0;
            if (used >= cap) {
                return { allowed: false, used, cap, reason: "free_tier" };
            }
        }

        return { allowed: true, used: safetyUsed, cap: DAILY_AI_REQUEST_SAFETY_CAP };
    } catch (err) {
        log.error("usage quota check failed", { err: String(err), user: userID });
        return { allowed: true, used: 0, cap: DAILY_AI_REQUEST_SAFETY_CAP };
    }
}

export function timeZoneOffsetMinutesFromRequest(request: Request): number | undefined {
    const raw = request.headers.get("X-Mealgram-Time-Zone-Offset-Minutes");
    if (!raw) return undefined;
    const value = Number.parseInt(raw, 10);
    if (!Number.isFinite(value)) return undefined;
    return Math.max(-12 * 60, Math.min(14 * 60, value));
}

export function dayStartTimestamp(nowMs: number, offsetMinutes: number | undefined): number {
    if (offsetMinutes === undefined) {
        return nowMs - 24 * 3600 * 1000;
    }
    const offsetMs = offsetMinutes * 60 * 1000;
    const localNow = new Date(nowMs + offsetMs);
    return (
        Date.UTC(
            localNow.getUTCFullYear(),
            localNow.getUTCMonth(),
            localNow.getUTCDate()
        ) - offsetMs
    );
}

export function endpointsForKind(kind: AIQuotaKind): string[] {
    switch (kind) {
        case "ai_draft_meal":
            return ["/api/v1/scan-food", "/api/v1/analyze-meal-text:ai_draft_meal"];
        case "ai_logged_meal":
            return ["/api/v1/analyze-meal-text:ai_logged_meal"];
        case "ai_meal_refresh":
            return ["/api/v1/analyze-meal-text:ai_meal_refresh"];
        case "ai_product_nutrition":
            return ["/api/v1/analyze-meal-text:ai_product_nutrition"];
        case "ola_chef":
            return ["/api/v1/ola-chef/suggestions"];
        case "coach_debrief":
            return ["/api/v1/coach/weekly-debrief"];
    }
}

/**
 * Aggregated stats for the admin dashboard. Pulled from the `ai_usage`
 * table over the trailing window.
 */
export interface UsageSummary {
    totalRequests: number;
    cachedRequests: number;
    geminiRequests: number;
    totalCostUSD: number;
    last24h: PeriodSlice;
    last7d: PeriodSlice;
    last30d: PeriodSlice;
    byModel: { model: string; requests: number; costUSD: number }[];
    daily: { day: string; requests: number; costUSD: number }[];
    generatedAt: number;
}

interface PeriodSlice {
    requests: number;
    costUSD: number;
}

export async function summarizeUsage(env: Env, log: Logger): Promise<UsageSummary> {
    const db = env.USAGE_DB;
    if (!db) {
        return emptySummary();
    }
    const now = Date.now();
    const day = 24 * 3600 * 1000;
    try {
        const [totals, last24, last7, last30, byModel, daily] = await Promise.all([
            db
                .prepare(
                    `SELECT
                        COUNT(*) AS total,
                        SUM(CASE WHEN cached = 1 THEN 1 ELSE 0 END) AS cached,
                        SUM(CASE WHEN cached = 0 THEN 1 ELSE 0 END) AS gemini,
                        COALESCE(SUM(cost_usd), 0) AS cost
                     FROM ai_usage`
                )
                .first<{ total: number; cached: number; gemini: number; cost: number }>(),
            slice(db, now - day),
            slice(db, now - 7 * day),
            slice(db, now - 30 * day),
            db
                .prepare(
                    `SELECT model, COUNT(*) AS requests, COALESCE(SUM(cost_usd), 0) AS cost
                     FROM ai_usage
                     GROUP BY model ORDER BY cost DESC`
                )
                .all<{ model: string; requests: number; cost: number }>(),
            db
                .prepare(
                    `SELECT date(ts / 1000, 'unixepoch') AS day,
                            COUNT(*) AS requests,
                            COALESCE(SUM(cost_usd), 0) AS cost
                     FROM ai_usage
                     WHERE ts >= ?
                     GROUP BY day ORDER BY day DESC`
                )
                .bind(now - 30 * day)
                .all<{ day: string; requests: number; cost: number }>(),
        ]);

        return {
            totalRequests: totals?.total ?? 0,
            cachedRequests: totals?.cached ?? 0,
            geminiRequests: totals?.gemini ?? 0,
            totalCostUSD: round(totals?.cost ?? 0),
            last24h: last24,
            last7d: last7,
            last30d: last30,
            byModel: (byModel.results ?? []).map((r) => ({
                model: r.model,
                requests: r.requests,
                costUSD: round(r.cost),
            })),
            daily: (daily.results ?? []).map((r) => ({
                day: r.day,
                requests: r.requests,
                costUSD: round(r.cost),
            })),
            generatedAt: now,
        };
    } catch (err) {
        log.error("usage summary failed", { err: String(err) });
        return emptySummary();
    }
}

async function slice(db: D1Database, sinceTs: number): Promise<PeriodSlice> {
    const row = await db
        .prepare(
            `SELECT COUNT(*) AS requests, COALESCE(SUM(cost_usd), 0) AS cost
             FROM ai_usage WHERE ts >= ?`
        )
        .bind(sinceTs)
        .first<{ requests: number; cost: number }>();
    return {
        requests: row?.requests ?? 0,
        costUSD: round(row?.cost ?? 0),
    };
}

function emptySummary(): UsageSummary {
    const empty: PeriodSlice = { requests: 0, costUSD: 0 };
    return {
        totalRequests: 0,
        cachedRequests: 0,
        geminiRequests: 0,
        totalCostUSD: 0,
        last24h: empty,
        last7d: empty,
        last30d: empty,
        byModel: [],
        daily: [],
        generatedAt: Date.now(),
    };
}

function round(value: number): number {
    // 4 decimals so per-call costs (~$0.0001) still register on the
    // dashboard. Storage is full precision in D1; this only affects the
    // JSON response.
    return Math.round(value * 10_000) / 10_000;
}
