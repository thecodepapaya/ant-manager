from __future__ import annotations

SCHEMA_SQL = """
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS events (
  id TEXT PRIMARY KEY,
  timestamp_start TEXT NOT NULL,
  timestamp_end TEXT,
  type TEXT NOT NULL,
  author TEXT,
  source TEXT NOT NULL,
  source_id TEXT,
  confidence_score REAL NOT NULL DEFAULT 1.0,
  created_at TEXT NOT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_events_source_sourceid ON events(source, source_id);
CREATE INDEX IF NOT EXISTS idx_events_time ON events(timestamp_start);

CREATE TABLE IF NOT EXISTS artifacts (
  id TEXT PRIMARY KEY,
  event_id TEXT NOT NULL,
  kind TEXT NOT NULL,
  content TEXT NOT NULL,
  hash TEXT NOT NULL,
  source_id TEXT,
  created_at TEXT NOT NULL,
  FOREIGN KEY(event_id) REFERENCES events(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_artifacts_event ON artifacts(event_id);

CREATE TABLE IF NOT EXISTS narratives (
  id TEXT PRIMARY KEY,
  period_start TEXT NOT NULL,
  period_end TEXT NOT NULL,
  purpose TEXT NOT NULL,
  text TEXT NOT NULL,
  evidence_ids TEXT NOT NULL,
  locked INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_narratives_period_purpose ON narratives(period_start, period_end, purpose);

CREATE TABLE IF NOT EXISTS blockers (
  id TEXT PRIMARY KEY,
  related_event_ids TEXT NOT NULL,
  category TEXT NOT NULL,
  external INTEGER NOT NULL,
  description TEXT NOT NULL,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS notes (
  id TEXT PRIMARY KEY,
  timestamp TEXT NOT NULL,
  content TEXT NOT NULL,
  created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_notes_time ON notes(timestamp);
"""


