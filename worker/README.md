# Fitgram Worker

Cloudflare Worker that proxies Gemini vision calls, verifies the Supabase
JWT, and caches results by image hash. The iOS app never embeds Gemini /
Anthropic credentials — every AI call lands here first.

## Routes

| Method | Path                | Purpose                              |
|--------|---------------------|--------------------------------------|
| GET    | `/healthz`          | Liveness probe.                      |
| POST   | `/api/v1/scan-food` | Vision: multipart image → JSON items |
| POST   | `/api/v1/subscription/sync` | Verify StoreKit transaction and sync Pro |

## Prerequisites

* Node 20+ with `npm`
* A Cloudflare account on the Workers free or paid plan
* Google Cloud project with the Generative Language API enabled
  (Gemini 2.5 Flash + Pro)
* Supabase project (any plan) — we read its JWT secret to verify tokens
* Upstash Redis (optional but recommended for cache durability when running
  outside Workers KV regions)

## Local development

```bash
cd worker
npm install
cp .env.example .env       # then fill in the four secrets
npx wrangler dev
```

Hit `http://127.0.0.1:8787/healthz` to confirm the loop boots.

To exercise the AI endpoint locally with a real Supabase JWT:

```bash
curl -X POST http://127.0.0.1:8787/api/v1/scan-food \
  -H "Authorization: Bearer $SUPABASE_JWT" \
  -F image=@./fixtures/schabowy.jpg \
  -F meal_type_hint=lunch
```

## First-time deploy

```bash
cd worker
npm install
npx wrangler login

# Optional KV cache binding (skips Upstash for free-tier setups):
npx wrangler kv namespace create scan-cache
# Paste the resulting id/preview_id into wrangler.toml under [[kv_namespaces]]

# Secrets — repeat for each:
npx wrangler secret put SUPABASE_JWT_SECRET     # from Supabase → Settings → API
npx wrangler secret put SUPABASE_URL            # https://<project>.supabase.co
npx wrangler secret put GEMINI_API_KEY          # from console.cloud.google.com
npx wrangler secret put UPSTASH_REDIS_URL       # optional, REST URL
npx wrangler secret put UPSTASH_REDIS_TOKEN     # optional, REST token

# App Store Connect → Users and Access → Integrations → In-App Purchase.
npx wrangler secret put APPLE_ISSUER_ID
npx wrangler secret put APPLE_KEY_ID
npx wrangler secret put APPLE_PRIVATE_KEY       # full .p8 contents

# Apply both usage/subscription migrations before deploying code.
npx wrangler d1 execute fitgram-usage --remote --file=migrations/0001_ai_usage.sql
npx wrangler d1 execute fitgram-usage --remote --file=migrations/0002_subscription_entitlements.sql
npx wrangler d1 execute fitgram-usage --remote --file=migrations/0003_usage_dashboard.sql
npx wrangler d1 execute fitgram-usage --remote --file=migrations/0002_subscription_entitlements.sql

npx wrangler deploy
```

The protected `/admin/dashboard` page uses HTTPS Basic authentication (username
`fitgram`, password from the `ADMIN_TOKEN` Worker secret) and shows request and token totals,
estimated cost, cache rate, average latency, top AI features, pseudonymous top
users, models, and a 30-day daily breakdown. Raw prompts, photos, transcripts,
email addresses, and full user IDs are never stored in analytics.

After deploy, copy the production URL (e.g. `https://fitgram-app.<acct>.workers.dev`)
into the iOS app's `Info.plist` as `WORKER_BASE_URL` — `AppConfig` reads it
via `Bundle.main.object(forInfoDictionaryKey:)`.

## Updating

```bash
npx wrangler deploy       # ships latest src/
npx wrangler tail         # follow logs after deploy
```

## Cost guardrails

* `SCAN_CACHE` plus `CACHE_TTL_SECONDS=604800` makes repeat scans of the
  same plate free.
* D1 atomically reserves each AI request before model execution, enforcing
  the free 3/3/2 pools and the 60-request daily safety ceiling server-side.
* Pro is derived from an App Store transaction verified by the Worker; the
  client cannot unlock premium by sending a flag.
* `gemini-2.5-flash` is the default model. Premium model access is selected
  only from the verified server entitlement.

## Layout

```
worker/
├── src/
│   ├── index.ts        # router
│   ├── auth.ts         # Supabase JWT verification
│   ├── cache.ts        # KV + Upstash adapters
│   ├── env.ts          # bindings typed for TS
│   ├── gemini.ts       # Gemini vision client + parsing
│   ├── log.ts          # leveled console logger
│   ├── responses.ts    # JSON helpers
│   └── scan-food.ts    # the /api/v1/scan-food handler
├── package.json
├── tsconfig.json
└── wrangler.toml
```
