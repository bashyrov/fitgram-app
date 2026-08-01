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
        // 404 instead of 401 — don't advertise the endpoint to scanners.
        return problemResponse(404, "Not found");
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
    // Accept either Authorization: Bearer xxx OR ?token=xxx (URL form so
    // the HTML dashboard works from a plain browser without curl).
    const auth = request.headers.get("Authorization") ?? "";
    const bearer = auth.startsWith("Bearer ") ? auth.slice(7) : "";
    const url = new URL(request.url);
    const queryToken = url.searchParams.get("token") ?? "";
    return bearer === env.ADMIN_TOKEN || queryToken === env.ADMIN_TOKEN;
}

function renderHTML(summary: UsageSummary): string {
    const fmtCost = (value: number): string => `$${value.toFixed(4)}`;
    const rows30d = summary.daily
        .map(
            (row) =>
                `<tr><td>${escape(row.day)}</td><td>${row.requests.toLocaleString()}</td><td>${fmtCost(row.costUSD)}</td></tr>`
        )
        .join("");
    const rowsByModel = summary.byModel
        .map(
            (row) =>
                `<tr><td>${escape(row.model)}</td><td>${row.requests.toLocaleString()}</td><td>${fmtCost(row.costUSD)}</td></tr>`
        )
        .join("");
    const generated = new Date(summary.generatedAt).toISOString();
    return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8" />
<title>Mealgram · AI usage</title>
<style>
  :root { color-scheme: light dark; }
  body {
    font: 14px/1.5 -apple-system, BlinkMacSystemFont, "SF Pro Rounded",
          system-ui, sans-serif;
    margin: 0;
    padding: 32px;
    background: #f5f3ee;
    color: #1e2419;
  }
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
  }
  th { font-size: 11px; text-transform: uppercase;
        letter-spacing: 0.05em; opacity: 0.55; }
  tr:last-child td { border-bottom: 0; }
  footer { margin-top: 24px; font-size: 11px; opacity: 0.45; }
  a { color: #5a8050; }
</style>
</head>
<body>
  <h1>Mealgram · AI usage</h1>
  <div class="label">Server-side aggregate from the ai_usage table.</div>

  <div class="grid">
    <div class="card">
      <div class="label">Last 24 h</div>
      <div class="value">${summary.last24h.requests.toLocaleString()}</div>
      <div class="sub">${fmtCost(summary.last24h.costUSD)}</div>
    </div>
    <div class="card">
      <div class="label">Last 7 days</div>
      <div class="value">${summary.last7d.requests.toLocaleString()}</div>
      <div class="sub">${fmtCost(summary.last7d.costUSD)}</div>
    </div>
    <div class="card">
      <div class="label">Last 30 days</div>
      <div class="value">${summary.last30d.requests.toLocaleString()}</div>
      <div class="sub">${fmtCost(summary.last30d.costUSD)}</div>
    </div>
    <div class="card">
      <div class="label">All-time</div>
      <div class="value">${summary.totalRequests.toLocaleString()}</div>
      <div class="sub">${fmtCost(summary.totalCostUSD)} · cached ${summary.cachedRequests.toLocaleString()}</div>
    </div>
  </div>

  <h2>By model</h2>
  <table>
    <thead><tr><th>Model</th><th>Requests</th><th>Cost</th></tr></thead>
    <tbody>${rowsByModel || `<tr><td colspan="3"><em>no data yet</em></td></tr>`}</tbody>
  </table>

  <h2>Daily breakdown (last 30 days)</h2>
  <table>
    <thead><tr><th>Day</th><th>Requests</th><th>Cost</th></tr></thead>
    <tbody>${rows30d || `<tr><td colspan="3"><em>no data yet</em></td></tr>`}</tbody>
  </table>

  <footer>Generated ${escape(generated)} · curl JSON: <code>/admin/usage?token=…</code></footer>
</body>
</html>`;
}

function escape(s: string): string {
    return s
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;");
}
