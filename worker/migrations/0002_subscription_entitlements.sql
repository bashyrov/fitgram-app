CREATE TABLE IF NOT EXISTS subscription_entitlements (
    user_id                    TEXT NOT NULL,
    original_transaction_id   TEXT PRIMARY KEY,
    latest_transaction_id     TEXT NOT NULL,
    product_id                 TEXT NOT NULL,
    environment                TEXT NOT NULL,
    expires_at_ms              INTEGER NOT NULL,
    revoked_at_ms              INTEGER,
    updated_at_ms              INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_subscription_entitlements_user
    ON subscription_entitlements(user_id, expires_at_ms DESC);

CREATE TABLE IF NOT EXISTS ai_quota_reservations (
    id              TEXT PRIMARY KEY,
    ts              INTEGER NOT NULL,
    expires_at_ms   INTEGER NOT NULL,
    user_id         TEXT NOT NULL,
    quota_kind      TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_ai_quota_reservations_user
    ON ai_quota_reservations(user_id, ts DESC);
