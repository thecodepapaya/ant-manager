from __future__ import annotations

import json
from dataclasses import dataclass
from datetime import date, datetime, timedelta, timezone
from typing import Any, Dict, List, Optional, Tuple

from core import config
from core.processing.llm_client import LLMError, generate_text
from core.processing.prompts import daily_prompt, wins_prompt
from core.storage import db
from core.utils import json_dumps, log_llm_request, log_llm_response, parse_iso


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
    notes = db.list_notes(start_iso=start_iso, end_iso=end_iso)

    kept = []
    for n in notes:
        ts = str(n.get("timestamp") or "")
        if not ts:
            continue
        try:
            t = parse_iso(ts)
            # Format timestamp for better LLM context (HH:MM)
            ts_display = t.astimezone().strftime("%H:%M")
            kept.append(f"[{ts_display}] {n.get('content','')}".strip())
        except Exception:
            continue
    return "\n".join(kept)


def _collect_evidence_snippets(
    start_iso: str, end_iso: str, author: Optional[str] = None, limit: int = 200
) -> Tuple[str, List[str]]:
    # start_iso and end_iso are UTC 'Z' strings.
    start_dt = parse_iso(start_iso)
    end_dt = parse_iso(end_iso)

    cfg = config.load_config()

    # Calculate days back needed from now to know how many days to look back
    now_utc = datetime.now(timezone.utc)
    days_back = (now_utc - start_dt).days + 2  # buffer

    # Use the shared collection function
    from core.processing.evidence_collector import collect_unified_items
    from core.ingestion.git_ingestion import _git_show_compact

    items = collect_unified_items(
        repo_paths=cfg.repo_paths,
        since_days=days_back,
        author_filter=author,
        start_dt=start_dt,
        end_dt=end_dt,
    )

    # Sort items by timestamp ascending for chronological narrative building
    items.sort(key=lambda x: str(x.get("timestamp") or ""))

    snippets: List[str] = []
    evidence_metadata: List[Dict[str, str]] = []

    for item in items[:limit]:
        eid = item["id"]
        kind = item.get("kind")
        etype = item.get("type")
        source = item.get("source")

        # Map types for the UI icons
        ui_type = "note" if kind == "note" else (etype or "event")
        evidence_metadata.append({"id": eid, "type": ui_type})

        if kind == "note":
            # Skip adding to snippets here as they are handled separately by _collect_notes_text
            # in generate_narrative and generate_wins to avoid duplication in the prompt.
            continue

        if etype == "code.commit":
            # Fetch details for snippet
            try:
                # 1. Try to fetch from artifacts if it's a DB event (includes AI summary if exists)
                arts = db.artifacts_for_event(eid)
                ai_summary_art = next((a for a in arts if a["kind"] == "ai.summary"), None)
                git_art = next((a for a in arts if a["kind"] == "git.commit"), None)

                parts = ["[git.commit]"]
                if ai_summary_art:
                    parts.append(ai_summary_art["content"])
                
                if git_art:
                    parts.append(git_art["content"])
                else:
                    # Fallback to live lookup if no git.commit artifact but repo_path is available
                    repo_path = item.get("repo_path")
                    if repo_path:
                        compact = _git_show_compact(repo_path, eid)
                        parts.append(compact)
                    else:
                        parts.append(f"{eid}: {item['title']}")
                
                snippets.append(" ".join(parts).strip())
            except Exception:
                snippets.append(f"[git.commit] {eid}: {item['title']}".strip())
        elif etype == "calendar.event":
            content = f"Meeting: {item['title']} ({item.get('duration', '??')}m) in {item.get('calendar_name', '??')}"
            notes = item.get("notes")
            if not notes:
                # Try to fetch from artifacts if it's a DB event
                try:
                    arts = db.artifacts_for_event(eid)
                    cal_art = next((a for a in arts if a["kind"] == "calendar.details"), None)
                    if cal_art:
                        notes = cal_art['content']
                except Exception:
                    pass
            if notes:
                content += f"\nNotes: {notes}"
            snippets.append(f"[{source}.event] {content}".strip())
        else:
            title = item.get('title', 'Untitled Event')
            snippets.append(f"[{source}] {title}".strip())
            # Check for any descriptive artifacts that might provide more context
            try:
                arts = db.artifacts_for_event(eid)
                for a in arts:
                    # Skip common technical or internal artifacts
                    if a["kind"] in ["git.commit", "git.diff", "ai.summary", "calendar.details"]:
                        continue
                    # Include anything else as a supplementary note
                    snippets.append(f"  ({a['kind']}) {a['content']}".strip())
            except Exception:
                pass

    return "\n\n".join(snippets), evidence_metadata


