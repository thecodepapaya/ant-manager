from __future__ import annotations

import os
from dataclasses import dataclass, field
from typing import List

from core.utils import ensure_dir, json_dumps, repo_root


def _config_dir() -> str:
    # Store user config in home dir (stable), but still allow override for dev/testing.
    override = os.environ.get("ANT_MANAGER_CONFIG_DIR")
    if override:
        ensure_dir(override)
        return override
    path = os.path.join(os.path.expanduser("~"), ".ant_manager")
    ensure_dir(path)
    return path


def config_path() -> str:
    return os.path.join(_config_dir(), "config.json")


@dataclass
class AppConfig:
    repo_paths: List[str] = field(default_factory=list)
    llm_model: str = "llama3.1:8b"


def load_config() -> AppConfig:
    path = config_path()
    if not os.path.exists(path):
        # Default: include repo root if it's a git repo (helps first-run dogfooding).
        default_repos: List[str] = []
        if os.path.isdir(os.path.join(repo_root(), ".git")):
            default_repos.append(repo_root())
        cfg = AppConfig(repo_paths=default_repos)
        save_config(cfg)
        return cfg

    import json

    with open(path, "r", encoding="utf-8") as f:
        raw = json.load(f)
    return AppConfig(
        repo_paths=list(raw.get("repo_paths", []) or []),
        llm_model=str(raw.get("llm_model") or "llama3.1:8b"),
    )


def save_config(cfg: AppConfig) -> None:
    path = config_path()
    import json

    with open(path, "w", encoding="utf-8") as f:
        json.dump(
            {"repo_paths": cfg.repo_paths, "llm_model": cfg.llm_model},
            f,
            ensure_ascii=False,
            indent=2,
        )


def add_repo(path: str) -> AppConfig:
    cfg = load_config()
    norm = os.path.abspath(os.path.expanduser(path))
    if norm not in cfg.repo_paths:
        cfg.repo_paths.append(norm)
        save_config(cfg)
    return cfg


def remove_repo(path: str) -> AppConfig:
    cfg = load_config()
    norm = os.path.abspath(os.path.expanduser(path))
    cfg.repo_paths = [p for p in cfg.repo_paths if os.path.abspath(p) != norm]
    save_config(cfg)
    return cfg


def set_model(model: str) -> AppConfig:
    cfg = load_config()
    cfg.llm_model = model
    save_config(cfg)
    return cfg


def config_as_json() -> str:
    cfg = load_config()
    return json_dumps({"repo_paths": cfg.repo_paths, "llm_model": cfg.llm_model})


