-- Mealgram AI usage accounting.
--
-- One row per call to Gemini (or cache hit that would have called Gemini).
-- The admin dashboard queries this table for daily/weekly/monthly aggregates
-- and per-model cost breakdown.

CREATE TABLE IF NOT EXISTS ai_usage (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    ts              INTEGER NOT NULL,          -- ms since epoch
    user_id         TEXT NOT NULL,             -- Supabase / Apple subject claim
    model           TEXT NOT NULL,             -- e.g. gemini-2.5-flash
    endpoint        TEXT NOT NULL,             -- e.g. /api/v1/scan-food
    prompt_tokens   INTEGER NOT NULL DEFAULT 0,
    output_tokens   INTEGER NOT NULL DEFAULT 0,
    cost_usd        REAL NOT NULL DEFAULT 0,
    cached          INTEGER NOT NULL DEFAULT 0, -- 0 = Gemini call, 1 = cache hit
    duration_ms     INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_ai_usage_ts ON ai_usage(ts DESC);
CREATE INDEX IF NOT EXISTS idx_ai_usage_user_ts ON ai_usage(user_id, ts DESC);
CREATE INDEX IF NOT EXISTS idx_ai_usage_model_ts ON ai_usage(model, ts DESC);
