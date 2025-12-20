from __future__ import annotations

import json
from dataclasses import dataclass
from datetime import date, datetime, timedelta, timezone
from typing import Any, Dict, List, Optional, Tuple

from core import config
from core.processing.llm_client import OllamaError, generate_text
from core.processing.prompts import daily_prompt, wins_prompt
from core.storage import db
from core.utils import json_dumps, log_generation, parse_iso


def _local_day_bounds(day: date) -> Tuple[str, str]:
    # Calculate start and end of the day in local time, then convert to UTC.
    # This ensures we cover the user's full local day regardless of the server's timezone.
    start_local = datetime.combine(day, datetime.min.time()).astimezone()
    end_local = datetime.combine(day, datetime.max.time()).astimezone()
    
    # Return as UTC ISO strings with 'Z' suffix, stripping microseconds for DB consistency
    start_utc = start_local.astimezone(timezone.utc).replace(microsecond=0)
    end_utc = end_local.astimezone(timezone.utc).replace(microsecond=0)
    
    return start_utc.isoformat().replace("+00:00", "Z"), end_utc.isoformat().replace("+00:00", "Z")


def _collect_notes_text(start_iso: str, end_iso: str) -> str:
    # Notes table is timestamped; keep only those in range.
    # start_iso and end_iso are already in UTC 'Z' format.
    notes = db.list_notes(days=3650)  # filter in-memory for simplicity
    
    start_dt = parse_iso(start_iso)
    end_dt = parse_iso(end_iso)
    
    kept = []
    for n in notes:
        ts = str(n.get("timestamp") or "")
        if not ts:
            continue
        try:
            t = parse_iso(ts)
            if start_dt <= t <= end_dt:
                kept.append(f"- {n.get('content','')}".strip())
        except Exception:
            continue
    return "\n".join(kept)


def _collect_evidence_snippets(
    start_iso: str, end_iso: str, author: Optional[str] = None, limit: int = 30
) -> Tuple[str, List[str]]:
    # start_iso and end_iso are UTC 'Z' strings.
    start_dt = parse_iso(start_iso)
    end_dt = parse_iso(end_iso)
    
    # 1. Fetch from DB
    arts = db.list_artifacts_between(start_iso, end_iso, author=author)
    
    # 2. Fetch from Live Git
    from core.ingestion.git_ingestion import get_commits, _git_show_compact
    cfg = config.load_config()
    
    # Calculate days back needed from now to know how many days to look back
    now_utc = datetime.now(timezone.utc)
    days_back = (now_utc - start_dt).days + 2 # buffer
    
    live_commits = get_commits(cfg.repo_paths, since_days=max(1, days_back), author_filter=author)
    
    # 3. Fetch from Live Calendar
    from core.ingestion.calendar_ingestion import get_calendar_events
    from core.ingestion.google_calendar import get_google_calendar_events
    live_cal = get_calendar_events(days=max(1, days_back))
    live_gcal = get_google_calendar_events(days=max(1, days_back))
    
    # Proper datetime filtering for live data
    def is_in_range(ts_str: str) -> bool:
        try:
            t = parse_iso(ts_str)
            return start_dt <= t <= end_dt
        except Exception:
            return False

    live_commits = [c for c in live_commits if is_in_range(c.date_iso)]
    live_cal = [e for e in live_cal if is_in_range(e.start_iso)]
    live_gcal = [e for e in live_gcal if is_in_range(e["start_iso"])]
    
    # 4. Filter and Limit Git Commits Early
    live_commits = live_commits[:limit]

    snippets: List[str] = []
    evidence_event_ids: List[str] = []
    
    # Combine DB artifacts
    for a in arts:
        event_id = str(a.get("event_id"))
        if event_id and event_id not in evidence_event_ids:
            evidence_event_ids.append(event_id)
        kind = a.get("kind")
        content = a.get("content", "")
        snippets.append(f"[{kind}] {content}".strip())
        
    # Combine Live Git commits (convert to snippets)
    for c in live_commits:
        if c.sha not in evidence_event_ids:
            evidence_event_ids.append(c.sha)
            # Fetch details for snippet
            try:
                compact = _git_show_compact(c.repo_path, c.sha)
                snippets.append(f"[git.commit] {compact}".strip())
            except Exception:
                snippets.append(f"[git.commit] {c.sha}: {c.subject}".strip())

    # Combine Live Calendar events
    for e in live_cal:
        if e.id not in evidence_event_ids:
            evidence_event_ids.append(e.id)
            content = f"Meeting: {e.title} ({e.duration_minutes}m) in {e.calendar_name}"
            if e.notes:
                content += f"\nNotes: {e.notes}"
            snippets.append(f"[calendar.event] {content}".strip())

    # Combine Live Google Calendar events
    for e in live_gcal:
        if e["id"] not in evidence_event_ids:
            evidence_event_ids.append(e["id"])
            content = f"Meeting: {e['title']} ({e['duration_minutes']}m) in {e['calendar_name']}"
            if e["notes"]:
                content += f"\nNotes: {e['notes']}"
            snippets.append(f"[google_calendar.event] {content}".strip())

    # Limit total snippets
    final_snippets = snippets[:limit]
    final_ids = evidence_event_ids[:limit]
    
    return "\n\n".join(final_snippets), final_ids


