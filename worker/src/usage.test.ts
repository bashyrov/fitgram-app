import { describe, expect, it } from "vitest";
import {
    dayStartTimestamp,
    endpointsForKind,
    timeZoneOffsetMinutesFromRequest,
} from "./usage";

describe("usage quota helpers", () => {
    it("parses and clamps the app time-zone offset header", () => {
        expect(
            timeZoneOffsetMinutesFromRequest(
                new Request("https://mealgram.test", {
                    headers: { "X-Mealgram-Time-Zone-Offset-Minutes": "120" },
                })
            )
        ).toBe(120);
        expect(
            timeZoneOffsetMinutesFromRequest(
                new Request("https://mealgram.test", {
                    headers: { "X-Mealgram-Time-Zone-Offset-Minutes": "9999" },
                })
            )
        ).toBe(840);
        expect(
            timeZoneOffsetMinutesFromRequest(
                new Request("https://mealgram.test", {
                    headers: { "X-Mealgram-Time-Zone-Offset-Minutes": "nope" },
                })
            )
        ).toBeUndefined();
        expect(timeZoneOffsetMinutesFromRequest(new Request("https://mealgram.test"))).toBeUndefined();
    });

    it("starts the quota window at local midnight for the user", () => {
        expect(
            new Date(dayStartTimestamp(Date.UTC(2026, 6, 30, 21, 30), 120)).toISOString()
        ).toBe("2026-07-29T22:00:00.000Z");
        expect(
            new Date(dayStartTimestamp(Date.UTC(2026, 6, 30, 22, 30), 120)).toISOString()
        ).toBe("2026-07-30T22:00:00.000Z");
    });

    it("keeps draft scan quota separate from logged meal quota", () => {
        expect(endpointsForKind("ai_draft_meal")).toContain("/api/v1/scan-food");
        expect(endpointsForKind("ai_logged_meal")).not.toContain("/api/v1/scan-food");
        expect(endpointsForKind("ai_logged_meal")).toEqual([
            "/api/v1/analyze-meal-text:ai_logged_meal",
        ]);
    });
});
