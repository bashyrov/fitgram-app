import { jwtVerify, createRemoteJWKSet, type JWTPayload } from "jose";

import type { Env } from "./env";

export interface AuthContext {
    userID: string;
    isPremium: boolean;
}

type JWKSResolver = ReturnType<typeof createRemoteJWKSet>;
let cachedJWKS: { url: string; jwks: JWKSResolver } | null = null;

function getJWKS(supabaseURL: string): JWKSResolver {
    const jwksURL = `${supabaseURL.replace(/\/$/, "")}/auth/v1/.well-known/jwks.json`;
    if (cachedJWKS && cachedJWKS.url === jwksURL) return cachedJWKS.jwks;
    const jwks = createRemoteJWKSet(new URL(jwksURL));
    cachedJWKS = { url: jwksURL, jwks };
    return jwks;
}

function extractUserID(payload: JWTPayload): string | null {
    if (typeof payload.sub === "string") return payload.sub;
    const userId = payload["user_id"];
    return typeof userId === "string" ? userId : null;
}

function extractPremium(payload: JWTPayload): boolean {
    const direct = payload["is_premium"] ?? payload["premium"] ?? payload["pro"];
    if (direct === true || direct === "true" || direct === 1) return true;

    const appMetadata = payload["app_metadata"];
    if (isRecord(appMetadata)) {
        const nested = appMetadata["is_premium"] ?? appMetadata["premium"] ?? appMetadata["pro"];
        if (nested === true || nested === "true" || nested === 1) return true;
        const entitlements = appMetadata["entitlements"];
        if (isRecord(entitlements)) {
            const premium = entitlements["premium"] ?? entitlements["pro"];
            if (premium === true || premium === "true" || premium === 1) return true;
        }
    }

    const userMetadata = payload["user_metadata"];
    if (isRecord(userMetadata)) {
        const nested = userMetadata["is_premium"] ?? userMetadata["premium"] ?? userMetadata["pro"];
        if (nested === true || nested === "true" || nested === 1) return true;
    }
    return false;
}

function isRecord(value: unknown): value is Record<string, unknown> {
    return typeof value === "object" && value !== null;
}

/**
 * Verifies the Supabase-issued JWT carried in `Authorization: Bearer <token>`.
 * Prefers JWKS (modern ECC keys) when `SUPABASE_URL` is set; falls back to
 * the legacy HS256 shared secret when `SUPABASE_JWT_SECRET` is set instead.
 * We never trust the token without verification.
 */
export async function authenticate(req: Request, env: Env): Promise<AuthContext> {
    const header = req.headers.get("Authorization") ?? "";
    if (!header.toLowerCase().startsWith("bearer ")) {
        throw new AuthError(401, "Missing bearer token");
    }
    const token = header.slice(7).trim();
    if (!token) throw new AuthError(401, "Empty bearer token");

    try {
        if (env.SUPABASE_URL) {
            const jwks = getJWKS(env.SUPABASE_URL);
            const { payload } = await jwtVerify(token, jwks);
            const userID = extractUserID(payload);
            if (!userID) throw new AuthError(401, "JWT missing user identifier");
            return { userID, isPremium: extractPremium(payload) };
        }
        if (env.SUPABASE_JWT_SECRET) {
            const secret = new TextEncoder().encode(env.SUPABASE_JWT_SECRET);
            const { payload } = await jwtVerify(token, secret, { algorithms: ["HS256"] });
            const userID = extractUserID(payload);
            if (!userID) throw new AuthError(401, "JWT missing user identifier");
            return { userID, isPremium: extractPremium(payload) };
        }
        throw new AuthError(500, "Neither SUPABASE_URL nor SUPABASE_JWT_SECRET configured");
    } catch (err) {
        if (err instanceof AuthError) throw err;
        throw new AuthError(401, `Invalid token: ${(err as Error).message}`);
    }
}

export class AuthError extends Error {
    constructor(
        public status: number,
        message: string
    ) {
        super(message);
        this.name = "AuthError";
    }
}
