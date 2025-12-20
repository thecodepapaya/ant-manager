from __future__ import annotations

import os
import sqlite3
from contextlib import contextmanager
from typing import Any, Dict, Iterable, List, Optional, Tuple

from core.storage.schema import SCHEMA_SQL
from core.utils import data_dir, json_dumps, new_id, sha256_text, utc_now_iso


def db_path() -> str:
    return os.path.join(data_dir(), "ant_manager.db")


@contextmanager
def connect() -> Iterable[sqlite3.Connection]:
    conn = sqlite3.connect(db_path())
    conn.row_factory = sqlite3.Row
    try:
        yield conn
    finally:
        conn.close()


def init_db() -> None:
    with connect() as conn:
        conn.executescript(SCHEMA_SQL)
        # Migration: Add author column to events if it doesn't exist
        try:
            conn.execute("ALTER TABLE events ADD COLUMN author TEXT")
        except sqlite3.OperationalError:
            pass  # Column already exists
        # Migration: Add title column to events if it doesn't exist
        try:
            conn.execute("ALTER TABLE events ADD COLUMN title TEXT")
        except sqlite3.OperationalError:
            pass
        conn.commit()


def _row_to_dict(row: sqlite3.Row) -> Dict[str, Any]:
    return {k: row[k] for k in row.keys()}


def upsert_event(
    *,
    event_id: str,
    timestamp_start: str,
    timestamp_end: Optional[str],
    type: str,
    title: Optional[str] = None,
    author: Optional[str] = None,
    source: str,
    source_id: Optional[str],
    confidence_score: float,
) -> None:
    with connect() as conn:
        conn.execute(
            """
            INSERT INTO events (id,timestamp_start,timestamp_end,type,title,author,source,source_id,confidence_score,created_at)
            VALUES (?,?,?,?,?,?,?,?,?,?)
            ON CONFLICT(id) DO UPDATE SET
              timestamp_start=excluded.timestamp_start,
              timestamp_end=excluded.timestamp_end,
              type=excluded.type,
              title=excluded.title,
              author=excluded.author,
              source=excluded.source,
              source_id=excluded.source_id,
              confidence_score=excluded.confidence_score
            """,
            (
                event_id,
                timestamp_start,
                timestamp_end,
                type,
                title,
                author,
                source,
                source_id,
                confidence_score,
                utc_now_iso(),
            ),
        )
        conn.commit()


def insert_event_if_missing(
    *,
    event_id: Optional[str] = None,
    timestamp_start: str,
    timestamp_end: Optional[str],
    type: str,
    title: Optional[str] = None,
    author: Optional[str] = None,
    source: str,
    source_id: Optional[str],
    confidence_score: float = 1.0,
) -> str:
    init_db()
    # 1. Check if an event with this source/source_id already exists
    if source_id is not None:
        with connect() as conn:
            row = conn.execute(
                "SELECT id FROM events WHERE source=? AND source_id=?",
                (source, source_id),
            ).fetchone()
            if row:
                return str(row["id"])

    # 2. Check if an event with this specific primary ID already exists (e.g. SHA)
    if event_id is not None:
        with connect() as conn:
            row = conn.execute(
                "SELECT id FROM events WHERE id=?",
                (event_id,),
            ).fetchone()
            if row:
                return str(row["id"])

    # 3. Create new event
    eid = event_id or new_id()
    upsert_event(
        event_id=eid,
        timestamp_start=timestamp_start,
        timestamp_end=timestamp_end,
        type=type,
        title=title,
        author=author,
        source=source,
        source_id=source_id,
        confidence_score=confidence_score,
    )
    return eid


def insert_artifact(
    *,
    event_id: str,
    kind: str,
    content: str,
    source_id: Optional[str] = None,
) -> str:
    init_db()
    artifact_id = new_id()
    with connect() as conn:
        conn.execute(
            """
            INSERT INTO artifacts (id,event_id,kind,content,hash,source_id,created_at)
            VALUES (?,?,?,?,?,?,?)
            """,
            (
                artifact_id,
                event_id,
                kind,
                content,
                sha256_text(content),
                source_id,
                utc_now_iso(),
            ),
        )
        conn.commit()
    return artifact_id


