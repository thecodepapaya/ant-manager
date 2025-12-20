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

    add_repo = sub.add_parser("config-add-repo")
    add_repo.add_argument("path")

    rem_repo = sub.add_parser("config-remove-repo")
    rem_repo.add_argument("path")

    set_model = sub.add_parser("config-set-model")
    set_model.add_argument("model")

    set_user = sub.add_parser("config-set-user-name")
    set_user.add_argument("name")

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

    details = sub.add_parser("event-details")
    details.add_argument("event_id")
    details.add_argument("--source", default=None)
    details.add_argument("--timestamp", default=None)
    details.add_argument("--regenerate", action="store_true")
    details.add_argument("--skip-llm", action="store_true")

    note = sub.add_parser("add-note")
    note.add_argument("content")

    add_event_artifact = sub.add_parser("add-event-artifact")
    add_event_artifact.add_argument("event_id")
    add_event_artifact.add_argument("kind")
    add_event_artifact.add_argument("content")

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


def main(argv: list[str]) -> int:
    args = build_parser().parse_args(argv)

    if args.cmd == "config-get":
        _print_json(json.loads(config.config_as_json()))
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

    if args.cmd == "config-set-user-name":
        cfg = config.set_user_name(args.name)
        _print_json({"ok": True, "user_name": cfg.user_name})
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
        note_id = db.add_note(args.content)
        _print_json({"ok": True, "note_id": note_id})
        return 0

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
        
        # Fetch notes (we fetch all for now and filter here for consistency)
        notes = db.list_notes(days=3650)
        if start_dt and end_dt:
            filtered = []
            for n in notes:
                try:
                    n_dt = parse_iso(n["timestamp"])
                    if start_dt <= n_dt <= end_dt:
                        filtered.append(n)
                except Exception: continue
            notes = filtered
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

        # Fetch live data
        from core.ingestion.git_ingestion import get_commits
        from core.ingestion.calendar_ingestion import get_calendar_events
        from core.ingestion.google_calendar import get_google_calendar_events

        commits = get_commits(cfg.repo_paths, since_days=max(1, days_back), author_filter=author)
        calendar_events = []
        google_events = []
        try: calendar_events = get_calendar_events(days=max(1, days_back))
        except Exception: pass
        try: google_events = get_google_calendar_events(days=max(1, days_back))
        except Exception: pass
        
        def is_in_range(ts_str: str) -> bool:
            if not start_dt or not end_dt: return True
            try:
                t = parse_iso(ts_str)
                return start_dt <= t <= end_dt
            except Exception: return False

        items = []
        for c in commits:
            if is_in_range(c.date_iso):
                items.append({
                    "kind": "event",
                    "id": c.sha,
                    "timestamp": c.date_iso,
                    "type": "code.commit",
                    "source": "git",
                    "source_id": f"{c.repo_path}:{c.sha}",
                    "title": c.subject,
                })

        for e in calendar_events:
            if is_in_range(e.start_iso):
                items.append({
                    "kind": "event",
                    "id": e.id,
                    "timestamp": e.start_iso,
                    "type": "calendar.event",
                    "source": "calendar",
                    "source_id": e.id,
                    "title": e.title,
                    "duration": e.duration_minutes,
                })

        for e in google_events:
            ts = e.get("start_iso")
            if not ts: continue
            # Handle Google's all-day format (YYYY-MM-DD)
            if 'T' not in ts: ts += 'T00:00:00Z'
            if is_in_range(ts):
                items.append({
                    "kind": "event",
                    "id": e["id"],
                    "timestamp": e["start_iso"],
                    "type": "calendar.event",
                    "source": "google_calendar",
                    "source_id": e["id"],
                    "title": e["title"],
                    "duration": e.get("duration_minutes"),
                })

        # DB events
        db_evs = db.list_events(days=max(1, days_back), author=author)
        for e in db_evs:
            # Filter out sources we handle live
            if e.get("source") in ["git", "calendar", "google_calendar"]: continue
            ts = e.get("timestamp_start")
            if ts and is_in_range(ts):
                items.append({
                    "kind": "event",
                    "id": e["id"],
                    "timestamp": ts,
                    "type": e["type"],
                    "source": e["source"],
                    "source_id": e["source_id"],
                    "title": f"External Event ({e['source']})",
                })

        # Notes
        all_notes = db.list_notes(days=max(1, days_back))
        for n in all_notes:
            ts = n.get("timestamp")
            if ts and is_in_range(ts):
                items.append({
                    "kind": "note",
                    "id": n["id"],
                    "timestamp": ts,
                    "content": n["content"],
                })

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
        ev = db.get_event(event_id)
        arts = db.artifacts_for_event(event_id) if ev else []

        # Check if we already have an AI summary
        existing_summary = next((a for a in arts if a["kind"] == "ai.summary"), None)

        if not ev or (not existing_summary or force_regenerate):
            if skip_llm:
                # If we're skipping LLM, just continue to what we have in DB
                pass
            else:
                cfg = config.load_config()
                from core.ingestion.git_ingestion import _git_show_compact, _git_is_repo

                if source_hint is None or source_hint == "git":
                    for repo in cfg.repo_paths:
                        if not _git_is_repo(repo):
                            continue
                        try:
                            details = _git_show_compact(repo, event_id)
                            if details:
                                summary = None
                                if not existing_summary or force_regenerate:
                                    try:
                                        from core.processing.llm_client import generate_text

                                        prompt = f"Summary this git commit briefly:\n\n{details}"
                                        summary = generate_text(model=cfg.llm_model, prompt=prompt)

                                        # Persist the event if it wasn't there
                                        if not ev:
                                            from datetime import datetime, timezone

                                            # Simple heuristic for missing data if live
                                            db.upsert_event(
                                                event_id=event_id,
                                                timestamp_start=timestamp_hint or datetime.now(timezone.utc).isoformat(),
                                                timestamp_end=None,
                                                type="code.commit",
                                                source="git",
                                                source_id=f"live:{event_id}",
                                                confidence_score=1.0,
                                            )
                                            ev = db.get_event(event_id)

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
                                    artifacts = [{"kind": "git.commit", "content": details}]
                                    if summary:
                                        artifacts.insert(0, {"kind": "ai.summary", "content": summary})

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
                                # If we have an event now, fall through to DB return
                                break
                        except Exception:
                            continue

            # Calendar fallbacks
            if not ev:
                lookback = 30
                start_search = None
                if timestamp_hint:
                    try:
                        from datetime import datetime as dt, timedelta

                        event_dt = dt.fromisoformat(timestamp_hint.replace("Z", "+00:00"))
                        start_search = event_dt - timedelta(days=1)
                        lookback = 3
                    except Exception:
                        pass

                if source_hint is None or source_hint == "calendar":
                    from core.ingestion.calendar_ingestion import get_calendar_events

                    for ce in get_calendar_events(days=lookback, start_date=start_search):
                        if ce.id == event_id:
                            content = f"Title: {ce.title}\nDuration: {ce.duration_minutes}m\nCalendar: {ce.calendar_name}\nNotes: {ce.notes}"
                            _print_json(
                                {
                                    "ok": True,
                                    "event": {
                                        "id": event_id,
                                        "type": "calendar.event",
                                        "source": "calendar",
                                        "timestamp": ce.start_iso,
                                    },
                                    "artifacts": [{"kind": "calendar.details", "content": content}],
                                }
                            )
                            return 0

                if source_hint is None or source_hint == "google_calendar":
                    from core.ingestion.google_calendar import get_google_calendar_events

                    for ge in get_google_calendar_events(days=lookback, start_date=start_search):
                        if ge["id"] == event_id:
                            content = f"Title: {ge['title']}\nDuration: {ge['duration_minutes']}m\nCalendar: {ge['calendar_name']}"
                            _print_json(
                                {
                                    "ok": True,
                                    "event": {
                                        "id": event_id,
                                        "type": "calendar.event",
                                        "source": "google_calendar",
                                        "timestamp": ge["start_iso"],
                                    },
                                    "artifacts": [{"kind": "calendar.details", "content": content}],
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
            end_date=end_date
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
        ev = db.get_event(event_id)
        if not ev:
            from datetime import datetime, timezone
            db.upsert_event(
                event_id=event_id,
                timestamp_start=datetime.now(timezone.utc).isoformat(),
                timestamp_end=None,
                type="calendar.event",
                source="calendar",
                source_id=event_id,
                confidence_score=1.0,
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