def generate_narrative(
    target_date: Optional[date] = None,
    period: str = "daily",
    days: int = 1,
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
    force_regenerate: bool = False,
) -> Dict[str, Any]:
    db.init_db()
    cfg = config.load_config()
    
    if start_date and end_date:
        start_day = start_date
        end_day = end_date
        # Use the period name as purpose if it's one of the standard ones
        purpose = period if period in ["daily", "weekly", "monthly"] else "custom"
    else:
        end_day = target_date or date.today()
        start_day = end_day - timedelta(days=max(days - 1, 0))
        purpose = period

    # Use _local_day_bounds to get consistent UTC 'Z' strings for the start and end of the days
    start_iso, _ = _local_day_bounds(start_day)
    _, end_iso = _local_day_bounds(end_day)

    # Check if a narrative already exists for this period+purpose
    if not force_regenerate:
        existing = db.get_narrative(start_iso, end_iso, purpose=purpose)
        if existing:
            ev_ids = existing.get("evidence_ids", [])
            if isinstance(ev_ids, str):
                try:
                    ev_ids = json.loads(ev_ids)
                except Exception:
                    ev_ids = []
            return {
                "ok": True,
                "purpose": purpose,
                "date": end_day.isoformat(),
                "period_start": start_iso,
                "period_end": end_iso,
                "narrative_id": existing["id"],
                "text": existing["text"],
                "evidence_event_ids": ev_ids,
                "locked": existing.get("locked", False),
            }

    evidence_snips, evidence_event_ids = _collect_evidence_snippets(
        start_iso, end_iso, author=cfg.user_name or None
    )
    notes_text = _collect_notes_text(start_iso, end_iso)

    llm_ok = True
    if not evidence_snips and not notes_text:
        text = f"Summary ({purpose}):\n- No tracked work evidence for this period.\n\nKey Work:\n- \n\nBlockers:\n- \n\nEvidence Used:\n- \n"
    else:
        prompt = daily_prompt(evidence_snips or "(none)", notes_text or "(none)")
        
        try:
            text = generate_text(model=cfg.llm_model, prompt=prompt)
            # Log successful generation
            log_generation(
                purpose=purpose,
                prompt=prompt,
                output=text,
                evidence=evidence_snips or "(none)",
                notes=notes_text or "(none)"
            )
        except OllamaError as e:
            llm_ok = False
            text = (
                f"Summary ({purpose}):\n- (LLM unavailable) Evidence captured below.\n\n"
                "Key Work:\n- \n\nBlockers:\n- \n\nEvidence Used:\n"
                + "\n".join([f"- {line}" for line in (evidence_snips.splitlines()[:20] if evidence_snips else [])])
            )
            # Log failure
            log_generation(
                purpose=f"{purpose}_failed",
                prompt=prompt,
                output=f"Error: {str(e)}",
                evidence=evidence_snips or "(none)",
                notes=notes_text or "(none)"
            )

    nar_id = db.upsert_narrative(
        period_start=start_iso,
        period_end=end_iso,
        purpose=purpose,
        text=text,
        evidence_ids=evidence_event_ids,
        locked=False,
    )

    return {
        "ok": True,
        "llm_ok": llm_ok,
        "purpose": purpose,
        "date": end_day.isoformat(),
        "period_start": start_iso,
        "period_end": end_iso,
        "narrative_id": nar_id,
        "text": text,
        "evidence_event_ids": evidence_event_ids,
        "notes": notes_text,
    }


