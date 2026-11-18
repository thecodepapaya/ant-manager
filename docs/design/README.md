# Design references

- **Clickable mockup** (design language only, not the final UI): https://claude.ai/artifact/CcJvVbVc2iLQccTWAetEQJ
  (private to the owner until shared). Artboards: App window (all sidebar screens), Onboarding, Quick capture, Menu bar.
- **[tokens.css](./tokens.css):** the mockup's design tokens. Same names and structure as the Flutter `AntTokens`
  ThemeExtension planned in SPEC §10: semantic colours (dark + light), accent variants derived from one `--accent`
  seed, and a radius scale derived from one `--radius` base.
- **Logo:** `legacy/app/assets/icon.png` and `legacy/app/assets/logo.webp` (two black ants on warm off-white).

Known gaps from the owner's review (fix in the real UI, see SPEC §10 "UX principles"): padding and spacing
inconsistencies, no obvious global model, notes hard to find, intimidating for new users, and a placeholder
hand-drawn logo instead of the real one.

**Superseded by the harness pivot (DECISIONS #47–#53):** the mockup shows editable reports ("Edit" on Today, an
edit-locked weekly) and no Narrative/facts view. Reports are now read-only renderings of the Narrative; corrections
happen on facts and evidence.
