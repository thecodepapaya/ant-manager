from __future__ import annotations
from core.config import load_config


DEFAULT_SYSTEM_RULES = """You are a local, privacy-first assistant for writing neutral, evidence-backed work summaries.

Hard rules:
- Do not invent facts.
- If evidence is insufficient, say so explicitly.
- Keep tone factual and calm (no defensiveness, no blame).
- Prefer bullet points.
"""


def get_system_rules() -> str:
    cfg = load_config()
    return cfg.prompt_system_rules or DEFAULT_SYSTEM_RULES


DEFAULT_DAILY_PROMPT = """Task: Produce a daily summary for the user based ONLY on the evidence.

Output format (plain text):
Summary:
- ...

Key Work:
- ...

Blockers:
- ...

Evidence Used:
- ...

Evidence snippets:
{evidence_snippets}

User notes (may include blockers / clarifications):
{notes}
"""


def daily_prompt(evidence_snippets: str, notes: str) -> str:
    cfg = load_config()
    template = cfg.prompt_daily_summary or DEFAULT_DAILY_PROMPT
    
    # Ensure system rules are included if the template doesn't seem to have its own system instructions
    # or just prepend them as before for consistency if requested.
    # The original implementation prepended SYSTEM_RULES.
    system_rules = get_system_rules()
    
    return f"""{system_rules}

{template.format(evidence_snippets=evidence_snippets, notes=notes)}"""


DEFAULT_WINS_PROMPT = """Task: Produce a {period_label} wins list that is promotion-ready and factual.

Output format (plain text):
Wins:
- ...

Evidence Used:
- ...

Evidence snippets:
{evidence_snippets}

User notes:
{notes}
"""


def wins_prompt(evidence_snippets: str, notes: str, period_label: str) -> str:
    cfg = load_config()
    template = cfg.prompt_wins_list or DEFAULT_WINS_PROMPT
    system_rules = get_system_rules()
    
    return f"""{system_rules}

{template.format(period_label=period_label, evidence_snippets=evidence_snippets, notes=notes)}"""


DEFAULT_COMMIT_SUMMARY_PROMPT = """Task: Summarize this git commit briefly in one line or two. Keep is factual.

Focus on "what" changed and "why" (if evident). Avoid technical minutiae unless critical.

Commit Details:
{details}
"""


def commit_summary_prompt(details: str) -> str:
    cfg = load_config()
    template = cfg.prompt_commit_summary or DEFAULT_COMMIT_SUMMARY_PROMPT
    system_rules = get_system_rules()

    return f"""{system_rules}

{template.format(details=details)}"""


def get_default_prompts() -> dict[str, str]:
    return {
        "system_rules": DEFAULT_SYSTEM_RULES,
        "daily_summary": DEFAULT_DAILY_PROMPT,
        "wins_list": DEFAULT_WINS_PROMPT,
        "commit_summary": DEFAULT_COMMIT_SUMMARY_PROMPT,
    }


