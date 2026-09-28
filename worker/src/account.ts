import { importPKCS8, SignJWT } from "jose";

import type { AuthContext } from "./auth";
import type { Env } from "./env";
import type { Logger } from "./log";
import { jsonResponse, problemResponse } from "./responses";

/** Worker-side tables keyed by the signed-in user's id. */
export const ACCOUNT_TABLES = ["subscription_entitlements", "ai_quota_reservations", "ai_usage"] as const;

interface DeleteAccountRequest {
    /** Fresh Sign in with Apple authorization code, sent only by Apple users. */
    apple_authorization_code?: string;
}

export type AppleRevocationResult = "revoked" | "not_requested" | "not_configured" | "failed";

/**
 * DELETE /api/v1/account — removes everything the Worker stores for the
 * user and, for Sign in with Apple accounts, revokes the Apple tokens
 * (App Store Review Guideline 5.1.1(v)). Supabase data is removed
 * separately by the `account` Edge Function.
 */
export async function handleDeleteAccount(
    request: Request,
    env: Env,
    log: Logger,
    auth: AuthContext,
    fetcher: typeof fetch = fetch
): Promise<Response> {
    if (request.method !== "DELETE") return problemResponse(405, "Method not allowed");

    let body: DeleteAccountRequest = {};
    const raw = await request.text();
    if (raw.trim()) {
        try {
            body = JSON.parse(raw) as DeleteAccountRequest;
        } catch {
            return problemResponse(400, "Bad JSON body");
        }
    }

    const deleted = await deleteWorkerRows(env, auth.userID);
    if (deleted === null) {
        log.error("Account row deletion failed", { user: auth.userID });
        return problemResponse(500, "Failed to delete account data");
    }

    const apple = await revokeAppleTokens(env, log, body.apple_authorization_code, fetcher);
    log.info("Account deleted", { rows: deleted, apple });
    return jsonResponse({ ok: true, deleted_rows: deleted, apple_revocation: apple });
}

/** Deletes the user's rows from every Worker table; null when D1 fails. */
export async function deleteWorkerRows(env: Env, userID: string): Promise<number | null> {
    if (!env.USAGE_DB) return 0;
    try {
        const results = await env.USAGE_DB.batch(
            ACCOUNT_TABLES.map((table) => env.USAGE_DB!.prepare(`DELETE FROM ${table} WHERE user_id = ?`).bind(userID))
        );
        return results.reduce((sum, result) => sum + (result.meta?.changes ?? 0), 0);
    } catch {
        return null;
    }
}

/**
 * Exchanges the authorization code for a refresh token and revokes it, which
 * unlinks the app from the user's Apple ID. Needs a Sign in with Apple key
 * (APPLE_SIWA_KEY_ID / APPLE_SIWA_PRIVATE_KEY) — not the In-App Purchase key.
 * Never blocks deletion: failures are reported back, data is already gone.
 */
export async function revokeAppleTokens(
    env: Env,
    log: Logger,
    authorizationCode: string | undefined,
    fetcher: typeof fetch = fetch
): Promise<AppleRevocationResult> {
    const code = authorizationCode?.trim();
    if (!code) return "not_requested";
    const teamID = env.APPLE_TEAM_ID;
    const keyID = env.APPLE_SIWA_KEY_ID;
    const privateKey = env.APPLE_SIWA_PRIVATE_KEY;
    const clientID = env.APPLE_BUNDLE_ID ?? "app.fitgram.ios.bashyrov";
    if (!teamID || !keyID || !privateKey) {
        log.warn("Sign in with Apple revocation skipped: key not configured");
        return "not_configured";
    }

    try {
        const clientSecret = await appleClientSecret(teamID, keyID, privateKey, clientID);
        const tokenResponse = await fetcher("https://appleid.apple.com/auth/token", {
            method: "POST",
            headers: { "Content-Type": "application/x-www-form-urlencoded" },
            body: new URLSearchParams({
                client_id: clientID,
                client_secret: clientSecret,
                code,
                grant_type: "authorization_code",
            }),
        });
        if (!tokenResponse.ok) {
            log.warn("Apple code exchange failed", { status: tokenResponse.status });
            return "failed";
        }
        const tokens = (await tokenResponse.json()) as { refresh_token?: string; access_token?: string };
        const token = tokens.refresh_token ?? tokens.access_token;
        if (!token) return "failed";

        const revokeResponse = await fetcher("https://appleid.apple.com/auth/revoke", {
            method: "POST",
            headers: { "Content-Type": "application/x-www-form-urlencoded" },
            body: new URLSearchParams({
                client_id: clientID,
                client_secret: clientSecret,
                token,
                token_type_hint: tokens.refresh_token ? "refresh_token" : "access_token",
            }),
        });
        if (!revokeResponse.ok) {
            log.warn("Apple token revoke failed", { status: revokeResponse.status });
            return "failed";
        }
        return "revoked";
    } catch (err) {
        log.warn("Apple token revocation error", { err: String(err) });
        return "failed";
    }
}

async function appleClientSecret(
    teamID: string,
    keyID: string,
    privateKey: string,
    clientID: string
): Promise<string> {
    const key = await importPKCS8(privateKey.replace(/\\n/g, "\n"), "ES256");
    return new SignJWT({})
        .setProtectedHeader({ alg: "ES256", kid: keyID })
        .setIssuer(teamID)
        .setSubject(clientID)
        .setAudience("https://appleid.apple.com")
        .setIssuedAt()
        .setExpirationTime("5m")
        .sign(key);
}
