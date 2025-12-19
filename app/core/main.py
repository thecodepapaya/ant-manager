from __future__ import annotations

import argparse
import json
import sys
from typing import Any, Dict

from core import config
from core.storage import db
from core.ingestion.git_ingestion import ingest_repos
from core.processing.narrative_builder import generate_daily, generate_wins


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

    detect_user = sub.add_parser("detect-git-user")
    detect_user.add_argument("path")

    daily = sub.add_parser("daily-summary")
    daily.add_argument("--date", default=None, help="ISO date (YYYY-MM-DD) in local time")

    timeline = sub.add_parser("timeline")
    timeline.add_argument("--days", type=int, default=7)

    wins = sub.add_parser("wins")
    wins.add_argument("--period", choices=["weekly", "monthly"], default="weekly")

    details = sub.add_parser("event-details")
    details.add_argument("event_id")

    note = sub.add_parser("add-note")
    note.add_argument("content")

    upd = sub.add_parser("update-narrative")
    upd.add_argument("narrative_id")
    upd.add_argument("text")

    lock = sub.add_parser("lock-narrative")
    lock.add_argument("narrative_id")

    notes = sub.add_parser("notes")
    notes.add_argument("--days", type=int, default=30)

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
        _print_json({"ok": True, "notes": db.list_notes(days=int(args.days))})
        return 0

    if args.cmd == "timeline":
        db.init_db()
        events = db.list_events(days=int(args.days))
        notes = db.list_notes(days=int(args.days))
        items = []
        for e in events:
            items.append(
                {
                    "kind": "event",
                    "id": e.get("id"),
                    "timestamp": e.get("timestamp_start"),
                    "type": e.get("type"),
                    "source": e.get("source"),
                    "source_id": e.get("source_id"),
                }
            )
        for n in notes:
            items.append(
                {
                    "kind": "note",
                    "id": n.get("id"),
                    "timestamp": n.get("timestamp"),
                    "type": "note",
                    "source": "manual",
                    "content": n.get("content"),
                }
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
        ev = db.get_event(str(args.event_id))
        if not ev:
            _print_json({"ok": False, "error": "event not found"})
            return 2
        arts = db.artifacts_for_event(str(args.event_id))
        _print_json({"ok": True, "event": ev, "artifacts": arts})
        return 0

    if args.cmd == "daily-summary":
        # v0: auto-ingest recent git so daily view always has something.
        cfg = config.load_config()
        ingest_repos(
            cfg.repo_paths,
            since_days=2,
            author_filter=cfg.user_name or None,
        )
        _print_json(generate_daily())
        return 0

    if args.cmd == "wins":
        cfg = config.load_config()
        ingest_repos(
            cfg.repo_paths,
            since_days=40,
            author_filter=cfg.user_name or None,
        )
        _print_json(generate_wins(period=str(args.period)))
        return 0

    if args.cmd == "update-narrative":
        ok = db.update_narrative_text(str(args.narrative_id), str(args.text))
        _print_json({"ok": ok})
        return 0 if ok else 2

    if args.cmd == "lock-narrative":
        ok = db.lock_narrative(str(args.narrative_id))
        _print_json({"ok": ok})
        return 0 if ok else 2

    # The commands below will be implemented in later todos.
    _print_json({"ok": False, "error": f"Command not implemented yet: {args.cmd}"})
    return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))


