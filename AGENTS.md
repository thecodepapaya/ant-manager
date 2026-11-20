# AGENTS.md

Guidance for coding agents in this repo.

## Layout
- `docs/`: v1 design. `SPEC.md` = what (authoritative); `DECISIONS.md` = numbered why-log (append only, mark superseded
  rows `⟶ see #N`); `lld/` = low-level design, step status in `lld/README.md`; `OWNER_TODO.md` = owner-only external tasks.
- `app/`, `packages/core`, `packages/ui`: v1 code (Dart pub workspace).
- `web/` + `wrangler.json`: Cloudflare Pages site; don't move.

## Architecture rules
- Harness: Sources → Evidence (payloads) → Narrative (typed facts citing payload revisions) → read-only Reports / Wins
  via the tool layer. Reports are never edited.
- `core` is pure Dart (no Flutter). `ui` doesn't depend on `core`. Platform services = ports in `core`, adapters in `app`.
- Engine isolate owns the DB, jobs, sources and LLM calls; the UI reads drift streams and writes only via `AntEngine`.
- Staleness is computed from recorded input revisions; triggers enqueue recompute work in the same transaction.
- The model never overwrites user-touched data. All models must support native structured output.
- No visual literals outside `AntTokens`.

## Working rules
- Simple over complete (#67): no fallbacks or settings for edge cases.
- **Tests are never written by the agent that wrote the code** (#99): a different agent writes them; `sarvam-code`
  (DeepSeek v4.1 flash, read-only) verifies them.
- Record every decision in DECISIONS + SPEC + the relevant LLD doc (+ OWNER_TODO if external).
- Explain tradeoffs briefly before asking. Keep responses concise.
- Git: `main` is the source of truth; work happens on `v1.1` (agents branch from it and merge back); push to `v1.1` allowed, never to `main`; tagged releases are public and unsigned (#134).

