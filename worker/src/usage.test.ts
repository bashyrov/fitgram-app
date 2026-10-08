import { describe, expect, it } from "vitest";
import {
    dayStartTimestamp,
    estimateCostUSD,
    endpointsForKind,
    freeQuotaScope,
    FREE_WEEKLY_AI_POOL,
    timeZoneOffsetMinutesFromRequest,
    weekStartTimestamp,
    pseudonymousUserID,
} from "./usage";

describe("usage quota helpers", () => {
    it("parses and clamps the app time-zone offset header", () => {
        expect(
            timeZoneOffsetMinutesFromRequest(
                new Request("https://fitgram.test", {
                    headers: { "X-Fitgram-Time-Zone-Offset-Minutes": "120" },
                })
            )
        ).toBe(120);
        expect(
            timeZoneOffsetMinutesFromRequest(
                new Request("https://fitgram.test", {
                    headers: { "X-Fitgram-Time-Zone-Offset-Minutes": "9999" },
                })
            )
        ).toBe(840);
        expect(
            timeZoneOffsetMinutesFromRequest(
                new Request("https://fitgram.test", {
                    headers: { "X-Fitgram-Time-Zone-Offset-Minutes": "nope" },
                })
            )
        ).toBeUndefined();
        expect(timeZoneOffsetMinutesFromRequest(new Request("https://fitgram.test"))).toBeUndefined();
    });

    it("starts the quota window at local midnight for the user", () => {
        expect(
            new Date(dayStartTimestamp(Date.UTC(2026, 6, 30, 21, 30), 120)).toISOString()
        ).toBe("2026-07-29T22:00:00.000Z");
        expect(
            new Date(dayStartTimestamp(Date.UTC(2026, 6, 30, 22, 30), 120)).toISOString()
        ).toBe("2026-07-30T22:00:00.000Z");
    });

    it("shares the logged-meal quota between photo and voice", () => {
        expect(endpointsForKind("ai_draft_meal")).toContain("/api/v1/scan-food");
        expect(endpointsForKind("ai_logged_meal")).toContain("/api/v1/scan-food");
        expect(endpointsForKind("ai_logged_meal")).toContain(
            "/api/v1/analyze-meal-text:ai_logged_meal"
        );
    });

    it("starts the free AI week on the user's local Monday", () => {
        // Thursday 2026-10-08 12:00 UTC, user at UTC+2 → Monday 2026-10-05 00:00 local.
        expect(
            new Date(weekStartTimestamp(Date.UTC(2026, 9, 8, 12), 120)).toISOString()
        ).toBe("2026-10-04T22:00:00.000Z");
        // Sunday 23:30 local still belongs to the week that started on Monday.
        expect(
            new Date(weekStartTimestamp(Date.UTC(2026, 9, 11, 21, 30), 120)).toISOString()
        ).toBe("2026-10-04T22:00:00.000Z");
        // Monday 00:30 local opens a fresh week.
        expect(
            new Date(weekStartTimestamp(Date.UTC(2026, 9, 11, 22, 30), 120)).toISOString()
        ).toBe("2026-10-11T22:00:00.000Z");
    });

    it("puts photo, voice, refresh and product lookups in one weekly free pool", () => {
        const now = Date.UTC(2026, 9, 8, 12);
        const photo = freeQuotaScope("ai_logged_meal", now, 120);
        const refresh = freeQuotaScope("ai_meal_refresh", now, 120);
        const product = freeQuotaScope("ai_product_nutrition", now, 120);
        expect(photo?.cap).toBe(FREE_WEEKLY_AI_POOL);
        expect(refresh).toEqual(photo);
        expect(product).toEqual(photo);
        expect(photo?.endpoints).toContain("/api/v1/scan-food");
        expect(photo?.endpoints).toContain("/api/v1/analyze-meal-text:ai_product_nutrition");
        expect(new Set(photo?.endpoints).size).toBe(photo?.endpoints.length);
        expect(freeQuotaScope("ola_chef", now, 120)?.cap).toBe(0);
    });

    it("uses stable pseudonymous IDs without exposing the source user ID", async () => {
        const first = await pseudonymousUserID("supabase-user-123");
        const second = await pseudonymousUserID("supabase-user-123");
        expect(first).toBe(second);
        expect(first).toMatch(/^user_[0-9a-f]{12}$/);
        expect(first).not.toContain("supabase-user-123");
    });

    it("estimates current Gemini 2.5 Flash token cost", () => {
        expect(estimateCostUSD("gemini-2.5-flash", 1_000_000, 1_000_000)).toBe(2.8);
        expect(estimateCostUSD("gemini-2.5-flash-lite", 1_000_000, 1_000_000)).toBe(0.5);
    });
});
