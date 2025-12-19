from __future__ import annotations


SYSTEM_RULES = """You are a local, privacy-first assistant for writing neutral, evidence-backed work summaries.

Hard rules:
- Do not invent facts.
- If evidence is insufficient, say so explicitly.
- Keep tone factual and calm (no defensiveness, no blame).
- Prefer bullet points.
"""


def daily_prompt(evidence_snippets: str, notes: str) -> str:
    return f"""{SYSTEM_RULES}

Task: Produce a daily summary for the user based ONLY on the evidence.

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


def wins_prompt(evidence_snippets: str, notes: str, period_label: str) -> str:
    return f"""{SYSTEM_RULES}

Task: Produce a {period_label} wins list that is promotion-ready and factual.

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


