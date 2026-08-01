# Admin AI usage dashboard

How to set up and query the server-side accounting that tracks every Gemini API call: request count + token usage + estimated USD cost. Admin-only — no user-facing surface.

## One-time setup (~5 minutes)

### 1. Create the D1 database

```bash
cd worker
npx wrangler d1 create mealgram-usage
```

This prints a `database_id`. Paste it into [wrangler.toml](wrangler.toml) under the `[[d1_databases]]` block (uncomment the lines):

```toml
[[d1_databases]]
binding = "USAGE_DB"
database_name = "mealgram-usage"
database_id = "<paste-from-step-above>"
```

### 2. Run the migration

```bash
npx wrangler d1 execute mealgram-usage --remote --file=migrations/0001_ai_usage.sql
```

Creates the `ai_usage` table. Idempotent — safe to re-run.

### 3. Set the admin token

Pick any long random string and store it as a Worker secret:

```bash
# Generate a secure random hex string
openssl rand -hex 32
# → e.g. 9d04a8...c211ef

npx wrangler secret put ADMIN_TOKEN
# Paste the hex string when prompted.
```

Keep this token in your password manager — it's the only thing protecting the cost dashboard.

### 4. Deploy

```bash
npx wrangler deploy
```

The Worker now logs every Gemini call into `ai_usage` automatically. No iOS changes needed — accounting happens server-side on every `/api/v1/scan-food` request.

## How to view the data

### Browser dashboard (easiest)

```
https://mealgram-worker.bashyroov.workers.dev/admin/dashboard?token=YOUR_ADMIN_TOKEN
```

Renders an HTML page with:
- Last 24h / 7d / 30d / all-time requests + cost
- Per-model breakdown (`gemini-2.5-flash` vs `gemini-2.5-pro`)
- Daily table for the last 30 days

Bookmark this URL — it's safe to share with yourself across devices since the token is in the query string.

### JSON via curl

```bash
TOKEN=YOUR_ADMIN_TOKEN
curl -sS "https://mealgram-worker.bashyroov.workers.dev/admin/usage" \
  -H "Authorization: Bearer $TOKEN" | jq
```

Sample response:

```json
{
  "totalRequests": 137,
  "cachedRequests": 42,
  "geminiRequests": 95,
  "totalCostUSD": 0.47,
  "last24h":  { "requests": 18, "costUSD": 0.05 },
  "last7d":   { "requests": 95, "costUSD": 0.29 },
  "last30d":  { "requests": 137, "costUSD": 0.47 },
  "byModel": [
    { "model": "gemini-2.5-flash", "requests": 88, "costUSD": 0.31 },
    { "model": "gemini-2.5-pro",   "requests": 7,  "costUSD": 0.16 }
  ],
  "daily": [
    { "day": "2026-05-22", "requests": 18, "costUSD": 0.05 },
    …
  ],
  "generatedAt": 1716401234567
}
```

### Direct D1 query (for ad-hoc analysis)

```bash
npx wrangler d1 execute mealgram-usage --remote --command \
  "SELECT user_id, COUNT(*) AS calls, ROUND(SUM(cost_usd), 4) AS usd
   FROM ai_usage
   WHERE ts >= strftime('%s', 'now', '-7 days') * 1000
   GROUP BY user_id
   ORDER BY usd DESC
   LIMIT 20"
```

## Pricing model

Cost estimates use Gemini's published per-million-token pricing in [usage.ts](src/usage.ts):

| Model | Input | Output |
|---|---|---|
| `gemini-2.5-flash` | $0.075 / 1M | $0.30 / 1M |
| `gemini-2.5-pro`   | $1.25 / 1M  | $5.00 / 1M |

Token counts come straight from Gemini's `usageMetadata` block in each response — they're authoritative, not estimated.

**Cache hits cost $0** but still get a row (`cached=1`) so we can see the cache-hit rate. A high cache-hit-rate after a few days of traffic is the cheapest possible operating mode — most photos are duplicates.

## Updating the pricing

Edit the `PRICE_PER_MILLION` table in [usage.ts](src/usage.ts) when Google changes their rates, run `npm run deploy`. Past rows keep their original cost; only future calls use the new rates.

## Cost budget alerts (future, optional)

Cloudflare Workers has `CRON Triggers` — drop a daily cron that compares `last24h.costUSD` against a threshold and pushes to your Slack via webhook. Not wired today; we'll see if we need it once traffic shows up.

## Security notes

- The admin endpoints return **404 (not 401)** when the token is wrong — keeps the routes invisible to scanners
- Token can come from either `Authorization: Bearer …` header or `?token=…` query param (the latter is what the HTML dashboard uses)
- D1 binding is optional — if you forget step 1, the Worker just logs a warning per request and skips accounting. Production never breaks because of a missing accounting layer.
