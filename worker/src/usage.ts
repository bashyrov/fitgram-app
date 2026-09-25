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
 *   gemini-2.5-flash       in: $0.30 / 1M   out: $2.50 / 1M
 *   gemini-2.5-flash-lite  in: $0.10 / 1M   out: $0.40 / 1M
 *   gemini-2.5-pro         in: $1.25 / 1M   out: $10.00 / 1M
 *
 * Cache hits write `cached=1, cost_usd=0` so we can still count requests
 * but don't double-charge ourselves.
 */
const PRICE_PER_MILLION: Record<string, { input: number; output: number }> = {
    "gemini-2.5-flash": { input: 0.3, output: 2.5 },
    "gemini-2.5-flash-lite": { input: 0.1, output: 0.4 },
    "gemini-2.5-pro": { input: 1.25, output: 10.0 },
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
    reservationID?: string | undefined;
}

const FALLBACK_PRICE = { input: 0.3, output: 2.5 };
export const DAILY_AI_REQUEST_SAFETY_CAP = 60;
const FREE_DAILY_LIMITS: Partial<Record<AIQuotaKind, number>> = {
    ai_logged_meal: 3,
    ai_meal_refresh: 3,
    ai_product_nutrition: 2,
    // Free uses the local Ola Chef catalog. The Worker endpoint is Pro-only.
    ola_chef: 0,
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
        if (record.reservationID) {
            await db.prepare("DELETE FROM ai_quota_reservations WHERE id = ? AND user_id = ?")
                .bind(record.reservationID, record.userID)
                .run();
        }
    } catch (err) {
        log.error("usage write failed", { err: String(err) });
    }
}

export async function releaseAIQuotaReservation(
    env: Env,
    log: Logger,
    reservationID: string | undefined
): Promise<void> {
    if (!env.USAGE_DB || !reservationID) return;
    try {
        await env.USAGE_DB.prepare("DELETE FROM ai_quota_reservations WHERE id = ?")
            .bind(reservationID)
            .run();
    } catch (error) {
        log.warn("quota reservation release failed", { error: String(error) });
    }
}

export interface DailyAIQuotaCheck {
    allowed: boolean;
    used: number;
    cap: number;
    reason?: "safety" | "free_tier";
    reservationID?: string;
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
        const now = Date.now();
        const since = dayStartTimestamp(now, options.timeZoneOffsetMinutes);
        await db.prepare("DELETE FROM ai_quota_reservations WHERE expires_at_ms <= ?").bind(now).run();
        const safetyRow = await db
            .prepare(
                `SELECT
                    (SELECT COUNT(*) FROM ai_usage WHERE user_id = ? AND ts >= ?) +
                    (SELECT COUNT(*) FROM ai_quota_reservations WHERE user_id = ? AND ts >= ?)
                    AS requests`
            )
            .bind(userID, since, userID, since)
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

        letFeature: if (!options.isPremium && options.kind) {
            const cap = FREE_DAILY_LIMITS[options.kind];
            if (cap === undefined) {
                break letFeature;
            }
            const endpoints = endpointsForKind(options.kind);
            const placeholders = endpoints.map(() => "?").join(", ");
            const freeRow = await db
                .prepare(
                    `SELECT
                        (SELECT COUNT(*) FROM ai_usage
                         WHERE user_id = ? AND ts >= ? AND endpoint IN (${placeholders})) +
                        (SELECT COUNT(*) FROM ai_quota_reservations
                         WHERE user_id = ? AND ts >= ? AND quota_kind = ?)
                        AS requests`
                )
                .bind(userID, since, ...endpoints, userID, since, options.kind)
                .first<{ requests: number }>();
            const used = freeRow?.requests ?? 0;
            if (used >= cap) {
                return { allowed: false, used, cap, reason: "free_tier" };
            }
        }

