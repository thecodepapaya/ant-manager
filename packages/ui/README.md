# ui

Ant Manager design tokens and components (SPEC §10, DECISIONS #39–#42). No dependency on `core`.

- `MaterialApp(theme: antTheme(AntTokens.dark()), darkTheme: …)`, then `context.tokens` in widgets.
- Literals live only in `lib/src/tokens/`. Check: `dart run packages/ui/tool/check_tokens.dart` (repo root).
- Gallery: `cd example && flutter run -d macos`.
- Fonts: Inter 4.1 (rsms/inter release, static 400–700) and JetBrains Mono (google/fonts, variable), both SIL OFL 1.1;
  licenses in `assets/fonts/*/OFL.txt`.
