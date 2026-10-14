import { describe, expect, it } from "vitest";

import type { Env } from "./env";
import { makeLogger } from "./log";
import { mirrorPremiumToSupabase, validateTransaction } from "./subscriptions";

const valid = {
    bundleId: "app.fitgram.ios.bashyrov",
    environment: "Sandbox",
    expiresDate: Date.now() + 86_400_000,
    originalTransactionId: "200000000000001",
    productId: "fitgram_premium_monthly",
    transactionId: "200000000000002",
};

describe("App Store entitlement validation", () => {
    it("accepts a known Fitgram subscription", () => {
        expect(validateTransaction(valid, valid.bundleId)).toMatchObject({
            ok: true,
            productID: "fitgram_premium_monthly",
        });
    });

    it("rejects another app and unknown products", () => {
        expect(validateTransaction({ ...valid, bundleId: "com.other.app" }, valid.bundleId).ok)
            .toBe(false);
        expect(validateTransaction({ ...valid, productId: "fake_pro" }, valid.bundleId).ok)
            .toBe(false);
    });
});

describe("Premium mirror to Supabase", () => {
    const log = makeLogger("error");
    const userID = "3f0c5a52-7c1e-4a9b-9f43-0d6d3a5f1b22";
    const env = {
        SUPABASE_URL: "https://project.supabase.co/",
        SUPABASE_SERVICE_ROLE_KEY: "service-key",
    } as Env;

    it("patches premium_until with the service role key", async () => {
        const calls: { url: string; init: RequestInit }[] = [];
        const fetcher = (async (url: string, init: RequestInit) => {
            calls.push({ url, init });
            return new Response(null, { status: 204 });
        }) as unknown as typeof fetch;
        const expires = Date.UTC(2027, 0, 1);

        expect(await mirrorPremiumToSupabase(env, log, userID, expires, fetcher)).toBe(true);
        expect(calls).toHaveLength(1);
        expect(calls[0]!.url).toBe(`https://project.supabase.co/rest/v1/public_profiles?user_id=eq.${userID}`);
        expect(calls[0]!.init.method).toBe("PATCH");
        expect((calls[0]!.init.headers as Record<string, string>).Authorization).toBe("Bearer service-key");
        expect(JSON.parse(calls[0]!.init.body as string)).toEqual({ premium_until: "2027-01-01T00:00:00.000Z" });
    });

    it("clears premium_until for a revoked subscription", async () => {
        let body = "";
        const fetcher = (async (_url: string, init: RequestInit) => {
            body = init.body as string;
            return new Response(null, { status: 204 });
        }) as unknown as typeof fetch;

        await mirrorPremiumToSupabase(env, log, userID, null, fetcher);
        expect(JSON.parse(body)).toEqual({ premium_until: null });
    });

    it("does nothing without the service role key and survives failures", async () => {
        let called = false;
        const fetcher = (async () => {
            called = true;
            return new Response("nope", { status: 500 });
        }) as unknown as typeof fetch;

        expect(await mirrorPremiumToSupabase({ SUPABASE_URL: env.SUPABASE_URL } as Env, log, userID, 1, fetcher))
            .toBe(false);
        expect(called).toBe(false);
        expect(await mirrorPremiumToSupabase(env, log, userID, 1, fetcher)).toBe(false);
    });
});
