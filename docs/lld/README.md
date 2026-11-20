# Low-level design

Done step by step with the owner, both sides reviewing and challenging each other (DECISIONS #46), following a
Hello Interview-style LLD flow. Guiding principle: **simple over complete** (#67).

| Step | Doc | Status |
|---|---|---|
| 1. Requirements | [01-requirements.md](./01-requirements.md) | Agreed |
| 2. Entities & relationships | [02-entities.md](./02-entities.md) | Agreed |
| 3. Class design | [03-class-design.md](./03-class-design.md) | Part 1 agreed (#67–82); Part 2 (app/ui) built directly (#101, #105, #107) |
| 4. Implementation (key algorithms) | [04-implementation.md](./04-implementation.md) | Agreed (#88–#92), refined while building (#100–#108) |
| 5. Extensibility | — | Not started |

**Build (on `v1`):** implementation **done**; independent tests (#99) **in progress**; end-to-end run with OpenRouter
(#96) **in progress**.

## Known gaps

Accepted for now under #67, verified against the code (2026-11-19):
- Sentry DSN not wired: crash-report opt-in stores the preference only (#105, OWNER_TODO).
- Auto-update not wired: appcast generation is a TODO in `build.yml` and `auto_updater` isn't called; no Linux
  "update available" notice either.
- Google OAuth client id/secret are placeholders (`google_oauth.dart`, OWNER_TODO).
- GitHub device flow later: PAT only (#106).
- Existing profile DBs keep old triggers: no trigger migration (pre-release). Schema v2 only adds payload
  occurred-time columns (#NEXT).
- GitHub issues you closed without being subscribed are missed (#106).
- Custom CA / insecure TLS options exist for AI providers only, not for self-hosted sources (SPEC §5).
- Stale reports aren't regenerated when opened (shown "Out of date"; regenerate on demand). No nudge snooze.

Every decision is logged with its rationale in [../DECISIONS.md](../DECISIONS.md).

## Scope audit (2026-11-18)

While the owner was away I went through SPEC, DECISIONS, OWNER_TODO and LLD 01–03 end to end.

**Fixed (mechanical, following decisions already made):**
- SPEC still described the pre-LLD architecture (folder sketch, old `EvidenceSource` contract, "isolates" for heavy
  work). Now it points to the engine isolate (#68), the workspace layout (#45) and the `Source` contract.
- SPEC still mentioned the private/remote network label, per-task model lists, "streaming into the editor",
  annotations as a separate concept, Workstream as a fact type, "roll-up provenance", and "narratives" as report text.
  All updated to #56, #63, #65, #70, #74 and #75.
- SPEC said meeting transcripts are "matched to the overlapping calendar event". That's fuzzy grouping, which #57 forbids,
  so it now uses the existing *suggested attach* rule (you confirm).
- The Provider entity still had `network_class`; it's replaced by TLS options. The Model entity now records structured-output
  support (#70).
- DECISIONS: 11 older rows that later decisions refine now carry a "⟶ see #…" pointer.

**Questions for the owner: answered 2026-11-18** (#83–#87):

1. **Where can notes attach?** SPEC said notes attach to "a day, project, fact, win or report", but the entity model
   (#56) only lets a note be standalone evidence or a payload on existing evidence. **Proposed:** keep the entity model;
   "add context" on a report or win creates a note dated inside that period (and tagged to its project, if any).
   Notes never attach to facts: you correct facts directly instead. → **Yes.**
2. **Tags on notes:** the quick-capture mockup had tags ("Recognition", "Blocker"), but no entity has tags.
   **Proposed:** no tags in v1 (project only); recognition is just a note with a screenshot + link. → **None in v1.**
3. **Hard delete:** the design never deletes history (tombstones, append-only revisions). But if something private gets
   captured by mistake (a personal calendar event, a screenshot with a password), you need it *gone*. **Proposed:** a
   user-only "Delete permanently" on evidence that purges its payloads, revisions and attachments; facts citing it
   lose those citations and, if none remain, are retired. → **Yes** (algorithm: 04-implementation §4.12).
4. **Template editor in v1?** SPEC §8 says templates can be duplicated and edited (with a live preview); LLD 01 lists the
   template editor as below the line. Under #67, **proposed:** built-in templates only in v1, editor later. → **No: the template editor is in v1.**
5. **Language and time zone:** **proposed** English-only UI in v1, and one time zone per profile (defaults to the system's)
   used for day boundaries. → **Yes.**
6. **Answered** (#88–#92): the five points at the end of [04-implementation.md](./04-implementation.md) (import window, diff cap, time
   estimation heuristic, minimal enrichment, structured reports).

**Checked and consistent (no action):** platforms and distribution, signing plan, profiles and identities, custom
endpoints, consent rule, backup scope, the Wins model, staleness invariants, OWNER_TODO after the simplification pass,
mockup flagged as design-language only.
