-- Improve dashboard lookup performance and correct historical estimates that
-- were recorded with legacy Gemini prices.

CREATE INDEX IF NOT EXISTS idx_ai_usage_endpoint_ts ON ai_usage(endpoint, ts DESC);

UPDATE ai_usage
SET cost_usd = ROUND(
    (prompt_tokens / 1000000.0) * 0.30 +
    (output_tokens / 1000000.0) * 2.50,
    6
)
WHERE cached = 0 AND model = 'gemini-2.5-flash';

UPDATE ai_usage
SET cost_usd = ROUND(
    (prompt_tokens / 1000000.0) * 0.10 +
    (output_tokens / 1000000.0) * 0.40,
    6
)
WHERE cached = 0 AND model = 'gemini-2.5-flash-lite';

UPDATE ai_usage
SET cost_usd = ROUND(
    (prompt_tokens / 1000000.0) * 1.25 +
    (output_tokens / 1000000.0) * 10.00,
    6
)
WHERE cached = 0 AND model = 'gemini-2.5-pro';
