from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Dict, List, Optional, Tuple

from core.storage import db
from core.utils import parse_iso, run_cmd, utc_now_iso


@dataclass
class GitCommit:
    sha: str
    author: str
    date_iso: str
    subject: str
    repo_path: str


def _git_is_repo(path: str) -> bool:
    try:
        out = run_cmd(["git", "-C", path, "rev-parse", "--is-inside-work-tree"])
        return out.strip() == "true"
    except Exception:
        return False


def get_git_user(repo_path: str) -> Optional[str]:
    """Try to detect the git user name from the repository config or global config."""
    try:
        # First check local repo config
        name = run_cmd(["git", "-C", repo_path, "config", "user.name"]).strip()
        if name:
            return name
        # Fallback to global config
        name = run_cmd(["git", "config", "--global", "user.name"]).strip()
        if name:
            return name
    except Exception:
        pass
    return None


def _git_log_commits(
    repo_path: str, since_days: int, author_filter: Optional[str] = None
) -> List[GitCommit]:
    since = (datetime.now(timezone.utc) - timedelta(days=since_days)).isoformat()
    # Use ISO strict for stable parsing; delimiter is ASCII Unit Separator.
    fmt = "%H\x1f%an\x1f%ad\x1f%s"
    cmd = [
        "git",
        "-C",
        repo_path,
        "log",
        f"--since={since}",
        "--date=iso-strict",
        f"--pretty=format:{fmt}",
        "--no-color",
    ]
    if author_filter:
        cmd.append(f"--author={author_filter}")

    out = run_cmd(cmd)
    commits: List[GitCommit] = []
    for line in out.splitlines():
        parts = line.split("\x1f")
        if len(parts) != 4:
            continue
        sha, author, date_iso, subject = parts
        commits.append(
            GitCommit(
                sha=sha.strip(),
                author=author.strip(),
                date_iso=date_iso.strip(),
                subject=subject.strip(),
                repo_path=repo_path,
            )
        )
    return commits


def _git_show_compact(repo_path: str, sha: str) -> str:
    # Compact, readable evidence snippet (not full diff).
    return run_cmd(
        [
            "git",
            "-C",
            repo_path,
            "show",
            "--stat",
            "--oneline",
            "--no-color",
            sha,
        ]
    ).strip()


def ingest_repo(
    repo_path: str, since_days: int = 7, author_filter: Optional[str] = None
) -> Dict[str, int]:
    if not _git_is_repo(repo_path):
        return {"events_created": 0, "artifacts_created": 0}

    db.init_db()
    commits = _git_log_commits(repo_path, since_days=since_days, author_filter=author_filter)
    events_created = 0
    artifacts_created = 0

    for c in commits:
        # Use source_id=commit sha so ingestion is idempotent.
        event_id = db.insert_event_if_missing(
            timestamp_start=c.date_iso,
            timestamp_end=None,
            type="code.commit",
            source="git",
            source_id=f"{c.repo_path}:{c.sha}",
            confidence_score=1.0,
        )

        # If event already existed, insert_event_if_missing returns existing id.
        # We still ensure at least one artifact exists for evidence.
        artifacts = db.artifacts_for_event(event_id)
        if artifacts:
            continue

        compact = _git_show_compact(repo_path=c.repo_path, sha=c.sha)
        db.insert_artifact(
            event_id=event_id,
            kind="git.commit",
            content=compact,
            source_id=c.sha,
        )
        artifacts_created += 1
        events_created += 1

    return {"events_created": events_created, "artifacts_created": artifacts_created}


def ingest_repos(
    repo_paths: List[str], since_days: int = 7, author_filter: Optional[str] = None
) -> Dict[str, int]:
    totals = {"repos": 0, "events_created": 0, "artifacts_created": 0}
    for path in repo_paths:
        totals["repos"] += 1
        res = ingest_repo(path, since_days=since_days, author_filter=author_filter)
        totals["events_created"] += int(res.get("events_created", 0))
        totals["artifacts_created"] += int(res.get("artifacts_created", 0))
    return totals


