from __future__ import annotations

import hashlib
import json
import os
import subprocess
import uuid
from datetime import datetime, timezone
from typing import Any, List


def ensure_dir(path: str) -> str:
    if not os.path.exists(path):
        os.makedirs(path, exist_ok=True)
    return path


def json_dumps(obj: Any) -> str:
    return json.dumps(obj, ensure_ascii=False)


def repo_root() -> str:
    # This is a bit arbitrary now that core is moved, 
    # but let's assume it's the parent of the 'core' directory.
    return os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def data_dir() -> str:
    # Use environment variable if set (by Flutter app), else default to ~/.ant_manager/data
    path = os.environ.get("ANT_MANAGER_DATA_DIR")
    if path:
        return ensure_dir(path)
    path = os.path.join(os.path.expanduser("~"), ".ant_manager", "data")
    return ensure_dir(path)


def new_id() -> str:
    return str(uuid.uuid4())


def sha256_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def parse_iso(iso_str: str) -> datetime:
    # datetime.fromisoformat handles most ISO 8601 strings in Python 3.7+
    return datetime.fromisoformat(iso_str.replace("Z", "+00:00"))


def run_cmd(args: List[str]) -> str:
    result = subprocess.run(
        args,
        capture_output=True,
        text=True,
        check=True,
    )
    return result.stdout

