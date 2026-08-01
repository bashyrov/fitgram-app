/// <reference types="@cloudflare/workers-types" />

import { authenticate, AuthError, type AuthContext } from "./auth";
import type { Env } from "./env";
import { makeLogger } from "./log";
import { problemResponse, jsonResponse } from "./responses";
import { handleScanFood } from "./scan-food";
import { handleAnalyzeMealText } from "./analyze-meal-text";
import { handleOlaChefSuggestions } from "./ola-chef";
import { handleAdmin } from "./admin";
import {
    handleInitialRecommendations,
    handleDailyInsight,
    handleWeeklyDebrief,
} from "./coach";

/**
 * Cloudflare Worker entrypoint. Routes everything; auth + body parsing are
 * delegated to individual handlers so each route stays single-purpose.
 *
 * Routes
 *   GET  /healthz            → ping
 *   POST /api/v1/scan-food                        → Gemini vision (auth)
 *   POST /api/v1/analyze-meal-text                → Gemini text meal parsing (optional auth)
 *   POST /api/v1/ola-chef/suggestions             → AI meal ideas by target calories (optional auth)
 *   POST /api/v1/user/initial-recommendations     → Gemini text (auth)
 *   POST /api/v1/coach/daily-insight              → Gemini text (auth)
 *   POST /api/v1/coach/weekly-debrief             → Gemini text (auth)
 *   GET  /admin/usage                              → JSON cost + req stats
 *   GET  /admin/dashboard                          → same data, HTML
 */
/**
 * Helper for routes where auth is "best effort" — returns the verified
 * userID when the request carries a valid Bearer JWT, otherwise resolves
 * to null instead of throwing. Lets scan-food keep working for
 * DebugBypass / pre-signin onboarding while still attributing real
 * users in the AI usage dashboard.
 */
async function authenticateOptional(req: Request, env: Env): Promise<AuthContext | null> {
    const header = req.headers.get("Authorization") ?? "";
    if (!header.toLowerCase().startsWith("bearer ")) return null;
    try {
        return await authenticate(req, env);
    } catch {
        return null;
    }
}

export default {
    async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
        const log = makeLogger(env.LOG_LEVEL);
        const url = new URL(request.url);
        try {
            if (url.pathname === "/healthz") {
                return jsonResponse({ status: "ok" });
            }
            if (url.pathname.startsWith("/admin/")) {
                return await handleAdmin(request, env, log, url.pathname);
            }
            if (url.pathname === "/api/v1/scan-food") {
                // Auth is optional — DebugBypass / onboarding-time scans
                // arrive without a Supabase JWT. When the header is
                // present we still verify it so production users get
                // attributed correctly in the AI usage dashboard.
                const auth = (await authenticateOptional(request, env)) ?? {
                    userID: "anonymous",
                    isPremium: false,
                };
                return await handleScanFood(request, env, log, auth);
            }
            if (url.pathname === "/api/v1/analyze-meal-text") {
                const auth = (await authenticateOptional(request, env)) ?? {
                    userID: "anonymous",
                    isPremium: false,
                };
                return await handleAnalyzeMealText(request, env, log, auth);
            }
            if (url.pathname === "/api/v1/ola-chef/suggestions") {
                const auth = (await authenticateOptional(request, env)) ?? {
                    userID: "anonymous",
                    isPremium: false,
                };
                return await handleOlaChefSuggestions(request, env, log, auth);
            }
            if (url.pathname === "/api/v1/user/initial-recommendations") {
                // Onboarding happens pre-auth — accept anonymous traffic
                // but stamp the inbound `user_id` (if any) into the usage
                // table so the dashboard still attributes calls.
                return await handleInitialRecommendations(request, env, log);
            }
            if (url.pathname === "/api/v1/coach/daily-insight") {
                return await handleDailyInsight(request, env, log);
            }
            if (url.pathname === "/api/v1/coach/weekly-debrief") {
                return await handleWeeklyDebrief(request, env, log);
            }
            return problemResponse(404, "Not found", { path: url.pathname });
        } catch (err) {
            if (err instanceof AuthError) {
                return problemResponse(err.status, err.message);
            }
            log.error("Unhandled error", { err: String(err), stack: (err as Error).stack });
            return problemResponse(500, "Internal error");
        } finally {
            // ctx is unused today but kept here so handlers can call
            // `ctx.waitUntil(...)` for background telemetry without changing
            // the entrypoint signature.
            void ctx;
        }
    },
} satisfies ExportedHandler<Env>;
