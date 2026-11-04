# Bug Verification: Automatic Browser Locale Detection on Initial Startup

- **Slug**: auto-i18n
- **Tested**: 2026-11-04
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified

## Summary

The bug no longer reproduces: when `localStorage` has no saved language preference (`evolution_sim_locale_v1`), `loadLocaleFromLocalStorage()` and `resolveInitialLocale()` now detect and normalize the browser's preferred language from `navigator.languages` / `navigator.language`, while preserving `localStorage` override priority and `"en"` fallback for unsupported languages. All unit, contract, and integration tests pass with zero regressions.

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| Reproduction (post-fix) | `npx vitest run tests/unit/i18n.test.ts --reporter=verbose` | pass | Simulated clean `localStorage` with `navigator.languages = ["es-MX", "en-US"]`; verified `detectBrowserLocale()` and `loadLocaleFromLocalStorage()` resolve to `"es"` instead of `"en"` |
| New / updated tests | `npx vitest run tests/unit/i18n.test.ts --reporter=verbose` | pass | 6/6 tests in `tests/unit/i18n.test.ts` passed, including BCP-47 normalization and `localStorage` override priority |
| Regression suite | `npm test` | pass | 6/6 test files (41/41 tests) passed across unit, contract, and integration suites |
| Lint / type-check | `npm run build` | pass | `tsc --noEmit && vite build` succeeded with 0 TypeScript or bundler errors |

## Output Excerpts

```text
 ✓ tests/unit/i18n.test.ts > i18n configuration and 8-locale dictionary parity (FR-015, SC-006) > initializes i18n with English ('en') as the default and fallback language 2ms
 ✓ tests/unit/i18n.test.ts > i18n configuration and 8-locale dictionary parity (FR-015, SC-006) > ensures 100% identical flattened leaf key sets and non-empty strings across all 8 locales 25ms
 ✓ tests/unit/i18n.test.ts > i18n configuration and 8-locale dictionary parity (FR-015, SC-006) > includes all 7 base decisions, 11 base traits, 7 biomes, and 3 scientific presets in all 8 locales 5ms
 ✓ tests/unit/i18n.test.ts > i18n configuration and 8-locale dictionary parity (FR-015, SC-006) > dynamically switches language across all 8 locales via changeAppLocale and restores back to 'en' 3ms
 ✓ tests/unit/i18n.test.ts > i18n configuration and 8-locale dictionary parity (FR-015, SC-006) > normalizes BCP-47 browser language tags and matches the first supported locale 0ms
 ✓ tests/unit/i18n.test.ts > i18n configuration and 8-locale dictionary parity (FR-015, SC-006) > detects browser locale from navigator and prioritizes stored localStorage locale when present 0ms

 Test Files  6 passed (6)
      Tests  41 passed (41)
```

## Residual Risks

- Users who previously manually selected a language in the Settings menu already have `evolution_sim_locale_v1` stored in `localStorage`; by design, their saved preference takes precedence over browser locale detection unless `localStorage` is cleared.

## Recommendation

Close the bug — verified end-to-end across browser locale detection, regional BCP-47 normalization, `localStorage` override precedence, and full regression/build checks.