def _hydrate_evidence(evidence_ids: List[Any], start_iso: str, end_iso: str, author: Optional[str] = None) -> List[Dict[str, str]]:
    """
    Ensures evidence items are in the new Dict format with 'id' and 'type'.
    If items are just strings (old format), we fetch metadata to find their types.
    """
    if not evidence_ids:
        return []
    
    # If already in new format, just return (assuming the first item is representative)
    if evidence_ids and isinstance(evidence_ids[0], dict) and "type" in evidence_ids[0]:
        return evidence_ids

    # Old format: list of strings. We need to fetch types.
    from core.processing.evidence_collector import collect_unified_items
    
    # Calculate days back for collection
    start_dt = parse_iso(start_iso)
    end_dt = parse_iso(end_iso)
    now_utc = datetime.now(timezone.utc)
    days_back = (now_utc - start_dt).days + 2

    cfg = config.load_config()
    items = collect_unified_items(
        repo_paths=cfg.repo_paths,
        since_days=days_back,
        author_filter=author,
        start_dt=start_dt,
        end_dt=end_dt,
    )
    
    # Map ID -> Type
    type_map = {}
    for item in items:
        eid = item["id"]
        kind = item.get("kind")
        etype = item.get("type")
        ui_type = "note" if kind == "note" else (etype or "event")
        type_map[eid] = ui_type
        
    hydrated = []
    for eid in evidence_ids:
        # eid might be a string or a dict from a partial migration
        actual_id = eid["id"] if isinstance(eid, dict) else str(eid)
        hydrated.append({
            "id": actual_id,
            "type": type_map.get(actual_id, "event") # default to event
        })
    return hydrated


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
    existing = db.get_narrative(start_iso, end_iso, purpose=purpose)
    if existing:
        is_locked = existing.get("locked", False)
        if is_locked or not force_regenerate:
            ev_ids = existing.get("evidence_ids", [])
            if isinstance(ev_ids, str):
                try:
                    ev_ids = json.loads(ev_ids)
                except Exception:
                    ev_ids = []
            
            # Hydrate to ensure icons are present even for old records
            hydrated_ev = _hydrate_evidence(ev_ids, start_iso, end_iso, author=cfg.user_name or None)
            
            return {
                "ok": True,
                "purpose": purpose,
                "date": end_day.isoformat(),
                "period_start": start_iso,
                "period_end": end_iso,
                "narrative_id": existing["id"],
                "text": existing["text"],
                "evidence_event_ids": hydrated_ev,
                "locked": is_locked,
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

        log_file = log_llm_request(
            purpose=purpose,
            prompt=prompt,
            evidence=evidence_snips or "(none)",
            notes=notes_text or "(none)",
        )

        try:
            api_key = None
            if cfg.llm_provider == "gemini":
                api_key = cfg.gemini_api_key
            elif cfg.llm_provider == "openai":
                api_key = cfg.openai_api_key

            text = generate_text(
                model=cfg.llm_model,
                prompt=prompt,
                provider=cfg.llm_provider,
                api_key=api_key,
            )
            log_llm_response(log_file, text)
        except LLMError as e:
            llm_ok = False
            text = (
                f"Summary ({purpose}):\n- (LLM unavailable: {str(e)}) Evidence captured below.\n\n"
                "Key Work:\n- \n\nBlockers:\n- \n\nEvidence Used:\n"
                + "\n".join(
                    [
                        f"- {line}"
                        for line in (
                            evidence_snips.splitlines()[:20] if evidence_snips else []
                        )
                    ]
                )
            )
            log_llm_response(log_file, f"Error: {str(e)}")

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
        "llm_provider": cfg.llm_provider,
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
    force_regenerate: bool = False,
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
        is_locked = existing.get("locked", False)
        if is_locked or not force_regenerate:
            ev_ids = existing.get("evidence_ids", [])
            if isinstance(ev_ids, str):
                try:
                    ev_ids = json.loads(ev_ids)
                except Exception:
                    ev_ids = []
            
            # Hydrate to ensure icons are present even for old records
            hydrated_ev = _hydrate_evidence(ev_ids, start_iso, end_iso, author=cfg.user_name or None)
            
            return {
                "ok": True,
                "purpose": f"wins.{label}",
                "period_start": start_iso,
                "period_end": end_iso,
                "narrative_id": existing["id"],
                "text": existing["text"],
                "evidence_event_ids": hydrated_ev,
                "locked": is_locked,
            }

    evidence_snips, evidence_event_ids = _collect_evidence_snippets(
        start_iso, end_iso, author=cfg.user_name or None, limit=60
    )
    notes_text = _collect_notes_text(start_iso, end_iso)

    if not evidence_snips and not notes_text:
        text = "Wins:\n- No tracked work evidence for this period.\n\nEvidence Used:\n- \n"
    else:
        prompt = wins_prompt(
            evidence_snips or "(none)", notes_text or "(none)", period_label=label
        )

        log_file = log_llm_request(
            purpose=f"wins.{label}",
            prompt=prompt,
            evidence=evidence_snips or "(none)",
            notes=notes_text or "(none)",
        )

        try:
            api_key = None
            if cfg.llm_provider == "gemini":
                api_key = cfg.gemini_api_key
            elif cfg.llm_provider == "openai":
                api_key = cfg.openai_api_key

            text = generate_text(
                model=cfg.llm_model,
                prompt=prompt,
                provider=cfg.llm_provider,
                api_key=api_key,
            )
            log_llm_response(log_file, text)
        except LLMError as e:
            text = (
                f"Wins:\n- (LLM unavailable: {str(e)}) Evidence captured below.\n\nEvidence Used:\n"
                + "\n".join(
                    [
                        f"- {line}"
                        for line in (
                            evidence_snips.splitlines()[:30] if evidence_snips else []
                        )
                    ]
                )
            )
            log_llm_response(log_file, f"Error: {str(e)}")

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
