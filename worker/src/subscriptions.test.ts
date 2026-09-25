import { describe, expect, it } from "vitest";

import { validateTransaction } from "./subscriptions";

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
