/// <reference types="@cloudflare/workers-types" />

import type { Env } from "./env";
import type { Logger } from "./log";
import { problemResponse, jsonResponse } from "./responses";
import { summarizeUsage, type UsageSummary } from "./usage";

/**
 * Admin-only routes. Gated by a shared-secret bearer token (`ADMIN_TOKEN`
 * wrangler secret). Returns 404 to anyone without the right token so the
 * routes are invisible to casual probing.
 */
export async function handleAdmin(
    request: Request,
    env: Env,
    log: Logger,
    pathname: string
): Promise<Response> {
    if (!isAuthorized(request, env)) {
        return new Response("Authentication required", {
            status: 401,
            headers: {
                "WWW-Authenticate": 'Basic realm="Fitgram AI usage", charset="UTF-8"',
                "Cache-Control": "no-store",
            },
        });
    }

    if (pathname === "/admin/usage") {
        const summary = await summarizeUsage(env, log);
        return jsonResponse(summary);
    }

    if (pathname === "/admin/dashboard") {
        const summary = await summarizeUsage(env, log);
        return new Response(renderHTML(summary), {
            headers: { "Content-Type": "text/html; charset=utf-8" },
        });
    }

    return problemResponse(404, "Not found");
}

function isAuthorized(request: Request, env: Env): boolean {
    if (!env.ADMIN_TOKEN) return false;
    const auth = request.headers.get("Authorization") ?? "";
    const bearer = auth.startsWith("Bearer ") ? auth.slice(7) : "";
    if (bearer === env.ADMIN_TOKEN) return true;
    if (!auth.startsWith("Basic ")) return false;
    try {
        const credentials = atob(auth.slice(6));
        const separator = credentials.indexOf(":");
        if (separator < 0) return false;
        const username = credentials.slice(0, separator);
        const password = credentials.slice(separator + 1);
        return username === "fitgram" && password === env.ADMIN_TOKEN;
    } catch {
        return false;
    }
}