def delete_artifacts_by_kind(event_id: str, kind: str) -> None:
    init_db()
    with connect() as conn:
        conn.execute(
            "DELETE FROM artifacts WHERE event_id=? AND kind=?",
            (event_id, kind),
        )
        conn.commit()


def add_note(content: str, timestamp: Optional[str] = None) -> str:
    init_db()
    note_id = new_id()
    ts = timestamp or utc_now_iso()
    with connect() as conn:
        conn.execute(
            "INSERT INTO notes (id,timestamp,content,created_at) VALUES (?,?,?,?)",
            (note_id, ts, content, utc_now_iso()),
        )
        conn.commit()
    return note_id


def update_note(note_id: str, content: str, timestamp: Optional[str] = None) -> bool:
    init_db()
    with connect() as conn:
        if timestamp:
            conn.execute(
                "UPDATE notes SET content=?, timestamp=? WHERE id=?",
                (content, timestamp, note_id),
            )
        else:
            conn.execute(
                "UPDATE notes SET content=? WHERE id=?",
                (content, note_id),
            )
        conn.commit()
        return True


def delete_note(note_id: str) -> bool:
    init_db()
    with connect() as conn:
        conn.execute("DELETE FROM notes WHERE id=?", (note_id,))
        conn.commit()
        return True


def delete_event(event_id: str) -> bool:
    init_db()
    with connect() as conn:
        # artifacts will be deleted automatically due to ON DELETE CASCADE
        conn.execute("DELETE FROM events WHERE id=?", (event_id,))
        conn.commit()
        return True


def list_notes(days: int = 30, start_iso: Optional[str] = None, end_iso: Optional[str] = None) -> List[Dict[str, Any]]:
    init_db()
    with connect() as conn:
        if start_iso and end_iso:
            rows = conn.execute(
                """
                SELECT * FROM notes
                WHERE datetime(timestamp) >= datetime(?) AND datetime(timestamp) < datetime(?)
                ORDER BY timestamp DESC
                """,
                (start_iso, end_iso),
            ).fetchall()
        else:
            rows = conn.execute(
                """
                SELECT * FROM notes
                WHERE datetime(timestamp) >= datetime('now', ?)
                ORDER BY timestamp DESC
                """,
                (f"-{days} days",),
            ).fetchall()
        return [_row_to_dict(r) for r in rows]


def list_events(days: int = 7, author: Optional[str] = None) -> List[Dict[str, Any]]:
    init_db()
    with connect() as conn:
        query = "SELECT * FROM events WHERE datetime(timestamp_start) >= datetime('now', ?)"
        params = [f"-{days} days"]
        if author:
            # Strict filtering: if it's a git commit, it MUST match the author.
            # Otherwise (notes, calendar), we allow NULL author.
            query += " AND (author = ? OR (author IS NULL AND source != 'git'))"
            params.append(author)
        query += " ORDER BY timestamp_start DESC"
        rows = conn.execute(query, params).fetchall()
        return [_row_to_dict(r) for r in rows]


def list_events_between(
    start_iso: str, end_iso: str, author: Optional[str] = None
) -> List[Dict[str, Any]]:
    init_db()
    with connect() as conn:
        query = "SELECT * FROM events WHERE datetime(timestamp_start) >= datetime(?) AND datetime(timestamp_start) < datetime(?)"
        params = [start_iso, end_iso]
        if author:
            # Strict filtering: if it's a git commit, it MUST match the author.
            # Otherwise (notes, calendar), we allow NULL author.
            query += " AND (author = ? OR (author IS NULL AND source != 'git'))"
            params.append(author)
        query += " ORDER BY timestamp_start ASC"
        rows = conn.execute(query, params).fetchall()
        return [_row_to_dict(r) for r in rows]


