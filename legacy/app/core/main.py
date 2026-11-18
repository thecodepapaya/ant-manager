from __future__ import annotations

import argparse
import json
import sys
from typing import Any, Dict

from core import config
from core.storage import db
from core.ingestion.git_ingestion import ingest_repos


def _print_json(obj: Any) -> None:
    sys.stdout.write(json.dumps(obj, ensure_ascii=False))
    sys.stdout.write("\n")


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="ant-manager-core")
    sub = p.add_subparsers(dest="cmd", required=True)

    sub.add_parser("config-get")
    sub.add_parser("config-get-default-prompts")

    list_models = sub.add_parser("llm-list-models")
    list_models.add_argument("--provider", default="ollama")
    list_models.add_argument("--api-key", default=None)

    add_repo = sub.add_parser("config-add-repo")
    add_repo.add_argument("path")

    rem_repo = sub.add_parser("config-remove-repo")
    rem_repo.add_argument("path")

    set_model = sub.add_parser("config-set-model")
    set_model.add_argument("model")

    set_llm = sub.add_parser("config-set-llm")
    set_llm.add_argument("--provider", help="ollama, gemini, or openai")
    set_llm.add_argument("--model", help="model name")
    set_llm.add_argument("--gemini-key", help="Gemini API key")
    set_llm.add_argument("--openai-key", help="OpenAI API key")

    set_user = sub.add_parser("config-set-user-name")
    set_user.add_argument("name")

    set_prompts = sub.add_parser("config-set-prompts")
    set_prompts.add_argument("--system-rules", help="System rules prompt")
    set_prompts.add_argument("--daily-summary", help="Daily summary template")
    set_prompts.add_argument("--wins-list", help="Wins list template")
    set_prompts.add_argument("--commit-summary", help="Commit summary template")

    sub.add_parser("init-db")

    sub.add_parser("google-calendar-auth-url")
    google_token = sub.add_parser("google-calendar-set-token")
    google_token.add_argument("code")

    google_secrets = sub.add_parser("google-calendar-set-secrets")
    google_secrets.add_argument("client_id")
    google_secrets.add_argument("client_secret")

    detect_user = sub.add_parser("detect-git-user")
    detect_user.add_argument("path")

    daily = sub.add_parser("daily-summary")
    daily.add_argument("--date", default=None, help="ISO date (YYYY-MM-DD) in local time")
    daily.add_argument("--regenerate", action="store_true", help="Force regeneration of the narrative")
    daily.add_argument("--days", type=int, default=1)
    daily.add_argument("--period", default="daily")
    daily.add_argument("--start-date", default=None)
    daily.add_argument("--end-date", default=None)

    timeline = sub.add_parser("timeline")
    timeline.add_argument("--days", type=int, default=7)
    timeline.add_argument("--date", default=None, help="ISO date (YYYY-MM-DD) to focus on")
    timeline.add_argument("--start-date", default=None, help="ISO date (YYYY-MM-DD) for start of range")
    timeline.add_argument("--end-date", default=None, help="ISO date (YYYY-MM-DD) for end of range")

    wins = sub.add_parser("wins")
    wins.add_argument("--period", choices=["daily", "weekly", "monthly"], default="weekly")
    wins.add_argument("--date", default=None, help="ISO date (YYYY-MM-DD) to focus on")
    wins.add_argument("--start-date", default=None, help="ISO date (YYYY-MM-DD) for start of range")
    wins.add_argument("--end-date", default=None, help="ISO date (YYYY-MM-DD) for end of range")
    wins.add_argument("--regenerate", action="store_true", help="Force regeneration of the wins narrative")

    details = sub.add_parser("event-details")
    details.add_argument("event_id")
    details.add_argument("--source", default=None)
    details.add_argument("--timestamp", default=None)
    details.add_argument("--regenerate", action="store_true")
    details.add_argument("--skip-llm", action="store_true")

    note = sub.add_parser("add-note")
    note.add_argument("content")
    note.add_argument("--timestamp", help="ISO timestamp for the note (defaults to now)")

    upd_note = sub.add_parser("update-note")
    upd_note.add_argument("note_id")
    upd_note.add_argument("content")
    upd_note.add_argument("--timestamp", help="ISO timestamp for the note")

    del_note = sub.add_parser("delete-note")
    del_note.add_argument("note_id")

    del_event = sub.add_parser("delete-event")
    del_event.add_argument("event_id")

    add_event_artifact = sub.add_parser("add-event-artifact")
    add_event_artifact.add_argument("event_id")
    add_event_artifact.add_argument("kind")
    add_event_artifact.add_argument("content")
    add_event_artifact.add_argument("--source", help="Source of the event (e.g. git, calendar)")
    add_event_artifact.add_argument("--timestamp", help="ISO timestamp of the event")
    add_event_artifact.add_argument("--type", help="Type of the event")
    add_event_artifact.add_argument("--title", help="Title of the event")

    upd_artifact = sub.add_parser("update-event-artifact")
    upd_artifact.add_argument("event_id")
    upd_artifact.add_argument("kind")
    upd_artifact.add_argument("content")

    upd = sub.add_parser("update-narrative")
    upd.add_argument("narrative_id")
    upd.add_argument("text")

    lock = sub.add_parser("lock-narrative")
    lock.add_argument("narrative_id")

    notes = sub.add_parser("notes")
    notes.add_argument("--days", type=int, default=30)
    notes.add_argument("--date", default=None, help="ISO date (YYYY-MM-DD) to focus on")
    notes.add_argument("--start-date", default=None, help="ISO date (YYYY-MM-DD) for start of range")
    notes.add_argument("--end-date", default=None, help="ISO date (YYYY-MM-DD) for end of range")

    ingest = sub.add_parser("ingest-git")
    ingest.add_argument("--days", type=int, default=7)

    return p


