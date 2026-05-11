import type { Env } from "./env";

/**
 * Image-hash keyed cache so repeat scans of the same plate don't re-bill us
 * for Gemini. KV first (durable across cold starts); Upstash Redis as the
 * shared cross-region fallback. If neither is configured we no-op so dev
 * builds still work.
 */
export interface CacheRepository {
    get<T>(key: string): Promise<T | null>;
    set<T>(key: string, value: T, ttlSeconds: number): Promise<void>;
}

class KvCache implements CacheRepository {
    constructor(private kv: KVNamespace) {}
    async get<T>(key: string): Promise<T | null> {
        return (await this.kv.get<T>(key, "json")) ?? null;
    }
    async set<T>(key: string, value: T, ttlSeconds: number): Promise<void> {
        await this.kv.put(key, JSON.stringify(value), { expirationTtl: ttlSeconds });
    }
}

class UpstashCache implements CacheRepository {
    constructor(
        private url: string,
        private token: string
    ) {}
    async get<T>(key: string): Promise<T | null> {
        const response = await fetch(`${this.url}/get/${encodeURIComponent(key)}`, {
            headers: { Authorization: `Bearer ${this.token}` },
        });
        if (!response.ok) return null;
        const payload = (await response.json()) as { result?: string | null };
        if (!payload.result) return null;
        try {
            return JSON.parse(payload.result) as T;
        } catch {
            return null;
        }
    }
    async set<T>(key: string, value: T, ttlSeconds: number): Promise<void> {
        const url = `${this.url}/setex/${encodeURIComponent(key)}/${ttlSeconds}/${encodeURIComponent(
            JSON.stringify(value)
        )}`;
        await fetch(url, {
            method: "POST",
            headers: { Authorization: `Bearer ${this.token}` },
        });
    }
}

class NoopCache implements CacheRepository {
    async get<T>(): Promise<T | null> {
        return null;
    }
    async set(): Promise<void> {}
}

export function pickCache(env: Env): CacheRepository {
    if (env.SCAN_CACHE) return new KvCache(env.SCAN_CACHE);
    if (env.UPSTASH_REDIS_URL && env.UPSTASH_REDIS_TOKEN) {
        return new UpstashCache(env.UPSTASH_REDIS_URL, env.UPSTASH_REDIS_TOKEN);
    }
    return new NoopCache();
}

/** SHA-256 over the raw image bytes — deterministic key for the cache. */
export async function imageHash(bytes: ArrayBuffer): Promise<string> {
    const digest = await crypto.subtle.digest("SHA-256", bytes);
    return Array.from(new Uint8Array(digest))
        .map((b) => b.toString(16).padStart(2, "0"))
        .join("");
}
