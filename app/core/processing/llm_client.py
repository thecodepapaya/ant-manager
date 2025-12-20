from __future__ import annotations

from typing import Optional

import requests


class LLMError(RuntimeError):
    pass


def generate_text(
    *,
    model: str,
    prompt: str,
    provider: str = "ollama",
    api_key: Optional[str] = None,
    base_url: Optional[str] = None,
    timeout_s: int = 120,
    num_ctx: int = 8192,
) -> str:
    if provider == "ollama":
        return _generate_ollama(
            model=model,
            prompt=prompt,
            base_url=base_url or "http://localhost:11434",
            timeout_s=timeout_s,
            num_ctx=num_ctx,
        )
    elif provider == "gemini":
        return _generate_gemini(
            model=model,
            prompt=prompt,
            api_key=api_key,
            timeout_s=timeout_s,
        )
    elif provider == "openai":
        return _generate_openai(
            model=model,
            prompt=prompt,
            api_key=api_key,
            timeout_s=timeout_s,
        )
    else:
        raise LLMError(f"Unknown LLM provider: {provider}")


def list_models(
    provider: str = "ollama",
    api_key: Optional[str] = None,
    base_url: Optional[str] = None,
    timeout_s: int = 10,
) -> List[str]:
    if provider == "ollama":
        return _list_ollama_models(base_url or "http://localhost:11434", timeout_s)
    elif provider == "gemini":
        return _list_gemini_models(api_key, timeout_s)
    elif provider == "openai":
        return _list_openai_models(api_key, timeout_s)
    else:
        raise LLMError(f"Unknown LLM provider: {provider}")


def _list_ollama_models(base_url: str, timeout_s: int) -> List[str]:
    url = f"{base_url.rstrip('/')}/api/tags"
    try:
        resp = requests.get(url, timeout=timeout_s)
        if resp.status_code != 200:
            return []
        data = resp.json()
        return [m["name"] for m in data.get("models", [])]
    except Exception:
        return []


def _list_gemini_models(api_key: Optional[str], timeout_s: int) -> List[str]:
    if not api_key:
        return []
    url = f"https://generativelanguage.googleapis.com/v1beta/models?key={api_key}"
    try:
        resp = requests.get(url, timeout=timeout_s)
        if resp.status_code != 200:
            return []
        data = resp.json()
        models = []
        for m in data.get("models", []):
            name = m.get("name", "")
            if name.startswith("models/"):
                name = name[len("models/") :]
            # Filter for models that support generation
            if "generateContent" in m.get("supportedGenerationMethods", []):
                models.append(name)
        return models
    except Exception:
        return []


def _list_openai_models(api_key: Optional[str], timeout_s: int) -> List[str]:
    if not api_key:
        return []
    url = "https://api.openai.com/v1/models"
    try:
        resp = requests.get(
            url,
            headers={"Authorization": f"Bearer {api_key}"},
            timeout=timeout_s,
        )
        if resp.status_code != 200:
            return []
        data = resp.json()
        # Filter for common chat models to avoid clutter
        chat_models = [
            m["id"]
            for m in data.get("data", [])
            if any(x in m["id"] for x in ["gpt-4", "gpt-3.5", "o1"])
        ]
        return sorted(chat_models)
    except Exception:
        return []


def _generate_ollama(
    model: str,
    prompt: str,
    base_url: str,
    timeout_s: int,
    num_ctx: int,
) -> str:
    url = f"{base_url.rstrip('/')}/api/generate"
    try:
        resp = requests.post(
            url,
            json={
                "model": model,
                "prompt": prompt,
                "stream": False,
                "options": {
                    "num_ctx": num_ctx,
                },
            },
            timeout=timeout_s,
        )
    except requests.RequestException as e:
        raise LLMError(f"Failed to reach Ollama at {base_url}: {e}") from e

    if resp.status_code != 200:
        raise LLMError(f"Ollama returned {resp.status_code}: {resp.text[:300]}")

    data = resp.json()
    text = data.get("response")
    if not isinstance(text, str):
        raise LLMError("Ollama response missing 'response' text")
    return text.strip()


def _generate_gemini(
    model: str,
    prompt: str,
    api_key: Optional[str],
    timeout_s: int,
) -> str:
    if not api_key:
        raise LLMError("Gemini API key is required")

    # Use a default model if only "gemini" was specified
    if model == "gemini":
        model = "gemini-1.5-flash"

    url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={api_key}"
    try:
        resp = requests.post(
            url,
            json={
                "contents": [{"parts": [{"text": prompt}]}],
            },
            timeout=timeout_s,
        )
    except requests.RequestException as e:
        raise LLMError(f"Failed to reach Gemini API: {e}") from e

    if resp.status_code != 200:
        raise LLMError(f"Gemini returned {resp.status_code}: {resp.text[:300]}")

    data = resp.json()
    try:
        text = data["candidates"][0]["content"]["parts"][0]["text"]
        return text.strip()
    except (KeyError, IndexError):
        raise LLMError(f"Unexpected Gemini response format: {data}")


def _generate_openai(
    model: str,
    prompt: str,
    api_key: Optional[str],
    timeout_s: int,
) -> str:
    if not api_key:
        raise LLMError("OpenAI API key is required")

    # Use a default model if only "openai" was specified
    if model == "openai":
        model = "gpt-4o-mini"

    url = "https://api.openai.com/v1/chat/completions"
    try:
        resp = requests.post(
            url,
            headers={
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json",
            },
            json={
                "model": model,
                "messages": [{"role": "user", "content": prompt}],
            },
            timeout=timeout_s,
        )
    except requests.RequestException as e:
        raise LLMError(f"Failed to reach OpenAI API: {e}") from e

    if resp.status_code != 200:
        raise LLMError(f"OpenAI returned {resp.status_code}: {resp.text[:300]}")

    data = resp.json()
    try:
        text = data["choices"][0]["message"]["content"]
        return text.strip()
    except (KeyError, IndexError):
        raise LLMError(f"Unexpected OpenAI response format: {data}")