def _get_live_calendar_details(event_id: str, source_hint: str = None, timestamp_hint: str = None) -> Optional[str]:
    """Helper to fetch live calendar details without returning JSON directly."""
    lookback = 30
    start_search = None
    if timestamp_hint:
        try:
            from datetime import datetime as dt, timedelta
            ts_clean = timestamp_hint.replace("Z", "+00:00")
            if " " in ts_clean and "+" not in ts_clean:
                ts_clean = ts_clean.replace(" ", "T") + "+00:00"
            event_dt = dt.fromisoformat(ts_clean)
            start_search = event_dt - timedelta(days=2)
            lookback = 60
        except Exception:
            pass

    if source_hint is None or source_hint in ["calendar", "google_calendar"]:
        from core.ingestion.calendar_ingestion import get_calendar_events
        cal_sources = []
        if source_hint is None or source_hint == "calendar":
            cal_sources.append("calendar")
        if source_hint is None or source_hint == "google_calendar":
            cal_sources.append("google_calendar")

        for src in cal_sources:
            if src == "calendar":
                for ce in get_calendar_events(days=lookback, start_date=start_search):
                    if ce.id == event_id:
                        return f"Title: {ce.title}\nDuration: {ce.duration_minutes}m\nCalendar: {ce.calendar_name}\nNotes: {ce.notes}"
            else:
                from core.ingestion.google_calendar import get_google_calendar_events
                try:
                    for ge in get_google_calendar_events(days=lookback, start_date=start_search):
                        if ge["id"] == event_id:
                            return f"Title: {ge['title']}\nDuration: {ge['duration_minutes']}m\nCalendar: {ge['calendar_name']}"
                except Exception:
                    continue
    return None


