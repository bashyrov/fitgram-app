import { describe, expect, it } from "vitest";
import {
    dayStartTimestamp,
    estimateCostUSD,
    endpointsForKind,
    timeZoneOffsetMinutesFromRequest,
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
