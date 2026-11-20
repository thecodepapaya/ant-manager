# Design references

- **Clickable mockup** (design language only, not the final UI): https://claude.ai/artifact/CcJvVbVc2iLQccTWAetEQJ
  (private to the owner until shared). Artboards: App window (all sidebar screens), Onboarding, Quick capture, Menu bar.
- **[tokens.css](./tokens.css):** the mockup's design tokens. Same names and structure as the Flutter `AntTokens`
  ThemeExtension planned in SPEC §10: semantic colours (dark + light), accent variants derived from one `--accent`
  seed, and a radius scale derived from one `--radius` base.
- **Logo:** vector sources in `app/assets/brand/`: `logo.svg` (two black ants on warm off-white, traced from the original artwork), `ant.svg` (one ant, transparent: macOS menu bar template; Windows/Linux trays use the `app-icon.svg` tile), `app-icon.svg` (rounded macOS-style tile). Raster icons (tray PNG, macOS AppIcon set, Windows `.ico`) are rendered from these with `resvg`; never edit the PNGs by hand (#123).

Known gaps from the owner's review (fix in the real UI, see SPEC §10 "UX principles"): padding and spacing
inconsistencies, no obvious global model, notes hard to find, intimidating for new users, and a placeholder
hand-drawn logo instead of the real one.

**Superseded by the harness pivot (DECISIONS #47–#53):** the mockup shows editable reports ("Edit" on Today, an
edit-locked weekly) and no Narrative/facts view. Reports are now read-only renderings of the Narrative; corrections
happen on facts and evidence.

**Mockup source** (visual reference for the Flutter screens): [mockup/](./mockup/), the HTML of each artboard.
Match its look (sidebar, density, type, chips, panels, empty states). Don't copy its outdated UX: editable reports,
per-task model table first, hard-to-find notes.