        const reservationID = crypto.randomUUID();
        const kind = options.kind ?? "ai_draft_meal";
        const featureCap = !options.isPremium ? FREE_DAILY_LIMITS[kind] : undefined;
        const endpoints = endpointsForKind(kind);
        const placeholders = endpoints.map(() => "?").join(", ");
        const featureClause = featureCap === undefined
            ? "1 = 1"
            : `(
                (SELECT COUNT(*) FROM ai_usage
                 WHERE user_id = ? AND ts >= ? AND endpoint IN (${placeholders})) +
                (SELECT COUNT(*) FROM ai_quota_reservations
                 WHERE user_id = ? AND ts >= ? AND quota_kind = ?)
              ) < ?`;
        const bindings: unknown[] = [
            reservationID, now, now + 2 * 60 * 1000, userID, kind,
            userID, since, userID, since,
        ];
        if (featureCap !== undefined) {
            bindings.push(userID, since, ...endpoints, userID, since, kind, featureCap);
        }
        const reserved = await db.prepare(
            `INSERT INTO ai_quota_reservations (id, ts, expires_at_ms, user_id, quota_kind)
             SELECT ?, ?, ?, ?, ?
             WHERE (
                (SELECT COUNT(*) FROM ai_usage WHERE user_id = ? AND ts >= ?) +
                (SELECT COUNT(*) FROM ai_quota_reservations WHERE user_id = ? AND ts >= ?)
             ) < ${DAILY_AI_REQUEST_SAFETY_CAP}
             AND ${featureClause}`
        ).bind(...bindings).run();
        if ((reserved.meta.changes ?? 0) !== 1) {
            return {
                allowed: false,
                used: safetyUsed,
                cap: featureCap ?? DAILY_AI_REQUEST_SAFETY_CAP,
                reason: featureCap === undefined ? "safety" : "free_tier",
            };
        }
        return {
            allowed: true,
            used: safetyUsed,
            cap: featureCap ?? DAILY_AI_REQUEST_SAFETY_CAP,
            reservationID,
        };
    } catch (err) {
        log.error("usage quota check failed", { err: String(err), user: userID });
        return { allowed: true, used: 0, cap: DAILY_AI_REQUEST_SAFETY_CAP };
    }
}

export function timeZoneOffsetMinutesFromRequest(request: Request): number | undefined {
    const raw = request.headers.get("X-Fitgram-Time-Zone-Offset-Minutes");
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
            // Photo and voice share one three-use daily pool.
            return ["/api/v1/scan-food", "/api/v1/analyze-meal-text:ai_logged_meal"];
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
    byModel: UsageBreakdown[];
    byEndpoint: UsageBreakdown[];
    topUsers: UserUsageBreakdown[];
    daily: DailyUsageBreakdown[];
    generatedAt: number;
}

interface PeriodSlice {
    requests: number;
    costUSD: number;
    promptTokens: number;
    outputTokens: number;
    cachedRequests: number;
    activeUsers: number;
}

export interface UsageBreakdown {
    label: string;
    requests: number;
    promptTokens: number;
    outputTokens: number;
    costUSD: number;
    cachedRequests: number;
    averageDurationMs: number;
}

export interface UserUsageBreakdown extends Omit<UsageBreakdown, "label"> {
    user: string;
}

export interface DailyUsageBreakdown extends Omit<UsageBreakdown, "label"> {
    day: string;
}

