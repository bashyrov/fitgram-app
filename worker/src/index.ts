/// <reference types="@cloudflare/workers-types" />

import { authenticate, AuthError } from "./auth";
import type { Env } from "./env";
import { makeLogger } from "./log";
import { problemResponse, jsonResponse } from "./responses";
import { handleScanFood } from "./scan-food";

/**
 * Cloudflare Worker entrypoint. Routes everything; auth + body parsing are
 * delegated to individual handlers so each route stays single-purpose.
 *
 * Routes
 *   GET  /healthz            → ping
 *   POST /api/v1/scan-food   → AI vision proxy (auth required)
 */
export default {
    async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
        const log = makeLogger(env.LOG_LEVEL);
        const url = new URL(request.url);
        try {
            if (url.pathname === "/healthz") {
                return jsonResponse({ status: "ok" });
            }
            if (url.pathname === "/api/v1/scan-food") {
                const auth = await authenticate(request, env);
                return await handleScanFood(request, env, log, auth);
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
