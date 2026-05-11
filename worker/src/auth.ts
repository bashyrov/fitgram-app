import { jwtVerify } from "jose";

import type { Env } from "./env";

export interface AuthContext {
    userID: string;
}

/**
 * Verifies the Supabase-issued JWT carried in `Authorization: Bearer <token>`.
 * Supabase signs JWTs with HS256 using the project's JWT secret (visible
 * under Settings → API). We never trust the token without verification —
 * forged JWTs would otherwise leak the AI proxy quota.
 */
export async function authenticate(req: Request, env: Env): Promise<AuthContext> {
    const header = req.headers.get("Authorization") ?? "";
    if (!header.toLowerCase().startsWith("bearer ")) {
        throw new AuthError(401, "Missing bearer token");
    }
    const token = header.slice(7).trim();
    if (!token) throw new AuthError(401, "Empty bearer token");
    if (!env.SUPABASE_JWT_SECRET) {
        throw new AuthError(500, "SUPABASE_JWT_SECRET not configured");
    }

    const secret = new TextEncoder().encode(env.SUPABASE_JWT_SECRET);
    try {
        const { payload } = await jwtVerify(token, secret, {
            algorithms: ["HS256"],
        });
        const userID =
            typeof payload.sub === "string"
                ? payload.sub
                : typeof payload["user_id"] === "string"
                  ? (payload["user_id"] as string)
                  : null;
        if (!userID) throw new AuthError(401, "JWT missing user identifier");
        return { userID };
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
