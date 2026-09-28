import { describe, expect, it } from "vitest";
import { promptContext, type CoachContext } from "./coach";
import { billedOutputTokens, geminiThinkingConfig } from "./gemini";

const ctx = {
    goals: {
        calorieGoalKcal: 2000,
        proteinGoalGrams: 120,
        carbsGoalGrams: 220,
        fatGoalGrams: 70,
        waterGoalMl: 2500,
        goalKind: "lose",
        dietMacroPreset: "balanced",
    },
    today: { caloriesKcal: 1234.5678, proteinGrams: 61.04, carbsGrams: 100, fatGrams: 40.26, entryCount: 3 },
    weight: { latestKg: 72.46, deltaKg30Days: -1.24 },
    hourOfDay: 14,
    hasOngoingCulturalEvent: false,
    userID: "user-123",
    locale: "pl",
} as unknown as CoachContext;

describe("promptContext", () => {
    it("drops the user id and locale", () => {
        const text = promptContext(ctx);
        expect(text).not.toContain("user-123");
        expect(text).not.toContain('"locale"');
    });

    it("rounds fractions to one decimal and keeps integers", () => {
        const parsed = JSON.parse(promptContext(ctx));
        expect(parsed.today.caloriesKcal).toBe(1234.6);
        expect(parsed.today.proteinGrams).toBe(61);
        expect(parsed.weight.latestKg).toBe(72.5);
        expect(parsed.goals.calorieGoalKcal).toBe(2000);
        expect(parsed.hourOfDay).toBe(14);
    });
});

describe("billedOutputTokens", () => {
    it("adds thinking tokens to the visible answer", () => {
        expect(billedOutputTokens({ candidatesTokenCount: 300, thoughtsTokenCount: 128 })).toBe(428);
        expect(billedOutputTokens({ candidatesTokenCount: 300 })).toBe(300);
        expect(billedOutputTokens(undefined)).toBe(0);
    });
});

describe("geminiThinkingConfig", () => {
    it("turns thinking off for Flash and caps it for Pro", () => {
        expect(geminiThinkingConfig("gemini-2.5-flash")).toEqual({ thinkingConfig: { thinkingBudget: 0 } });
        expect(geminiThinkingConfig("gemini-2.5-pro")).toEqual({ thinkingConfig: { thinkingBudget: 128 } });
        expect(geminiThinkingConfig("gemini-flash-latest")).toEqual({});
    });
});
