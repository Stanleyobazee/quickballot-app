-- QuickBallot database schema
-- Compatible with PostgreSQL 14+

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ── Polls ────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS polls (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    question    TEXT        NOT NULL,
    status      TEXT        NOT NULL DEFAULT 'active'
                            CHECK (status IN ('active', 'closed')),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    closed_at   TIMESTAMPTZ
);

-- ── Poll options ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS poll_options (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    poll_id     UUID        NOT NULL REFERENCES polls(id) ON DELETE CASCADE,
    label       TEXT        NOT NULL,
    display_order INT       NOT NULL DEFAULT 0
);

-- ── Votes ────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS votes (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    poll_id     UUID        NOT NULL REFERENCES polls(id) ON DELETE CASCADE,
    option_id   UUID        NOT NULL REFERENCES poll_options(id) ON DELETE CASCADE,
    voter_token TEXT        NOT NULL,   -- hashed client fingerprint, prevents duplicate votes
    cast_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- One vote per voter per poll
CREATE UNIQUE INDEX IF NOT EXISTS votes_poll_voter_unique
    ON votes (poll_id, voter_token);

-- ── Indexes ──────────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_poll_options_poll_id ON poll_options(poll_id);
CREATE INDEX IF NOT EXISTS idx_votes_poll_id        ON votes(poll_id);
CREATE INDEX IF NOT EXISTS idx_votes_option_id      ON votes(option_id);

-- ── Seed data ────────────────────────────────────────────────────────────────
INSERT INTO polls (id, question, status) VALUES
    ('00000000-0000-0000-0000-000000000001', 'Which cloud provider do you prefer?', 'active'),
    ('00000000-0000-0000-0000-000000000002', 'What is your preferred container runtime?', 'active')
ON CONFLICT (id) DO NOTHING;

INSERT INTO poll_options (poll_id, label, display_order) VALUES
    ('00000000-0000-0000-0000-000000000001', 'AWS',           1),
    ('00000000-0000-0000-0000-000000000001', 'Azure',         2),
    ('00000000-0000-0000-0000-000000000001', 'Google Cloud',  3),
    ('00000000-0000-0000-0000-000000000002', 'Docker',        1),
    ('00000000-0000-0000-0000-000000000002', 'Podman',        2),
    ('00000000-0000-0000-0000-000000000002', 'containerd',    3)
ON CONFLICT DO NOTHING;