def main(argv: list[str]) -> int:
    args = build_parser().parse_args(argv)

    if args.cmd == "config-get":
        _print_json(json.loads(config.config_as_json()))
        return 0

    if args.cmd == "config-get-default-prompts":
        from core.processing.prompts import get_default_prompts
        _print_json(get_default_prompts())
        return 0

    if args.cmd == "llm-list-models":
        from core.processing.llm_client import list_models
        try:
            models = list_models(provider=args.provider, api_key=args.api_key)
            _print_json({"ok": True, "models": models})
        except Exception as e:
            _print_json({"ok": False, "error": str(e)})
        return 0

    if args.cmd == "config-add-repo":
        cfg = config.add_repo(args.path)
        _print_json({"ok": True, "repo_paths": cfg.repo_paths})
        return 0

    if args.cmd == "config-remove-repo":
        cfg = config.remove_repo(args.path)
        _print_json({"ok": True, "repo_paths": cfg.repo_paths})
        return 0

    if args.cmd == "config-set-model":
        cfg = config.set_model(args.model)
        _print_json({"ok": True, "llm_model": cfg.llm_model})
        return 0

    if args.cmd == "config-set-llm":
        cfg = config.set_llm_config(
            provider=args.provider,
            model=args.model,
            gemini_key=args.gemini_key,
            openai_key=args.openai_key,
        )
        _print_json(
            {
                "ok": True,
                "llm_provider": cfg.llm_provider,
                "llm_model": cfg.llm_model,
            }
        )
        return 0

    if args.cmd == "config-set-user-name":
        cfg = config.set_user_name(args.name)
        _print_json({"ok": True, "user_name": cfg.user_name})
        return 0

    if args.cmd == "config-set-prompts":
        cfg = config.set_prompts(
            system_rules=args.system_rules,
            daily_summary=args.daily_summary,
            wins_list=args.wins_list,
            commit_summary=args.commit_summary,
        )
        _print_json(
            {
                "ok": True,
                "prompt_system_rules": cfg.prompt_system_rules,
                "prompt_daily_summary": cfg.prompt_daily_summary,
                "prompt_wins_list": cfg.prompt_wins_list,
                "prompt_commit_summary": cfg.prompt_commit_summary,
            }
        )
        return 0

    if args.cmd == "init-db":
        db.init_db()
        _print_json({"ok": True, "db_path": db.db_path()})
        return 0

    if args.cmd == "google-calendar-auth-url":
        from core.ingestion.google_calendar import get_auth_url
        try:
            url = get_auth_url()
            _print_json({"ok": True, "url": url})
        except Exception as e:
            _print_json({"ok": False, "error": str(e)})
        return 0

    if args.cmd == "google-calendar-set-token":
        from core.ingestion.google_calendar import exchange_code_for_token
        try:
            if not args.code or args.code.strip() == "":
                config.set_google_token(None)
                _print_json({"ok": True})
            elif args.code.startswith("RAW:"):
                # Direct token JSON from Dart
                token_json = args.code[4:]
                config.set_google_token(token_json)
                _print_json({"ok": True})
            else:
                token_json = exchange_code_for_token(args.code)
                config.set_google_token(token_json)
                _print_json({"ok": True})
        except Exception as e:
            _print_json({"ok": False, "error": str(e)})
        return 0

    if args.cmd == "google-calendar-set-secrets":
        try:
            config.set_google_secrets(args.client_id, args.client_secret)
            _print_json({"ok": True})
        except Exception as e:
            _print_json({"ok": False, "error": str(e)})
        return 0

    if args.cmd == "detect-git-user":
        from core.ingestion.git_ingestion import get_git_user
        name = get_git_user(args.path)
        _print_json({"ok": True, "name": name})
        return 0

    if args.cmd == "add-note":
        db.init_db()
        note_id = db.add_note(args.content, timestamp=args.timestamp)
        _print_json({"ok": True, "note_id": note_id})
        return 0

    if args.cmd == "update-note":
        db.init_db()
        ok = db.update_note(args.note_id, args.content, timestamp=args.timestamp)
        _print_json({"ok": ok})
        return 0 if ok else 2

    if args.cmd == "delete-note":
        db.init_db()
        ok = db.delete_note(args.note_id)
        _print_json({"ok": ok})
        return 0 if ok else 2

    if args.cmd == "delete-event":
        db.init_db()
        ok = db.delete_event(args.event_id)
        _print_json({"ok": ok})
        return 0 if ok else 2

    if args.cmd == "notes":
        db.init_db()

        from datetime import datetime, date as pydate, timedelta, timezone as tz
        from datetime import time as pytime
        from core.utils import parse_iso

        start_dt = None
        end_dt = None

        if args.start_date and args.end_date:
            sd = pydate.fromisoformat(args.start_date)
            ed = pydate.fromisoformat(args.end_date)
            start_dt = datetime.combine(sd, pytime.min).astimezone(tz.utc)
            end_dt = datetime.combine(ed, pytime.max).astimezone(tz.utc)
        elif args.date:
            td = pydate.fromisoformat(args.date)
            days = int(args.days)
            # Standard lookback logic
            sd = td - timedelta(days=max(days - 1, 0))
            start_dt = datetime.combine(sd, pytime.min).astimezone(tz.utc)
            end_dt = datetime.combine(td, pytime.max).astimezone(tz.utc)

        if start_dt and end_dt:
            start_iso = start_dt.isoformat().replace("+00:00", "Z")
            end_iso = end_dt.isoformat().replace("+00:00", "Z")
            notes = db.list_notes(start_iso=start_iso, end_iso=end_iso)
        else:
            # Fallback to lookback from now if no range specified
            days = int(args.days)
            notes = db.list_notes(days=days)

        _print_json({"ok": True, "notes": notes})
        return 0

    if args.cmd == "timeline":
        db.init_db()
        cfg = config.load_config()
        author = cfg.user_name or None

        from datetime import datetime, date as pydate, timedelta, timezone as tz
        from datetime import time as pytime
        from core.utils import parse_iso
        from core.processing.evidence_collector import collect_unified_items

        start_dt = None
        end_dt = None

        if args.start_date and args.end_date:
            sd = pydate.fromisoformat(args.start_date)
            ed = pydate.fromisoformat(args.end_date)
            start_dt = datetime.combine(sd, pytime.min).astimezone(tz.utc)
            end_dt = datetime.combine(ed, pytime.max).astimezone(tz.utc)
        elif args.date:
            td = pydate.fromisoformat(args.date)
            days = int(args.days)
            sd = td - timedelta(days=max(days - 1, 0))
            start_dt = datetime.combine(sd, pytime.min).astimezone(tz.utc)
            end_dt = datetime.combine(td, pytime.max).astimezone(tz.utc)

        # Calculate days back from now to ensure we ingest enough live data
        if start_dt:
            now_utc = datetime.now(tz.utc)
            days_back = (now_utc - start_dt).days + 2
        else:
            days_back = int(args.days)

        items = collect_unified_items(
            repo_paths=cfg.repo_paths,
            since_days=days_back,
            author_filter=author,
            start_dt=start_dt,
            end_dt=end_dt,
        )

        items.sort(key=lambda x: str(x.get("timestamp") or ""), reverse=True)
        _print_json({"ok": True, "items": items})
        return 0

    if args.cmd == "ingest-git":
        cfg = config.load_config()
        totals = ingest_repos(
            cfg.repo_paths,
            since_days=int(args.days),
            author_filter=cfg.user_name or None,
        )
        _print_json({"ok": True, **totals})
        return 0

    if args.cmd == "event-details":
        event_id = str(args.event_id)
        source_hint = args.source
        timestamp_hint = args.timestamp
        force_regenerate = args.regenerate
        skip_llm = args.skip_llm

        # 1. Check if it's a note
        with db.connect() as conn:
            note_row = conn.execute("SELECT * FROM notes WHERE id=?", (event_id,)).fetchone()
            if note_row:
                note = dict(note_row)
                _print_json({
                    "ok": True,
                    "event": {
                        "id": note["id"],
                        "timestamp": note["timestamp"],
                        "type": "note",
                        "title": "Manual Note",
                        "source": "manual",
                    },
                    "artifacts": [
                        {"kind": "note.content", "content": note["content"]}
                    ]
                })
                return 0

        # 2. Proceed with standard event lookup
        ev = db.get_event(event_id)
        arts = db.artifacts_for_event(event_id) if ev else []
        
        # Check if we already have an AI summary
        existing_summary = next((a for a in arts if a["kind"] == "ai.summary"), None)

        # If it's not in the DB, or we need to (re)generate a summary, try live sources
        if not ev or (not existing_summary or force_regenerate):
            cfg = config.load_config()
            from core.ingestion.git_ingestion import _git_show_compact, _git_is_repo

            # Try Git lookup
            if source_hint is None or source_hint == "git":
                from core.ingestion.git_ingestion import _git_show_compact, _git_is_repo, _git_show_full

                # Try to find the full diff artifact first
                diff_artifact = next((a for a in arts if a["kind"] == "git.diff"), None)
                full_details = diff_artifact["content"] if diff_artifact else None

                for repo in cfg.repo_paths:
                    if not _git_is_repo(repo):
                        continue
                    try:
                        # Use compact for initial details if not already fetched
                        compact_details = _git_show_compact(repo, event_id)
                        if compact_details:
                            # Fetch full diff live if not in artifacts
                            if not full_details:
                                full_details = _git_show_full(repo, event_id)

                            summary = None
                            # Only generate summary if not skipping LLM AND (no existing summary OR force regenerate)
                            if not skip_llm and (not existing_summary or force_regenerate):
                                try:
                                    from core.processing.llm_client import LLMError, generate_text
                                    from core.utils import log_llm_request, log_llm_response
                                    from core.processing.prompts import commit_summary_prompt

                                    # Use full details (diff) for summarization context
                                    # But don't include it if it's too big (e.g. > 20KB)
                                    MAX_DIFF_SIZE = 20000
                                    summarization_context = full_details
                                    if len(full_details) > MAX_DIFF_SIZE:
                                        summarization_context = f"{compact_details}\n\n(Diff omitted from summary generation because it is too large: {len(full_details)} characters)"

                                    prompt = commit_summary_prompt(summarization_context)
                                    log_file = log_llm_request(
                                        purpose=f"event_detail_{event_id[:8]}",
                                        prompt=prompt,
                                        evidence=full_details,
                                    )

                                    api_key = None
                                    if cfg.llm_provider == "gemini":
                                        api_key = cfg.gemini_api_key
                                    elif cfg.llm_provider == "openai":
                                        api_key = cfg.openai_api_key

                                    summary = generate_text(
                                        model=cfg.llm_model,
                                        prompt=prompt,
                                        provider=cfg.llm_provider,
                                        api_key=api_key,
                                    )
                                    log_llm_response(log_file, summary)

                                    # Persist the event if it wasn't there
                                    if not ev:
                                        from datetime import datetime, timezone
                                        db.upsert_event(
                                            event_id=event_id,
                                            timestamp_start=timestamp_hint
                                            or datetime.now(timezone.utc).isoformat(),
                                            timestamp_end=None,
                                            type="code.commit",
                                            source="git",
                                            source_id=f"{repo}:{event_id}",
                                            confidence_score=1.0,
                                        )
                                        ev = db.get_event(event_id)

                                    # Save full diff as artifact if it wasn't there
                                    if not diff_artifact:
                                        db.delete_artifacts_by_kind(event_id, "git.diff")
                                        db.insert_artifact(
                                            event_id=event_id,
                                            kind="git.diff",
                                            content=full_details,
                                            source_id=f"{event_id}:diff"
                                        )

                                    # Save summary as artifact
                                    db.delete_artifacts_by_kind(event_id, "ai.summary")
                                    db.insert_artifact(
                                        event_id=event_id,
                                        kind="ai.summary",
                                        content=summary,
                                    )
                                    # Refresh artifacts
                                    arts = db.artifacts_for_event(event_id)
                                except Exception:
                                    pass

                            # If we still don't have an event record but have live data, return it
                            if not ev:
                                artifacts = [
                                    {"kind": "git.commit", "content": compact_details},
                                    {"kind": "git.diff", "content": full_details}
                                ]
                                if summary:
                                    artifacts.insert(
                                        0, {"kind": "ai.summary", "content": summary}
                                    )

                                _print_json(
                                    {
                                        "ok": True,
                                        "event": {
                                            "id": event_id,
                                            "type": "code.commit",
                                            "source": "git",
                                        },
                                        "artifacts": artifacts,
                                    }
                                )
                                return 0
                            # If we have an event now, break loop and fall through to DB return
                            break
                    except Exception:
                        continue

        # Calendar fallbacks (only if still not found in DB or Git)
        if not ev:
            live_details = _get_live_calendar_details(
                event_id, source_hint=source_hint, timestamp_hint=timestamp_hint
            )
            if live_details:
                # We don't use 'source_hint' directly because the helper might have found it 
                # in a different calendar source than hinted if hinted was generic 'calendar'
                # but for simplicity we'll just use the hint or 'calendar'
                _print_json(
                    {
                        "ok": True,
                        "event": {
                            "id": event_id,
                            "type": "calendar.event",
                            "source": source_hint or "calendar",
                            "timestamp": timestamp_hint,
                        },
                        "artifacts": [
                            {"kind": "calendar.details", "content": live_details}
                        ],
                    }
                )
                return 0

        if ev:
            _print_json({"ok": True, "event": ev, "artifacts": arts})
            return 0

        _print_json({"ok": False, "error": "event not found"})
        return 2

    if args.cmd == "daily-summary":
        from core.processing.narrative_builder import generate_narrative
        target_date = None
        start_date = None
        end_date = None
        if args.start_date and args.end_date:
            from datetime import date as pydate
            start_date = pydate.fromisoformat(args.start_date)
            end_date = pydate.fromisoformat(args.end_date)
        elif args.date:
            from datetime import date as pydate
            target_date = pydate.fromisoformat(args.date)
            
        _print_json(generate_narrative(
            target_date=target_date, 
            period=args.period,
            days=args.days,
            start_date=start_date,
            end_date=end_date,
            force_regenerate=args.regenerate
        ))
        return 0

    if args.cmd == "wins":
        from core.processing.narrative_builder import generate_wins
        target_date = None
        start_date = None
        end_date = None
        if args.start_date and args.end_date:
            from datetime import date as pydate
            start_date = pydate.fromisoformat(args.start_date)
            end_date = pydate.fromisoformat(args.end_date)
        elif args.date:
            from datetime import date as pydate
            target_date = pydate.fromisoformat(args.date)
        
        _print_json(generate_wins(
            period=str(args.period), 
            target_date=target_date, 
            start_date=start_date, 
            end_date=end_date,
            force_regenerate=args.regenerate
        ))
        return 0

    if args.cmd == "update-event-artifact":
        db.init_db()
        event_id = str(args.event_id)
        kind = str(args.kind)
        content = str(args.content)
        db.delete_artifacts_by_kind(event_id, kind)
        db.insert_artifact(event_id=event_id, kind=kind, content=content)
        _print_json({"ok": True})
        return 0

    if args.cmd == "update-narrative":
        ok = db.update_narrative_text(str(args.narrative_id), str(args.text))
        _print_json({"ok": ok})
        return 0 if ok else 2

    if args.cmd == "lock-narrative":
        ok = db.lock_narrative(str(args.narrative_id))
        _print_json({"ok": ok})
        return 0 if ok else 2

    if args.cmd == "add-event-artifact":
        db.init_db()
        event_id = str(args.event_id)

        # Check if this event already exists in DB
        existing_ev = db.get_event(event_id)

        # Always upsert if we have metadata, to ensure stubs are filled correctly
        if args.timestamp or args.source or args.title:
            from datetime import datetime, timezone
            db.upsert_event(
                event_id=event_id,
                timestamp_start=args.timestamp
                or datetime.now(timezone.utc).isoformat(),
                timestamp_end=None,
                type=args.type or "calendar.event",
                title=args.title,
                source=args.source or "calendar",
                source_id=event_id,
                confidence_score=1.0,
            )

        # If it's a new promotion of a calendar event, fetch and save live details
        # so they don't "disappear" from the UI once the event is in the DB.
        if existing_ev is None and (
            args.type == "calendar.event"
            or args.source in ["calendar", "google_calendar"]
        ):
            live_details = _get_live_calendar_details(
                event_id, source_hint=args.source, timestamp_hint=args.timestamp
            )
            if live_details:
                db.insert_artifact(
                    event_id=event_id, kind="calendar.details", content=live_details
                )

        artifact_id = db.insert_artifact(
            event_id=event_id,
            kind=str(args.kind),
            content=str(args.content),
        )
        _print_json({"ok": True, "artifact_id": artifact_id})
        return 0

    _print_json({"ok": False, "error": f"Unknown command: {args.cmd}"})
    return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
