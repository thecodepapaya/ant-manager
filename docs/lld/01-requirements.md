# LLD 01 — Requirements

Step 1 of the low-level design (Hello Interview style: requirements → entities → class design → implementation →
extensibility). Agreed with the owner on 2026-11-18. Product context: [../SPEC.md](../SPEC.md),
rationale: [../DECISIONS.md](../DECISIONS.md) (the harness pivot is #47–#54).

## Framing: Ant Manager is a harness

```
Sources ──► EVIDENCE ──► NARRATIVE ──► tool layer ──► Reports · Wins · (later) Chat · (later) MCP
            raw, cited     typed facts,
            records        each citing evidence
```

## Vocabulary (fixed for the rest of the LLD)

| Term | Meaning |
|---|---|
| **Evidence** | Any captured record of work: commit, PR/review, calendar event, note (text or screenshot + optional link), etc. Notes can be added for any day, including past days. |
| **Fact** | One typed statement in the Narrative, citing ≥ 1 evidence item. Types: **Outcome, Problem solved, Invisible work, Hiccup, Decision, Time allocation**. Facts are grouped into **Workstreams** (an entity, see 02-entities). Labelled *model-inferred* or *user-confirmed*; time facts are *measured* or *estimated*. |
| **Narrative** | The set of all facts for a profile: the defensible, continuously maintained model of the work. Answers "what did I work on, which projects, what invisible work, what problems were solved, where did time go, what went wrong". |
| **Report** | A read-only rendering of the Narrative for a period (daily, weekly, monthly, quarterly or custom) through a template. Can be locked. A "review doc" is a quarterly or custom report with a review template. |
| **Win** | An Outcome fact or starred evidence in the Wins log, including model suggestions the user accepted. |
| **Tool** | A typed query over Evidence and the Narrative (search evidence, get facts, time breakdown, workstream timeline…). Every consumer reads through tools. |

## Functional requirements (core: designed in full)

1. **Capture evidence:**
   - **notes:** text, or screenshot + optional link; can be added **for any day, including past days**
   - **git commits:** automatic, from watched repos
   - **PRs/reviews:** the host and repo are derived from each repo's `origin` remote; one token or sign-in per host
   - **calendar events**
2. **Maintain the Narrative:** extract typed facts from evidence incrementally as it arrives. Every fact cites evidence.
   User-touched facts are never overwritten or removed by the model.
3. **Correct the Narrative:** the user can confirm, edit or reject facts, and add evidence. This is the *only* way to
   change what outputs say.
4. **Generate reports** for daily, weekly, monthly, **quarterly** and custom ranges by querying the Narrative for the
   period and rendering it with a template. On a schedule and on demand. **Reports are not editable.**
5. **Lock reports:** a locked report is a frozen snapshot, never regenerated, showing "facts changed since lock".
   **Unlocking is allowed** and recorded in history.
6. **Reports list:** browse, open, lock or unlock, regenerate (if unlocked) after facts or evidence change. Old
   versions are kept.
7. **Timeline** of all evidence, filterable by source, project and date.
8. **Wins:** a view over Outcome facts + starred evidence; star manually, or accept or reject model-suggested wins.
9. **Model choice:** local models, network endpoints (OpenAI-compatible or Ollama on localhost, LAN or remote), or cloud
   providers with the user's own keys. One default model plus optional overrides for Vision, Extraction and Reports.
10. **Background (tray) operation:**
    - It captures evidence promptly. Repos are watched so that commits later removed by squash, rebase or force-push are still recorded.
    - It keeps the Narrative up to date and runs scheduled jobs (reports, nudge, backup).
    - It hosts the quick-capture hotkey.
    - **Quitting is safe:** everything catches up on the next launch (missed schedules run once).
    - Only the **active profile** runs in the background.
11. **Profiles:** separate data, sources, identities, models and schedules per profile.
12. **Projects & curation:** group evidence and facts into projects (auto-suggested, user-confirmed), hide or exclude
    evidence (including rules), annotate evidence.
13. **Tool layer:** every consumer (reports, Wins, UI queries) reads Evidence and the Narrative through typed query tools,
    so a future chat or MCP server can reuse them unchanged.

## Below the line (designed *for*, not detailed in this LLD)

These must fit the core abstractions without changing them. The extensibility step (LLD step 5) shows how.

- **Chat interface** over the Narrative (uses the tool layer)
- **MCP server** exposing the tool layer to external agents (deferred; off by default when built)
- Full-text **search UI** (the FTS5 index itself is core) and semantic search with embeddings
- Additional sources: Linear, Jira Cloud, meeting transcripts, ICS (also how Outlook is supported), Apple / Google calendar specifics
- Share and export formats (Slack, rich text, Markdown, PDF)
- Backup and restore (local folder only)
- Scheduled-generation settings UI, end-of-day nudge, quick-capture UI
- Prompt-template editor
- Onboarding flow
- Auto-update, crash reporting

## Non-functional requirements

| # | Requirement | Target / definition |
|---|---|---|
| N1 | **Perceived low latency** | Opening Today or a report is instant (< 200 ms from local data). Generation streams: first token ≤ 2 s on cloud, ≤ 5 s on a warm local model. Scheduled reports and fact extraction are precomputed. Fact extraction is incremental, and prompt size is budgeted. Generation never blocks the UI and can be cancelled. (Total generation time on slow local hardware is explicitly *not* guaranteed.) |
| N2 | **Privacy** | All data at rest stays on the machine. Network traffic goes only to the configured AI provider and connected source APIs. No telemetry unless opted in. Secrets live only in the OS keychain. Remote providers get a one-time consent notice. |
| N3 | **Durability** | No data loss on crash or force-quit: transactional writes (SQLite WAL), idempotent and resumable syncs and extraction, a job queue that survives restarts. |
| N4 | **Offline-first** | Everything except cloud AI calls and remote source sync works offline. |
| N5 | **Footprint** | Near-zero idle CPU in the tray (event-driven watching, backed-off polling). Memory budget roughly 200 MB resident in the tray, to be validated. |
| N6 | **Scale** | Smooth with several years of data (≈100k evidence items and their facts per profile): timeline at 60 fps, paginated and indexed queries, FTS5 for text retrieval. |
| N7 | **Extensibility** | A new source, provider, fact type, tool, backup destination or export format = one new class + one registration, with no edits to existing code. |
| N8 | **Testability** | Core logic is testable without Flutter (`packages/core`, `dart test`). External APIs and clock are behind interfaces. Fact extraction has fixture-based evaluations (quality), not just unit tests. |
| N9 | **Defensibility** | No fact without a citation. The inferred/confirmed and measured/estimated labels are always visible. Every report statement traces to facts, and every fact traces to evidence. |

## Open points

- ~~Regenerate with a style instruction~~: **resolved, yes** (wording only, stored on the snapshot; see 02-entities).
- Revisit N5's memory budget once there's a running build.
- The mockup predates this pivot (it shows editable reports and no facts view). It's still valid as design language only.
