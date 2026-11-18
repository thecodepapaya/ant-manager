from __future__ import annotations

import json
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, List, Optional, Tuple

from core import config
from core.storage import db
from core.utils import parse_iso


def collect_unified_items(
    repo_paths: List[str],
    since_days: int = 7,
    author_filter: Optional[str] = None,
    start_dt: Optional[datetime] = None,
    end_dt: Optional[datetime] = None,
) -> List[Dict[str, Any]]:
    """
    Collects and deduplicates items from all sources (Git, Calendar, Google Calendar, DB, Notes).
    This logic is shared between the timeline view and narrative generation.
    """
    from core.ingestion.git_ingestion import get_commits
    from core.ingestion.calendar_ingestion import get_calendar_events
    from core.ingestion.google_calendar import get_google_calendar_events

    # Fetch live data
    live_commits = get_commits(
        repo_paths, since_days=max(1, since_days), author_filter=author_filter
    )
    live_cal = get_calendar_events(days=max(1, since_days))
    live_gcal = get_google_calendar_events(days=max(1, since_days))

    # Fetch DB events
    db_evs = db.list_events(days=max(1, since_days), author=author_filter)

    # Fetch manual notes
    start_iso = start_dt.isoformat().replace("+00:00", "Z") if start_dt else None
    end_iso = end_dt.isoformat().replace("+00:00", "Z") if end_dt else None
    
    if start_iso and end_iso:
        all_notes = db.list_notes(start_iso=start_iso, end_iso=end_iso)
    else:
        all_notes = db.list_notes(days=max(1, since_days))

    def is_in_range(ts_str: str) -> bool:
        if not ts_str:
            return False
        if not start_dt or not end_dt:
            return True
        try:
            # Handle Google's all-day format (YYYY-MM-DD)
            if "T" not in ts_str:
                ts_str += "T00:00:00Z"
            t = parse_iso(ts_str)
            return start_dt <= t <= end_dt
        except Exception:
            return False

    items = []
    seen_source_ids = set()
    seen_ids = set()

    # 1. Process live commits
    for c in live_commits:
        if is_in_range(c.date_iso):
            if c.sha in seen_ids:
                continue
            source_id = f"{c.repo_path}:{c.sha}"
            items.append(
                {
                    "kind": "event",
                    "id": c.sha,
                    "timestamp": c.date_iso,
                    "type": "code.commit",
                    "source": "git",
                    "source_id": source_id,
                    "title": c.subject,
                    "repo_path": c.repo_path,
                }
            )
            seen_source_ids.add(source_id)
            seen_ids.add(c.sha)

    # 2. Process live calendar
    for e in live_cal:
        if is_in_range(e.start_iso):
            items.append(
                {
                    "kind": "event",
                    "id": e.id,
                    "timestamp": e.start_iso,
                    "type": "calendar.event",
                    "source": "calendar",
                    "source_id": e.id,
                    "title": e.title,
                    "duration": e.duration_minutes,
                    "notes": e.notes,
                    "calendar_name": e.calendar_name,
                }
            )
            seen_source_ids.add(e.id)
            seen_ids.add(e.id)

    # 3. Process live google calendar
    for e in live_gcal:
        ts = e.get("start_iso")
        if ts and is_in_range(ts):
            items.append(
                {
                    "kind": "event",
                    "id": e["id"],
                    "timestamp": ts,
                    "type": "calendar.event",
                    "source": "google_calendar",
                    "source_id": e["id"],
                    "title": e["title"],
                    "duration": e.get("duration_minutes"),
                    "notes": e.get("notes"),
                    "calendar_name": e.get("calendar_name"),
                }
            )
            seen_source_ids.add(e["id"])
            seen_ids.add(e["id"])

    # 4. Process DB events (excluding live sources to avoid duplication)
    for e in db_evs:
        eid = e.get("id")
        sid = e.get("source_id")
        if e.get("source") in ["git", "calendar", "google_calendar"]:
            if (sid and sid in seen_source_ids) or (eid and eid in seen_ids):
                continue
        ts = e.get("timestamp_start")
        if ts and is_in_range(ts):
            title = e.get("title") or f"External Event ({e['source']})"
            items.append(
                {
                    "kind": "event",
                    "id": e["id"],
                    "timestamp": ts,
                    "type": e["type"],
                    "source": e["source"],
                    "source_id": e["source_id"],
                    "title": title,
                }
            )
            seen_ids.add(e["id"])

    # 5. Add manual notes from DB
    for n in all_notes:
        ts = n.get("timestamp")
        if ts and is_in_range(ts):
            items.append(
                {
                    "kind": "note",
                    "id": n["id"],
                    "timestamp": ts,
                    "content": n["content"],
                }
            )

    return items

