import { decodeJwt, importPKCS8, SignJWT } from "jose";

import type { AuthContext } from "./auth";
import type { Env } from "./env";
import type { Logger } from "./log";
import { jsonResponse, problemResponse } from "./responses";

const ALLOWED_PRODUCTS = new Set(["fitgram_premium_monthly", "fitgram_premium_yearly"]);

interface SyncRequest {
    transaction_id?: string;
}

interface AppleTransactionPayload {
    bundleId?: string;
    environment?: string;
    expiresDate?: number;
    originalTransactionId?: string;
    productId?: string;
    revocationDate?: number;
    transactionId?: string;
}

export async function handleSubscriptionSync(
    request: Request,
    env: Env,
    log: Logger,
    auth: AuthContext
): Promise<Response> {
    if (request.method !== "POST") return problemResponse(405, "Method not allowed");
    if (!env.USAGE_DB) return problemResponse(503, "Subscription storage is unavailable");

    const config = appStoreConfig(env);
    if (!config) return problemResponse(503, "App Store verification is not configured");

    let body: SyncRequest;
    try {
        body = await request.json<SyncRequest>();
    } catch {
        return problemResponse(400, "Invalid JSON body");
    }
    const transactionID = body.transaction_id?.trim();
    if (!transactionID || !/^\d{6,30}$/.test(transactionID)) {
        return problemResponse(400, "Invalid transaction identifier");
    }

    try {
        const token = await makeAppStoreToken(config);
        const signedInfo = await fetchSignedTransaction(transactionID, token);
        const payload = decodeJwt(signedInfo) as AppleTransactionPayload;
        const verified = validateTransaction(payload, config.bundleID);
        if (!verified.ok) return problemResponse(403, verified.reason);

        const result = await env.USAGE_DB.prepare(
            `INSERT INTO subscription_entitlements (
                user_id, original_transaction_id, latest_transaction_id,
                product_id, environment, expires_at_ms, revoked_at_ms, updated_at_ms
             ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
             ON CONFLICT(original_transaction_id) DO UPDATE SET
                latest_transaction_id = excluded.latest_transaction_id,
                product_id = excluded.product_id,
                environment = excluded.environment,
                expires_at_ms = excluded.expires_at_ms,
                revoked_at_ms = excluded.revoked_at_ms,
                updated_at_ms = excluded.updated_at_ms
             WHERE subscription_entitlements.user_id = excluded.user_id`
        )
            .bind(
                auth.userID,
                verified.originalTransactionID,
                verified.transactionID,
                verified.productID,
                verified.environment,
                verified.expiresAt,
                verified.revokedAt,
                Date.now()
            )
            .run();

        if ((result.meta.changes ?? 0) !== 1) {
            log.warn("subscription already belongs to another user", {
                user: auth.userID,
                originalTransactionID: verified.originalTransactionID,
            });
            return problemResponse(409, "Subscription is linked to another account");
        }

        return jsonResponse({
            is_premium: verified.revokedAt === null && verified.expiresAt > Date.now(),
            product_id: verified.productID,
            expires_at_ms: verified.expiresAt,
        });
    } catch (error) {
        log.error("App Store subscription sync failed", { user: auth.userID, error: String(error) });
        return problemResponse(502, "App Store verification is temporarily unavailable");
    }
}

function appStoreConfig(env: Env): {
    issuerID: string;
    keyID: string;
    privateKey: string;
    bundleID: string;
} | null {
    if (!env.APPLE_ISSUER_ID || !env.APPLE_KEY_ID || !env.APPLE_PRIVATE_KEY) return null;
    return {
        issuerID: env.APPLE_ISSUER_ID,
        keyID: env.APPLE_KEY_ID,
        privateKey: env.APPLE_PRIVATE_KEY.replace(/\\n/g, "\n"),
        bundleID: env.APPLE_BUNDLE_ID ?? "app.fitgram.ios.bashyrov",
    };
}

async function makeAppStoreToken(config: NonNullable<ReturnType<typeof appStoreConfig>>): Promise<string> {
    const key = await importPKCS8(config.privateKey, "ES256");
    return new SignJWT({ bid: config.bundleID })
        .setProtectedHeader({ alg: "ES256", kid: config.keyID, typ: "JWT" })
        .setIssuer(config.issuerID)
        .setAudience("appstoreconnect-v1")
        .setIssuedAt()
        .setExpirationTime("5m")
        .sign(key);
}

async function fetchSignedTransaction(transactionID: string, token: string): Promise<string> {
    const path = `/inApps/v1/transactions/${encodeURIComponent(transactionID)}`;
    for (const origin of ["https://api.storekit.apple.com", "https://api.storekit-sandbox.apple.com"]) {
        const response = await fetch(`${origin}${path}`, {
            headers: { Authorization: `Bearer ${token}`, Accept: "application/json" },
        });
        if (response.ok) {
            const body = await response.json<{ signedTransactionInfo?: string }>();
            if (!body.signedTransactionInfo) throw new Error("Apple response omitted transaction info");
            return body.signedTransactionInfo;
        }
        if (response.status !== 404) throw new Error(`Apple transaction API returned ${response.status}`);
    }
    throw new Error("Transaction not found in production or sandbox");
}

export function validateTransaction(
    payload: AppleTransactionPayload,
    bundleID: string
):
    | { ok: false; reason: string }
    | {
          ok: true;
          transactionID: string;
          originalTransactionID: string;
          productID: string;
          environment: string;
          expiresAt: number;
          revokedAt: number | null;
      } {
    if (payload.bundleId !== bundleID) return { ok: false, reason: "Transaction belongs to another app" };
    if (!payload.productId || !ALLOWED_PRODUCTS.has(payload.productId)) {
        return { ok: false, reason: "Unknown subscription product" };
    }
    if (!payload.transactionId || !payload.originalTransactionId || !payload.expiresDate) {
        return { ok: false, reason: "Incomplete transaction information" };
    }
    return {
        ok: true,
        transactionID: payload.transactionId,
        originalTransactionID: payload.originalTransactionId,
        productID: payload.productId,
        environment: payload.environment ?? "Unknown",
        expiresAt: payload.expiresDate,
        revokedAt: payload.revocationDate ?? null,
    };
}
