import { describe, expect, it } from "vitest";

import { ACCOUNT_TABLES, deleteWorkerRows, handleDeleteAccount, revokeAppleTokens } from "./account";
import type { Env } from "./env";
import type { Logger } from "./log";

const log: Logger = { debug() {}, info() {}, warn() {}, error() {} } as unknown as Logger;

function fakeD1(changesPerTable = 2) {
    const statements: { sql: string; args: unknown[] }[] = [];
    const db = {
        prepare(sql: string) {
            const statement = {
                sql,
                args: [] as unknown[],
                bind(...args: unknown[]) {
                    statement.args = args;
                    return statement;
                },
            };
            return statement;
        },
        async batch(list: { sql: string; args: unknown[] }[]) {
            statements.push(...list.map((s) => ({ sql: s.sql, args: s.args })));
            return list.map(() => ({ meta: { changes: changesPerTable } }));
        },
    };
    return { db, statements };
}

async function testPrivateKeyPEM(): Promise<string> {
    const pair = (await crypto.subtle.generateKey({ name: "ECDSA", namedCurve: "P-256" }, true, [
        "sign",
        "verify",
    ])) as CryptoKeyPair;
    const pkcs8 = new Uint8Array((await crypto.subtle.exportKey("pkcs8", pair.privateKey)) as ArrayBuffer);
    const b64 = btoa(String.fromCharCode(...pkcs8));
    return `-----BEGIN PRIVATE KEY-----\n${b64}\n-----END PRIVATE KEY-----`;
}

describe("deleteWorkerRows", () => {
    it("deletes the user from every Worker table", async () => {
        const { db, statements } = fakeD1();
        const deleted = await deleteWorkerRows({ USAGE_DB: db } as unknown as Env, "user-1");
        expect(deleted).toBe(ACCOUNT_TABLES.length * 2);
        expect(statements.map((s) => s.sql)).toEqual(
            ACCOUNT_TABLES.map((table) => `DELETE FROM ${table} WHERE user_id = ?`)
        );
        expect(statements.every((s) => s.args[0] === "user-1")).toBe(true);
    });

    it("reports a D1 failure instead of pretending success", async () => {
        const db = {
            prepare: () => ({ bind: () => ({}) }),
            batch: async () => {
                throw new Error("D1 down");
            },
        };
        expect(await deleteWorkerRows({ USAGE_DB: db } as unknown as Env, "u")).toBeNull();
    });
});

describe("revokeAppleTokens", () => {
    it("does nothing without an authorization code", async () => {
        expect(await revokeAppleTokens({} as Env, log, undefined)).toBe("not_requested");
    });

    it("skips revocation when the Sign in with Apple key is missing", async () => {
        expect(await revokeAppleTokens({ APPLE_TEAM_ID: "T" } as Env, log, "code")).toBe("not_configured");
    });

    it("exchanges the code and revokes the refresh token", async () => {
        const calls: { url: string; body: URLSearchParams }[] = [];
        const fetcher = (async (url: string, init: RequestInit) => {
            calls.push({ url, body: init.body as URLSearchParams });
            if (url.endsWith("/auth/token")) {
                return new Response(JSON.stringify({ refresh_token: "r-1" }), { status: 200 });
            }
            return new Response("", { status: 200 });
        }) as unknown as typeof fetch;
        const env = {
            APPLE_TEAM_ID: "L55G3V9NJ3",
            APPLE_SIWA_KEY_ID: "KEY123",
            APPLE_SIWA_PRIVATE_KEY: await testPrivateKeyPEM(),
            APPLE_BUNDLE_ID: "app.fitgram.ios.bashyrov",
        } as Env;

        expect(await revokeAppleTokens(env, log, "auth-code", fetcher)).toBe("revoked");
        expect(calls.map((c) => c.url)).toEqual([
            "https://appleid.apple.com/auth/token",
            "https://appleid.apple.com/auth/revoke",
        ]);
        expect(calls[0]!.body.get("code")).toBe("auth-code");
        expect(calls[1]!.body.get("token")).toBe("r-1");
        expect(calls[1]!.body.get("token_type_hint")).toBe("refresh_token");
        expect(calls[1]!.body.get("client_id")).toBe("app.fitgram.ios.bashyrov");
    });

    it("reports failure when Apple rejects the code", async () => {
        const fetcher = (async () => new Response("invalid_grant", { status: 400 })) as unknown as typeof fetch;
        const env = {
            APPLE_TEAM_ID: "T",
            APPLE_SIWA_KEY_ID: "K",
            APPLE_SIWA_PRIVATE_KEY: await testPrivateKeyPEM(),
        } as Env;
        expect(await revokeAppleTokens(env, log, "bad", fetcher)).toBe("failed");
    });
});

describe("handleDeleteAccount", () => {
    it("deletes rows and returns the revocation outcome", async () => {
        const { db } = fakeD1(1);
        const request = new Request("https://w/api/v1/account", { method: "DELETE" });
        const response = await handleDeleteAccount(request, { USAGE_DB: db } as unknown as Env, log, {
            userID: "user-1",
            isPremium: false,
        });
        expect(response.status).toBe(200);
        expect(await response.json()).toEqual({
            ok: true,
            deleted_rows: ACCOUNT_TABLES.length,
            apple_revocation: "not_requested",
        });
    });

    it("rejects other methods", async () => {
        const request = new Request("https://w/api/v1/account", { method: "POST" });
        const response = await handleDeleteAccount(request, {} as Env, log, { userID: "u", isPremium: false });
        expect(response.status).toBe(405);
    });
});
