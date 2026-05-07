CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS pending_actions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    user_id TEXT NOT NULL,
    company_id TEXT NOT NULL DEFAULT 'milana_premium',

    action_type TEXT NOT NULL,
    target TEXT NOT NULL,

    payload JSONB NOT NULL,

    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'confirmed', 'executed', 'cancelled', 'failed')),

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    confirmed_at TIMESTAMPTZ,
    executed_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,

    error_message TEXT
);

CREATE TABLE IF NOT EXISTS action_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    action_id UUID,
    user_id TEXT NOT NULL,
    company_id TEXT NOT NULL DEFAULT 'milana_premium',

    action_type TEXT NOT NULL,
    target TEXT NOT NULL,

    payload JSONB,
    status TEXT NOT NULL,
    result TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pending_actions_status
ON pending_actions(status);

CREATE INDEX IF NOT EXISTS idx_pending_actions_user_created
ON pending_actions(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_action_logs_created
ON action_logs(created_at DESC);