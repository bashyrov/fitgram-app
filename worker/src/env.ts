/// <reference types="@cloudflare/workers-types" />

export interface Env {
    // Secrets — set via `wrangler secret put`.
    SUPABASE_JWT_SECRET?: string; // legacy HS256 fallback
    SUPABASE_URL?: string; // e.g. https://xyz.supabase.co — required for JWKS verification
    GEMINI_API_KEY?: string;
    ANTHROPIC_API_KEY?: string;
    ANTHROPIC_BASE_URL?: string;
    ANTHROPIC_AUTH_MODE?: string;
    AI_PROVIDER?: string;
    UPSTASH_REDIS_URL: string;
    UPSTASH_REDIS_TOKEN: string;

    // Non-secret bindings.
    GEMINI_VISION_MODEL: string;
    GEMINI_PREMIUM_MODEL: string;
    CLAUDE_TEXT_MODEL: string;
    CLAUDE_VISION_MODEL: string;
    CACHE_TTL_SECONDS: string;
    LOG_LEVEL: string;

    // Optional KV — falls back to in-memory when missing.
    SCAN_CACHE?: KVNamespace;

    // Optional D1 — accounting falls silent if not bound. Provisioned via
    // `wrangler d1 create mealgram-usage`. See worker/migrations/0001_ai_usage.sql.
    USAGE_DB?: D1Database;

    // Shared secret for GET /admin/usage. Set via `wrangler secret put ADMIN_TOKEN`.
    ADMIN_TOKEN?: string;
}
