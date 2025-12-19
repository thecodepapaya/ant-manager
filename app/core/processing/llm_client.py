from __future__ import annotations

from typing import Optional

import requests


class OllamaError(RuntimeError):
    pass


def generate_text(
    *,
    model: str,
    prompt: str,
    base_url: str = "http://localhost:11434",
    timeout_s: int = 120,
) -> str:
    url = f"{base_url.rstrip('/')}/api/generate"
    try:
        resp = requests.post(
            url,
            json={"model": model, "prompt": prompt, "stream": False},
            timeout=timeout_s,
        )
    except requests.RequestException as e:
        raise OllamaError(f"Failed to reach Ollama at {base_url}: {e}") from e

    if resp.status_code != 200:
        raise OllamaError(f"Ollama returned {resp.status_code}: {resp.text[:300]}")

    data = resp.json()
    text = data.get("response")
    if not isinstance(text, str):
        raise OllamaError("Ollama response missing 'response' text")
    return text.strip()


