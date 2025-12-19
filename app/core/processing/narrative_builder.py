from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime, timedelta, timezone
from typing import Any, Dict, List, Optional, Tuple

from core import config
from core.processing.llm_client import OllamaError, generate_text
from core.processing.prompts import daily_prompt, wins_prompt
from core.storage import db
from core.utils import json_dumps, parse_iso


def _local_day_bounds(day: date) -> Tuple[str, str]:
    # Use local time boundaries but store ISO with timezone.
    start = datetime.combine(day, datetime.min.time()).astimezone()
    end = (start + timedelta(days=1)).astimezone()
    return start.isoformat(), end.isoformat()


def _collect_notes_text(start_iso: str, end_iso: str) -> str:
    # Notes table is timestamped; keep only those in range.
    notes = db.list_notes(days=3650)  # filter in-memory for now (simple v0)
    kept = []
    for n in notes:
        ts = str(n.get("timestamp") or "")
        if not ts:
            continue
        try:
            t = parse_iso(ts)
        except Exception:
            continue
        if start_iso <= t.isoformat() < end_iso:
            kept.append(f"- {n.get('content','')}".strip())
    return "\n".join(kept)


def _collect_evidence_snippets(start_iso: str, end_iso: str, limit: int = 30) -> Tuple[str, List[str]]:
    arts = db.list_artifacts_between(start_iso, end_iso)
    snippets: List[str] = []
    evidence_event_ids: List[str] = []
    for a in arts[:limit]:
        event_id = str(a.get("event_id"))
        if event_id and event_id not in evidence_event_ids:
            evidence_event_ids.append(event_id)
        kind = a.get("kind")
        content = a.get("content", "")
        snippets.append(f"[{kind}] {content}".strip())
    return "\n\n".join(snippets), evidence_event_ids


def generate_daily(day: Optional[date] = None) -> Dict[str, Any]:
    db.init_db()
    cfg = config.load_config()
    day = day or date.today()
    start_iso, end_iso = _local_day_bounds(day)

    evidence_snips, evidence_event_ids = _collect_evidence_snippets(start_iso, end_iso)
    notes_text = _collect_notes_text(start_iso, end_iso)

    if not evidence_snips and not notes_text:
        text = "Summary:\n- No tracked work evidence for this day.\n\nKey Work:\n- \n\nBlockers:\n- \n\nEvidence Used:\n- \n"
    else:
        prompt = daily_prompt(evidence_snips or "(none)", notes_text or "(none)")
        try:
            text = generate_text(model=cfg.llm_model, prompt=prompt)
        except OllamaError as e:
            # v0 fallback: deterministic, evidence-only (no LLM).
            text = (
                "Summary:\n- (LLM unavailable) Evidence captured below.\n\n"
                "Key Work:\n- \n\nBlockers:\n- \n\nEvidence Used:\n"
                + "\n".join([f"- {line}" for line in (evidence_snips.splitlines()[:20] if evidence_snips else [])])
            )

    nar_id = db.upsert_narrative(
        period_start=start_iso,
        period_end=end_iso,
        purpose="daily",
        text=text,
        evidence_ids=evidence_event_ids,
        locked=False,
    )

    return {
        "ok": True,
        "purpose": "daily",
        "date": day.isoformat(),
        "period_start": start_iso,
        "period_end": end_iso,
        "narrative_id": nar_id,
        "text": text,
        "evidence_event_ids": evidence_event_ids,
        "notes": notes_text,
    }


def generate_wins(period: str = "weekly") -> Dict[str, Any]:
    db.init_db()
    cfg = config.load_config()
    today = date.today()

    if period == "monthly":
        start_day = today - timedelta(days=30)
        label = "monthly"
    else:
        start_day = today - timedelta(days=7)
        label = "weekly"

    start_iso, _ = _local_day_bounds(start_day)
    _, end_iso = _local_day_bounds(today)

    evidence_snips, evidence_event_ids = _collect_evidence_snippets(start_iso, end_iso, limit=60)
    notes_text = _collect_notes_text(start_iso, end_iso)

    if not evidence_snips and not notes_text:
        text = "Wins:\n- No tracked work evidence for this period.\n\nEvidence Used:\n- \n"
    else:
        prompt = wins_prompt(evidence_snips or "(none)", notes_text or "(none)", period_label=label)
        try:
            text = generate_text(model=cfg.llm_model, prompt=prompt)
        except OllamaError:
            text = (
                "Wins:\n- (LLM unavailable) Evidence captured below.\n\nEvidence Used:\n"
                + "\n".join([f"- {line}" for line in (evidence_snips.splitlines()[:30] if evidence_snips else [])])
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