function renderHTML(summary: UsageSummary): string {
    const fmtCost = (value: number): string => `$${value.toFixed(4)}`;
    const fmtNumber = (value: number): string => value.toLocaleString("en-US");
    const fmtTokens = (input: number, output: number): string =>
        `${fmtNumber(input)} / ${fmtNumber(output)}`;
    const cacheRate = (cached: number, total: number): string =>
        total === 0 ? "0%" : `${Math.round((cached / total) * 100)}%`;
    const rows30d = summary.daily
        .map(
            (row) =>
                `<tr><td>${escape(row.day)}</td><td>${fmtNumber(row.requests)}</td><td>${fmtTokens(row.promptTokens, row.outputTokens)}</td><td>${cacheRate(row.cachedRequests, row.requests)}</td><td>${row.averageDurationMs} ms</td><td>${fmtCost(row.costUSD)}</td></tr>`
        )
        .join("");
    const rowsByModel = summary.byModel
        .map(
            (row) =>
                `<tr><td>${escape(row.label)}</td><td>${fmtNumber(row.requests)}</td><td>${fmtTokens(row.promptTokens, row.outputTokens)}</td><td>${cacheRate(row.cachedRequests, row.requests)}</td><td>${fmtCost(row.costUSD)}</td></tr>`
        )
        .join("");
    const rowsByEndpoint = summary.byEndpoint.map((row) =>
        `<tr><td>${escape(friendlyEndpoint(row.label))}</td><td><code>${escape(row.label)}</code></td><td>${fmtNumber(row.requests)}</td><td>${fmtTokens(row.promptTokens, row.outputTokens)}</td><td>${cacheRate(row.cachedRequests, row.requests)}</td><td>${row.averageDurationMs} ms</td><td>${fmtCost(row.costUSD)}</td></tr>`
    ).join("");
    const rowsByUser = summary.topUsers.map((row) =>
        `<tr><td><code>${escape(row.user)}</code></td><td>${fmtNumber(row.requests)}</td><td>${fmtTokens(row.promptTokens, row.outputTokens)}</td><td>${cacheRate(row.cachedRequests, row.requests)}</td><td>${row.averageDurationMs} ms</td><td>${fmtCost(row.costUSD)}</td></tr>`
    ).join("");
    const generated = new Date(summary.generatedAt).toISOString();
    return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8" />
<title>Fitgram · AI usage</title>
<style>
  :root { color-scheme: light dark; }
  * { box-sizing: border-box; }
  body {
    font: 14px/1.5 -apple-system, BlinkMacSystemFont, "SF Pro Rounded",
          system-ui, sans-serif;
    margin: 0;
    padding: 32px 20px 56px;
    background: #f5f3ee;
    color: #1e2419;
  }
  main { max-width: 1180px; margin: 0 auto; }
  @media (prefers-color-scheme: dark) {
    body { background: #14140f; color: #ece5d3; }
    .card { background: #1f1f17; border-color: #2c2c22; }
  }
  h1 { font-size: 22px; margin: 0 0 4px; font-weight: 700; }
  h2 { font-size: 14px; margin: 24px 0 8px; opacity: 0.6; font-weight: 600;
       text-transform: uppercase; letter-spacing: 0.05em; }
  .grid {
    display: grid; grid-template-columns: repeat(4, 1fr);
    gap: 12px; margin: 16px 0 8px;
  }
  .table-wrap { overflow-x: auto; background: #fff; border-radius: 14px; padding: 4px 12px; }
  .card {
    background: #fff; border: 1px solid #e0d9c8;
    border-radius: 14px; padding: 16px;
  }
  .label { font-size: 11px; text-transform: uppercase;
            letter-spacing: 0.05em; opacity: 0.55; }
  .value { font-size: 22px; font-weight: 700; margin-top: 6px;
            font-variant-numeric: tabular-nums; }
  .sub { font-size: 12px; opacity: 0.55; margin-top: 2px;
          font-variant-numeric: tabular-nums; }
  table {
    width: 100%; border-collapse: collapse; margin-top: 8px;
    font-variant-numeric: tabular-nums;
  }
  th, td {
    text-align: left; padding: 8px 10px; border-bottom: 1px solid #e0d9c8;
  }
  @media (prefers-color-scheme: dark) {
    th, td { border-color: #2c2c22; }
    .table-wrap { background: #1f1f17; }
  }
  th { font-size: 11px; text-transform: uppercase;
        letter-spacing: 0.05em; opacity: 0.55; }
  tr:last-child td { border-bottom: 0; }
  footer { margin-top: 24px; font-size: 11px; opacity: 0.45; }
  a { color: #5a8050; }
  code { font-size: 12px; white-space: nowrap; }
  @media (max-width: 760px) {
    .grid { grid-template-columns: repeat(2, 1fr); }
    body { padding: 20px 12px 40px; }
  }
</style>
</head>
<body><main>
  <h1>Fitgram · AI usage</h1>
  <div class="label">Server-side aggregate from the ai_usage table.</div>

  <div class="grid">
    <div class="card">
      <div class="label">Last 24 h</div>
      <div class="value">${summary.last24h.requests.toLocaleString()}</div>
      <div class="sub">${fmtCost(summary.last24h.costUSD)} · ${summary.last24h.activeUsers} users</div>
    </div>
    <div class="card">
      <div class="label">Last 7 days</div>
      <div class="value">${summary.last7d.requests.toLocaleString()}</div>
      <div class="sub">${fmtCost(summary.last7d.costUSD)} · ${summary.last7d.activeUsers} users</div>
    </div>
    <div class="card">
      <div class="label">Last 30 days</div>
      <div class="value">${summary.last30d.requests.toLocaleString()}</div>
      <div class="sub">${fmtCost(summary.last30d.costUSD)} · ${summary.last30d.activeUsers} users</div>
    </div>
    <div class="card">
      <div class="label">All-time</div>
      <div class="value">${summary.totalRequests.toLocaleString()}</div>
      <div class="sub">${fmtCost(summary.totalCostUSD)} · cached ${summary.cachedRequests.toLocaleString()}</div>
    </div>
  </div>

  <h2>By model</h2>
  <div class="table-wrap"><table>
    <thead><tr><th>Model</th><th>Requests</th><th>Tokens in / out</th><th>Cache</th><th>Cost</th></tr></thead>
    <tbody>${rowsByModel || `<tr><td colspan="3"><em>no data yet</em></td></tr>`}</tbody>
  </table></div>

  <h2>Top AI features · last 30 days</h2>
  <div class="table-wrap"><table>
    <thead><tr><th>Feature</th><th>Endpoint</th><th>Requests</th><th>Tokens in / out</th><th>Cache</th><th>Avg latency</th><th>Cost</th></tr></thead>
    <tbody>${rowsByEndpoint || `<tr><td colspan="7"><em>no data yet</em></td></tr>`}</tbody>
  </table></div>

  <h2>Top users · last 30 days</h2>
  <div class="table-wrap"><table>
    <thead><tr><th>Anonymous user</th><th>Requests</th><th>Tokens in / out</th><th>Cache</th><th>Avg latency</th><th>Cost</th></tr></thead>
    <tbody>${rowsByUser || `<tr><td colspan="6"><em>no data yet</em></td></tr>`}</tbody>
  </table></div>

  <h2>Daily breakdown (last 30 days)</h2>
  <div class="table-wrap"><table>
    <thead><tr><th>Day</th><th>Requests</th><th>Tokens in / out</th><th>Cache</th><th>Avg latency</th><th>Cost</th></tr></thead>
    <tbody>${rows30d || `<tr><td colspan="3"><em>no data yet</em></td></tr>`}</tbody>
  </table></div>

  <footer>Generated ${escape(generated)} · JSON endpoint: <code>/admin/usage</code></footer>
</main></body>
</html>`;
}

function friendlyEndpoint(endpoint: string): string {
    if (endpoint.includes("scan-food")) return "Photo scan";
    if (endpoint.includes("ai_logged_meal")) return "Voice meal";
    if (endpoint.includes("ai_meal_refresh")) return "Meal refresh";
    if (endpoint.includes("ai_product_nutrition")) return "Product nutrition";
    if (endpoint.includes("ola-chef")) return "Ola Chef";
    if (endpoint.includes("daily-plan")) return "Daily Ola";
    if (endpoint.includes("daily-insight")) return "Ola insight";
    if (endpoint.includes("weekly-debrief")) return "Weekly report";
    if (endpoint.includes("initial-recommendations")) return "Onboarding plan";
    return endpoint;
}

function escape(s: string): string {
    return s
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;");
}
