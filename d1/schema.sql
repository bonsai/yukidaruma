-- Yukidaruma D1 control-plane schema
-- D1 stores metadata and bounded small text payloads. Larger files live in Google Drive.
-- All timestamps are UTC ISO-8601 text.

PRAGMA foreign_keys = ON;

-- Dataset catalog
CREATE TABLE IF NOT EXISTS datasets (
  id            TEXT PRIMARY KEY,
  name          TEXT NOT NULL,
  description   TEXT,
  storage_backend TEXT NOT NULL DEFAULT 'google_drive' CHECK (storage_backend IN ('d1', 'google_drive')),
  storage_ref   TEXT NOT NULL,
  storage_backend TEXT NOT NULL CHECK (storage_backend IN ('d1', 'google_drive')),
  storage_ref   TEXT NOT NULL,
  uri           TEXT NOT NULL,
  format        TEXT NOT NULL CHECK (format IN ('parquet', 'csv', 'jsonl', 'json', 'notebook', 'tar.gz', 'zip')),
  size_bytes    INTEGER,
  checksum      TEXT,
  schema_json   TEXT,
  tags_json     TEXT,
  source_json   TEXT,
  created_at    TEXT NOT NULL,
  updated_at    TEXT NOT NULL,
  archived_at   TEXT
);

CREATE INDEX IF NOT EXISTS idx_datasets_name ON datasets(name);
CREATE INDEX IF NOT EXISTS idx_datasets_format ON datasets(format);
CREATE INDEX IF NOT EXISTS idx_datasets_archived ON datasets(archived_at);

-- Small UTF-8 dataset payloads only. API enforces a configurable byte limit.
CREATE TABLE IF NOT EXISTS dataset_contents (
  dataset_id  TEXT PRIMARY KEY REFERENCES datasets(id) ON DELETE CASCADE,
  content_text TEXT NOT NULL,
  byte_length INTEGER NOT NULL CHECK (byte_length >= 0),
  checksum TEXT,
  updated_at TEXT NOT NULL
);

-- Job definitions (immutable intent + mutable state)
CREATE TABLE IF NOT EXISTS jobs (
  id                  TEXT PRIMARY KEY,
  task                TEXT NOT NULL,
  requested_runtime   TEXT NOT NULL,
  language            TEXT NOT NULL,
  payload_json        TEXT NOT NULL,
  state               TEXT NOT NULL CHECK (state IN (
                        'queued', 'claimed', 'dispatched', 'running',
                        'succeeded', 'failed', 'cancel_requested',
                        'cancelled', 'timed_out'
                      )),
  priority            INTEGER NOT NULL DEFAULT 50,
  submitted_by        TEXT NOT NULL,
  idempotency_key     TEXT,
  created_at          TEXT NOT NULL,
  updated_at          TEXT NOT NULL,
  cancel_requested_at TEXT
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_jobs_idempotency
  ON jobs(idempotency_key) WHERE idempotency_key IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_jobs_state ON jobs(state);
CREATE INDEX IF NOT EXISTS idx_jobs_created ON jobs(created_at);
CREATE INDEX IF NOT EXISTS idx_jobs_submitted_by ON jobs(submitted_by);

-- Individual execution attempts
CREATE TABLE IF NOT EXISTS runs (
  id              TEXT PRIMARY KEY,
  job_id          TEXT NOT NULL REFERENCES jobs(id),
  attempt         INTEGER NOT NULL,
  runner_id       TEXT,
  state           TEXT NOT NULL CHECK (state IN (
                    'claimed', 'dispatched', 'running',
                    'succeeded', 'failed', 'cancelled', 'timed_out'
                  )),
  started_at      TEXT,
  finished_at     TEXT,
  heartbeat_at    TEXT,
  duration_ms     INTEGER,
  code_revision   TEXT,
  environment_json TEXT,
  error_code      TEXT,
  error_message   TEXT,
  UNIQUE (job_id, attempt)
);

CREATE INDEX IF NOT EXISTS idx_runs_job ON runs(job_id);
CREATE INDEX IF NOT EXISTS idx_runs_runner ON runs(runner_id);
CREATE INDEX IF NOT EXISTS idx_runs_state ON runs(state);

-- Output artifact metadata; payload is in dataset_contents (small) or Google Drive (large).
CREATE TABLE IF NOT EXISTS artifacts (
  id            TEXT PRIMARY KEY,
  run_id        TEXT NOT NULL REFERENCES runs(id),
  name          TEXT NOT NULL,
  uri           TEXT NOT NULL,
  format        TEXT,
  size_bytes    INTEGER,
  checksum      TEXT,
  content_type  TEXT,
  created_at    TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_artifacts_run ON artifacts(run_id);

-- Registered compute runners
CREATE TABLE IF NOT EXISTS runners (
  id                  TEXT PRIMARY KEY,
  type                TEXT NOT NULL CHECK (type IN ('muse_vm', 'colab', 'kaggle')),
  status              TEXT NOT NULL CHECK (status IN ('online', 'offline', 'disabled', 'draining')),
  capabilities_json   TEXT,
  labels_json         TEXT,
  last_heartbeat_at   TEXT,
  registered_at       TEXT NOT NULL,
  disabled_at         TEXT
);

CREATE INDEX IF NOT EXISTS idx_runners_status ON runners(status);
CREATE INDEX IF NOT EXISTS idx_runners_type ON runners(type);

-- Append-only state / audit events
CREATE TABLE IF NOT EXISTS job_events (
  id            TEXT PRIMARY KEY,
  job_id        TEXT NOT NULL REFERENCES jobs(id),
  run_id        TEXT,
  event_type    TEXT NOT NULL,
  from_state    TEXT,
  to_state      TEXT,
  message       TEXT,
  metadata_json TEXT,
  created_at    TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_job_events_job ON job_events(job_id);
CREATE INDEX IF NOT EXISTS idx_job_events_created ON job_events(created_at);