def generate_wins(
    period: str = "weekly",
    target_date: Optional[date] = None,
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
) -> Dict[str, Any]:
    db.init_db()
    cfg = config.load_config()

    if start_date and end_date:
        start_day = start_date
        end_day = end_date
        label = "custom"
    elif target_date:
        # Use the target date as the end of the period
        end_day = target_date
        if period == "monthly":
            start_day = target_date - timedelta(days=30)
            label = "monthly"
        elif period == "daily":
            start_day = target_date
            label = "daily"
        else:
            start_day = target_date - timedelta(days=7)
            label = "weekly"
    else:
        # Default: use today as end
        today = date.today()
        end_day = today
        if period == "monthly":
            start_day = today - timedelta(days=30)
            label = "monthly"
        elif period == "daily":
            start_day = today
            label = "daily"
        else:
            start_day = today - timedelta(days=7)
            label = "weekly"

    start_iso, _ = _local_day_bounds(start_day)
    _, end_iso = _local_day_bounds(end_day)

    # Check if a narrative already exists for this period
    existing = db.get_narrative(start_iso, end_iso, purpose=f"wins.{label}")
    if existing:
        ev_ids = existing.get("evidence_ids", [])
        if isinstance(ev_ids, str):
            try:
                ev_ids = json.loads(ev_ids)
            except Exception:
                ev_ids = []
        return {
            "ok": True,
            "purpose": f"wins.{label}",
            "period_start": start_iso,
            "period_end": end_iso,
            "narrative_id": existing["id"],
            "text": existing["text"],
            "evidence_event_ids": ev_ids,
            "locked": existing.get("locked", False),
        }

    evidence_snips, evidence_event_ids = _collect_evidence_snippets(
        start_iso, end_iso, author=cfg.user_name or None, limit=60
    )
    notes_text = _collect_notes_text(start_iso, end_iso)

    if not evidence_snips and not notes_text:
        text = "Wins:\n- No tracked work evidence for this period.\n\nEvidence Used:\n- \n"
    else:
        prompt = wins_prompt(evidence_snips or "(none)", notes_text or "(none)", period_label=label)
        try:
            text = generate_text(model=cfg.llm_model, prompt=prompt)
            # Log successful generation
            log_generation(
                purpose=f"wins.{label}",
                prompt=prompt,
                output=text,
                evidence=evidence_snips or "(none)",
                notes=notes_text or "(none)"
            )
        except OllamaError as e:
            text = (
                "Wins:\n- (LLM unavailable) Evidence captured below.\n\nEvidence Used:\n"
                + "\n".join([f"- {line}" for line in (evidence_snips.splitlines()[:30] if evidence_snips else [])])
            )
            # Log failure
            log_generation(
                purpose=f"wins.{label}_failed",
                prompt=prompt,
                output=f"Error: {str(e)}",
                evidence=evidence_snips or "(none)",
                notes=notes_text or "(none)"
            )

    nar_id = db.upsert_narrative(
        period_start=start_iso,
        period_end=end_iso,
        purpose=f"wins.{label}",
        text=text,
        evidence_ids=evidence_event_ids,
        locked=False,
    )

    return {
        "ok": True,
        "purpose": f"wins.{label}",
        "period_start": start_iso,
        "period_end": end_iso,
        "narrative_id": nar_id,
        "text": text,
        "evidence_event_ids": evidence_event_ids,
    }
