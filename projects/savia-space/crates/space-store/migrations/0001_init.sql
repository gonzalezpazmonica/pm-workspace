-- Savia Space schema v1. Private local state; never stored in Git.

CREATE TABLE sessions (
    id            TEXT PRIMARY KEY,
    project_id    TEXT NOT NULL,
    title         TEXT NOT NULL,
    revision      INTEGER NOT NULL CHECK (revision >= 1),
    state         TEXT NOT NULL CHECK (state IN ('OPEN', 'ARCHIVED')),
    created_at    TEXT NOT NULL,
    updated_at    TEXT NOT NULL,
    last_turn_at  TEXT
);

CREATE TABLE events (
    session_id   TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    sequence     INTEGER NOT NULL CHECK (sequence >= 1),
    event_id     TEXT NOT NULL UNIQUE,
    run_id       TEXT,
    occurred_at  TEXT NOT NULL,
    body         TEXT NOT NULL,
    PRIMARY KEY (session_id, sequence)
);

CREATE TABLE runs (
    id                   TEXT PRIMARY KEY,
    session_id           TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    revision             INTEGER NOT NULL CHECK (revision >= 1),
    state                TEXT NOT NULL,
    preset_id            TEXT,
    preset_version       TEXT,
    provider_profile_id  TEXT,
    manifest_id          TEXT,
    terminal_reason      TEXT,
    created_at           TEXT NOT NULL,
    updated_at           TEXT NOT NULL
);

-- At most one non-terminal run per session, enforced by the database itself.
CREATE UNIQUE INDEX runs_one_active_per_session ON runs(session_id)
    WHERE state NOT IN ('COMPLETED', 'FAILED', 'CANCELLED', 'INTERRUPTED');

CREATE TABLE attempts (
    id          TEXT PRIMARY KEY,
    run_id      TEXT NOT NULL UNIQUE REFERENCES runs(id) ON DELETE CASCADE,
    state       TEXT NOT NULL CHECK (state IN ('RESERVED', 'DISPATCH_INTENT', 'OUTPUT_COMPLETE', 'FINISHED', 'UNKNOWN')),
    epoch       INTEGER NOT NULL,
    started_at  TEXT,
    ended_at    TEXT
);

CREATE TABLE messages (
    id                TEXT PRIMARY KEY,
    session_id        TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    run_id            TEXT REFERENCES runs(id) ON DELETE CASCADE,
    role              TEXT NOT NULL CHECK (role IN ('user', 'assistant')),
    status            TEXT NOT NULL CHECK (status IN ('partial', 'final', 'interrupted', 'failed')),
    created_sequence  INTEGER NOT NULL,
    text              TEXT NOT NULL,
    citations         TEXT NOT NULL DEFAULT '[]',
    manifest_id       TEXT,
    validation        TEXT,
    UNIQUE (session_id, created_sequence)
);

CREATE TABLE previews (
    id             TEXT PRIMARY KEY,
    session_id     TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    run_id         TEXT NOT NULL UNIQUE,
    request_hash   TEXT NOT NULL,
    manifest_hash  TEXT NOT NULL,
    payload_hash   TEXT NOT NULL,
    manifest       TEXT NOT NULL,
    body           BLOB NOT NULL,
    expires_at     TEXT NOT NULL,
    consumed       INTEGER NOT NULL DEFAULT 0 CHECK (consumed IN (0, 1))
);

CREATE TABLE outputs (
    run_id  TEXT PRIMARY KEY REFERENCES runs(id) ON DELETE CASCADE,
    raw     BLOB NOT NULL
);

CREATE TABLE idempotency (
    principal     TEXT NOT NULL,
    operation     TEXT NOT NULL,
    target        TEXT NOT NULL,
    key           TEXT NOT NULL,
    request_hash  TEXT NOT NULL,
    response      TEXT NOT NULL,
    created_at    TEXT NOT NULL,
    PRIMARY KEY (principal, operation, target, key)
);

CREATE TABLE web_sessions (
    token_hash    TEXT PRIMARY KEY,
    created_at    TEXT NOT NULL,
    last_used_at  TEXT NOT NULL,
    revoked       INTEGER NOT NULL DEFAULT 0 CHECK (revoked IN (0, 1))
);

-- Private captures: full base text of a note read with the person's own reader credential.
CREATE TABLE captures (
    id            TEXT PRIMARY KEY,
    project_id    TEXT NOT NULL,
    session_id    TEXT REFERENCES sessions(id) ON DELETE CASCADE,
    dome_id       TEXT NOT NULL,
    resource_id   TEXT NOT NULL,
    title         TEXT NOT NULL,
    content_hash  TEXT NOT NULL,
    text_base     TEXT NOT NULL,
    obtained_at   TEXT NOT NULL
);

CREATE TABLE selections (
    session_id  TEXT PRIMARY KEY REFERENCES sessions(id) ON DELETE CASCADE,
    id          TEXT NOT NULL,
    revision    INTEGER NOT NULL CHECK (revision >= 1),
    refs        TEXT NOT NULL
);
