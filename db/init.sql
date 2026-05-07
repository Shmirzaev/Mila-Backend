CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS ai_memory (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    user_id TEXT NOT NULL,
    company_id TEXT NOT NULL DEFAULT 'milana_premium',

    category TEXT NOT NULL DEFAULT 'general',
    memory_type TEXT NOT NULL DEFAULT 'fact',

    title TEXT NOT NULL,
    content TEXT NOT NULL,

    source TEXT DEFAULT 'voice_assistant',
    importance SMALLINT NOT NULL DEFAULT 3 CHECK (importance BETWEEN 1 AND 5),

    tags TEXT[] DEFAULT ARRAY[]::TEXT[],

    status TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'archived', 'deleted')),

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS ai_memory_embeddings (
    memory_id UUID PRIMARY KEY REFERENCES ai_memory(id) ON DELETE CASCADE,

    embedding VECTOR(768) NOT NULL,
    embedding_model TEXT NOT NULL DEFAULT 'gemini-embedding-2',

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS ai_memory_audit (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    memory_id UUID,
    action TEXT NOT NULL,
    user_id TEXT NOT NULL,

    old_content TEXT,
    new_content TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ai_memory_user_status
ON ai_memory(user_id, status);

CREATE INDEX IF NOT EXISTS idx_ai_memory_category
ON ai_memory(category);

CREATE INDEX IF NOT EXISTS idx_ai_memory_importance
ON ai_memory(importance DESC);

CREATE INDEX IF NOT EXISTS idx_ai_memory_embedding_hnsw
ON ai_memory_embeddings
USING hnsw (embedding vector_cosine_ops);