/// <reference types="@cloudflare/workers-types" />

export interface Env {
    // Secrets — set via `wrangler secret put`.
    SUPABASE_JWT_SECRET: string;
    GEMINI_API_KEY: string;
    UPSTASH_REDIS_URL: string;
    UPSTASH_REDIS_TOKEN: string;

    // Non-secret bindings.
    GEMINI_VISION_MODEL: string;
    GEMINI_PREMIUM_MODEL: string;
    CACHE_TTL_SECONDS: string;
    LOG_LEVEL: string;

    // Optional KV — falls back to in-memory when missing.
    SCAN_CACHE?: KVNamespace;
}