def list_artifacts_between(
    start_iso: str, end_iso: str, author: Optional[str] = None
) -> List[Dict[str, Any]]:
    init_db()
    with connect() as conn:
        query = """
            SELECT a.* FROM artifacts a
            JOIN events e ON e.id = a.event_id
            WHERE datetime(e.timestamp_start) >= datetime(?) AND datetime(e.timestamp_start) < datetime(?)
        """
        params = [start_iso, end_iso]
        if author:
            # Strict filtering: if it's a git commit, it MUST match the author.
            # Otherwise (notes, calendar), we allow NULL author.
            query += " AND (e.author = ? OR (e.author IS NULL AND e.source != 'git'))"
            params.append(author)
        query += " ORDER BY e.timestamp_start ASC, a.created_at ASC"
        rows = conn.execute(query, params).fetchall()
        return [_row_to_dict(r) for r in rows]


def artifacts_for_event(event_id: str) -> List[Dict[str, Any]]:
    init_db()
    with connect() as conn:
        rows = conn.execute(
            "SELECT * FROM artifacts WHERE event_id=? ORDER BY created_at ASC",
            (event_id,),
        ).fetchall()
        return [_row_to_dict(r) for r in rows]


def get_event(event_id: str) -> Optional[Dict[str, Any]]:
    init_db()
    with connect() as conn:
        row = conn.execute("SELECT * FROM events WHERE id=?", (event_id,)).fetchone()
        return _row_to_dict(row) if row else None


def upsert_narrative(
    *,
    period_start: str,
    period_end: str,
    purpose: str,
    text: str,
    evidence_ids: List[str],
    locked: bool = False,
) -> str:
    init_db()
    now = utc_now_iso()
    nar_id = new_id()
    with connect() as conn:
        # Use ON CONFLICT for atomic upsert and to avoid IntegrityError.
        # We only update if the existing narrative is NOT locked.
        conn.execute(
            """
            INSERT INTO narratives (id,period_start,period_end,purpose,text,evidence_ids,locked,created_at,updated_at)
            VALUES (?,?,?,?,?,?,?,?,?)
            ON CONFLICT(period_start, period_end, purpose) DO UPDATE SET
                text=CASE WHEN narratives.locked=0 THEN excluded.text ELSE narratives.text END,
                evidence_ids=CASE WHEN narratives.locked=0 THEN excluded.evidence_ids ELSE narratives.evidence_ids END,
                updated_at=CASE WHEN narratives.locked=0 THEN excluded.updated_at ELSE narratives.updated_at END,
                locked=CASE WHEN narratives.locked=0 THEN excluded.locked ELSE narratives.locked END
            """,
            (
                nar_id,
                period_start,
                period_end,
                purpose,
                text,
                json_dumps(evidence_ids),
                1 if locked else 0,
                now,
                now,
            ),
        )
        conn.commit()

        # Retrieve the ID of the narrative (might be the existing one or the new one)
        row = conn.execute(
            "SELECT id FROM narratives WHERE period_start=? AND period_end=? AND purpose=?",
            (period_start, period_end, purpose),
        ).fetchone()
        return str(row["id"]) if row else nar_id


def get_narrative(period_start: str, period_end: str, purpose: str) -> Optional[Dict[str, Any]]:
    init_db()
    with connect() as conn:
        row = conn.execute(
            """
            SELECT * FROM narratives
            WHERE period_start=? AND period_end=? AND purpose=?
            """,
            (period_start, period_end, purpose),
        ).fetchone()
        return _row_to_dict(row) if row else None


def update_narrative_text(narrative_id: str, text: str) -> bool:
    init_db()
    now = utc_now_iso()
    with connect() as conn:
        row = conn.execute("SELECT locked FROM narratives WHERE id=?", (narrative_id,)).fetchone()
        if not row:
            return False
        if int(row["locked"]) == 1:
            return False
        conn.execute(
            "UPDATE narratives SET text=?, updated_at=? WHERE id=?",
            (text, now, narrative_id),
        )
        conn.commit()
        return True


def lock_narrative(narrative_id: str) -> bool:
    init_db()
    now = utc_now_iso()
    with connect() as conn:
        row = conn.execute("SELECT id FROM narratives WHERE id=?", (narrative_id,)).fetchone()
        if not row:
            return False
        conn.execute(
            "UPDATE narratives SET locked=1, updated_at=? WHERE id=?",
            (now, narrative_id),
        )
        conn.commit()
        return True


