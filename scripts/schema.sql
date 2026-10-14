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

-- ── Additional tech polls ────────────────────────────────────────────────────
INSERT INTO polls (id, question, status) VALUES
    ('00000000-0000-0000-0000-000000000003', 'Which programming language do you use most?', 'active'),
    ('00000000-0000-0000-0000-000000000004', 'Which frontend framework do you prefer?', 'active'),
    ('00000000-0000-0000-0000-000000000005', 'Which database do you reach for first?', 'active'),
    ('00000000-0000-0000-0000-000000000006', 'Which code editor or IDE is your daily driver?', 'active'),
    ('00000000-0000-0000-0000-000000000007', 'Which CI/CD tool do you prefer?', 'active'),
    ('00000000-0000-0000-0000-000000000008', 'Which infrastructure-as-code tool do you use?', 'active'),
    ('00000000-0000-0000-0000-000000000009', 'Which operating system do you develop on?', 'active'),
    ('00000000-0000-0000-0000-000000000010', 'Which AI coding assistant do you use most?', 'active')
ON CONFLICT (id) DO NOTHING;

-- poll_options has no natural unique key, so guard with NOT EXISTS to keep
-- this block safe to re-run against an already-seeded database.
INSERT INTO poll_options (poll_id, label, display_order)
SELECT v.poll_id::uuid, v.label, v.display_order
FROM (VALUES
    ('00000000-0000-0000-0000-000000000003', 'Python',      1),
    ('00000000-0000-0000-0000-000000000003', 'JavaScript / TypeScript', 2),
    ('00000000-0000-0000-0000-000000000003', 'Java',        3),
    ('00000000-0000-0000-0000-000000000003', 'Go',          4),
    ('00000000-0000-0000-0000-000000000003', 'Rust',        5),

    ('00000000-0000-0000-0000-000000000004', 'React',       1),
    ('00000000-0000-0000-0000-000000000004', 'Vue',         2),
    ('00000000-0000-0000-0000-000000000004', 'Angular',     3),
    ('00000000-0000-0000-0000-000000000004', 'Svelte',      4),

    ('00000000-0000-0000-0000-000000000005', 'PostgreSQL',  1),
    ('00000000-0000-0000-0000-000000000005', 'MySQL',       2),
    ('00000000-0000-0000-0000-000000000005', 'MongoDB',     3),
    ('00000000-0000-0000-0000-000000000005', 'Redis',       4),
    ('00000000-0000-0000-0000-000000000005', 'SQLite',      5),

    ('00000000-0000-0000-0000-000000000006', 'VS Code',     1),
    ('00000000-0000-0000-0000-000000000006', 'JetBrains IDEs', 2),
    ('00000000-0000-0000-0000-000000000006', 'Vim / Neovim', 3),
    ('00000000-0000-0000-0000-000000000006', 'Emacs',       4),

    ('00000000-0000-0000-0000-000000000007', 'GitHub Actions', 1),
    ('00000000-0000-0000-0000-000000000007', 'GitLab CI',   2),
    ('00000000-0000-0000-0000-000000000007', 'Jenkins',     3),
    ('00000000-0000-0000-0000-000000000007', 'CircleCI',    4),

    ('00000000-0000-0000-0000-000000000008', 'Terraform',   1),
    ('00000000-0000-0000-0000-000000000008', 'Pulumi',      2),
    ('00000000-0000-0000-0000-000000000008', 'CloudFormation', 3),
    ('00000000-0000-0000-0000-000000000008', 'Ansible',     4),

    ('00000000-0000-0000-0000-000000000009', 'Linux',       1),
    ('00000000-0000-0000-0000-000000000009', 'macOS',       2),
    ('00000000-0000-0000-0000-000000000009', 'Windows',     3),
    ('00000000-0000-0000-0000-000000000009', 'Windows + WSL', 4),

    ('00000000-0000-0000-0000-000000000010', 'Claude Code', 1),
    ('00000000-0000-0000-0000-000000000010', 'GitHub Copilot', 2),
    ('00000000-0000-0000-0000-000000000010', 'Cursor',      3),
    ('00000000-0000-0000-0000-000000000010', 'None',        4)
) AS v(poll_id, label, display_order)
WHERE NOT EXISTS (
    SELECT 1 FROM poll_options o
    WHERE o.poll_id = v.poll_id::uuid AND o.label = v.label
);