export async function summarizeUsage(env: Env, log: Logger): Promise<UsageSummary> {
    const db = env.USAGE_DB;
    if (!db) {
        return emptySummary();
    }
    const now = Date.now();
    const day = 24 * 3600 * 1000;
    try {
        const [totals, last24, last7, last30, byModel, byEndpoint, topUsers, daily] = await Promise.all([
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
                    `SELECT model AS label, COUNT(*) AS requests,
                            COALESCE(SUM(prompt_tokens), 0) AS prompt_tokens,
                            COALESCE(SUM(output_tokens), 0) AS output_tokens,
                            COALESCE(SUM(cost_usd), 0) AS cost,
                            SUM(CASE WHEN cached = 1 THEN 1 ELSE 0 END) AS cached,
                            COALESCE(AVG(duration_ms), 0) AS avg_duration
                     FROM ai_usage
                     GROUP BY model ORDER BY cost DESC`
                )
                .all<RawBreakdown>(),
            db
                .prepare(
                    `SELECT endpoint AS label, COUNT(*) AS requests,
                            COALESCE(SUM(prompt_tokens), 0) AS prompt_tokens,
                            COALESCE(SUM(output_tokens), 0) AS output_tokens,
                            COALESCE(SUM(cost_usd), 0) AS cost,
                            SUM(CASE WHEN cached = 1 THEN 1 ELSE 0 END) AS cached,
                            COALESCE(AVG(duration_ms), 0) AS avg_duration
                     FROM ai_usage WHERE ts >= ?
                     GROUP BY endpoint ORDER BY cost DESC, requests DESC LIMIT 20`
                )
                .bind(now - 30 * day)
                .all<RawBreakdown>(),
            db
                .prepare(
                    `SELECT user_id AS label, COUNT(*) AS requests,
                            COALESCE(SUM(prompt_tokens), 0) AS prompt_tokens,
                            COALESCE(SUM(output_tokens), 0) AS output_tokens,
                            COALESCE(SUM(cost_usd), 0) AS cost,
                            SUM(CASE WHEN cached = 1 THEN 1 ELSE 0 END) AS cached,
                            COALESCE(AVG(duration_ms), 0) AS avg_duration
                     FROM ai_usage WHERE ts >= ?
                     GROUP BY user_id ORDER BY cost DESC, requests DESC LIMIT 20`
                )
                .bind(now - 30 * day)
                .all<RawBreakdown>(),
            db
                .prepare(
                    `SELECT date(ts / 1000, 'unixepoch') AS day,
                            COUNT(*) AS requests,
                            COALESCE(SUM(prompt_tokens), 0) AS prompt_tokens,
                            COALESCE(SUM(output_tokens), 0) AS output_tokens,
                            COALESCE(SUM(cost_usd), 0) AS cost,
                            SUM(CASE WHEN cached = 1 THEN 1 ELSE 0 END) AS cached,
                            COALESCE(AVG(duration_ms), 0) AS avg_duration
                     FROM ai_usage
                     WHERE ts >= ?
                     GROUP BY day ORDER BY day DESC`
                )
                .bind(now - 30 * day)
                .all<RawDailyBreakdown>(),
        ]);

        return {
            totalRequests: totals?.total ?? 0,
            cachedRequests: totals?.cached ?? 0,
            geminiRequests: totals?.gemini ?? 0,
            totalCostUSD: round(totals?.cost ?? 0),
            last24h: last24,
            last7d: last7,
            last30d: last30,
            byModel: (byModel.results ?? []).map(mapBreakdown),
            byEndpoint: (byEndpoint.results ?? []).map(mapBreakdown),
            topUsers: await Promise.all((topUsers.results ?? []).map(mapUserBreakdown)),
            daily: (daily.results ?? []).map((row) => ({
                day: row.day,
                ...mapBreakdown(row),
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
            `SELECT COUNT(*) AS requests,
                    COALESCE(SUM(cost_usd), 0) AS cost,
                    COALESCE(SUM(prompt_tokens), 0) AS prompt_tokens,
                    COALESCE(SUM(output_tokens), 0) AS output_tokens,
                    SUM(CASE WHEN cached = 1 THEN 1 ELSE 0 END) AS cached,
                    COUNT(DISTINCT user_id) AS active_users
             FROM ai_usage WHERE ts >= ?`
        )
        .bind(sinceTs)
        .first<RawPeriodSlice>();
    return {
        requests: row?.requests ?? 0,
        costUSD: round(row?.cost ?? 0),
        promptTokens: row?.prompt_tokens ?? 0,
        outputTokens: row?.output_tokens ?? 0,
        cachedRequests: row?.cached ?? 0,
        activeUsers: row?.active_users ?? 0,
    };
}

function emptySummary(): UsageSummary {
    const empty: PeriodSlice = {
        requests: 0, costUSD: 0, promptTokens: 0, outputTokens: 0,
        cachedRequests: 0, activeUsers: 0,
    };
    return {
        totalRequests: 0,
        cachedRequests: 0,
        geminiRequests: 0,
        totalCostUSD: 0,
        last24h: empty,
        last7d: empty,
        last30d: empty,
        byModel: [],
        byEndpoint: [],
        topUsers: [],
        daily: [],
        generatedAt: Date.now(),
    };
}

interface RawBreakdown {
    label: string;
    requests: number;
    prompt_tokens: number;
    output_tokens: number;
    cost: number;
    cached: number;
    avg_duration: number;
}

interface RawDailyBreakdown extends RawBreakdown {
    day: string;
}

interface RawPeriodSlice {
    requests: number;
    cost: number;
    prompt_tokens: number;
    output_tokens: number;
    cached: number;
    active_users: number;
}

function mapBreakdown(row: RawBreakdown): UsageBreakdown {
    return {
        label: row.label,
        requests: row.requests,
        promptTokens: row.prompt_tokens,
        outputTokens: row.output_tokens,
        costUSD: round(row.cost),
        cachedRequests: row.cached,
        averageDurationMs: Math.round(row.avg_duration),
    };
}

async function mapUserBreakdown(row: RawBreakdown): Promise<UserUsageBreakdown> {
    const breakdown = mapBreakdown(row);
    const { label: _, ...metrics } = breakdown;
    return { user: await pseudonymousUserID(row.label), ...metrics };
}

export async function pseudonymousUserID(userID: string): Promise<string> {
    const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(userID));
    const prefix = Array.from(new Uint8Array(digest).slice(0, 6))
        .map((byte) => byte.toString(16).padStart(2, "0"))
        .join("");
    return `user_${prefix}`;
}

function round(value: number): number {
    // 4 decimals so per-call costs (~$0.0001) still register on the
    // dashboard. Storage is full precision in D1; this only affects the
    // JSON response.
    return Math.round(value * 10_000) / 10_000;
}
