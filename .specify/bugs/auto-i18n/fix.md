# Bug Fix: Automatic Browser Locale Detection on Initial Startup

- **Slug**: auto-i18n
- **Fixed**: 2026-11-04
- **Assessment**: ./assessment.md
- **Status**: applied

## Summary

Added automatic browser locale detection (`matchSupportedLocale` and `detectBrowserLocale`) that inspects `navigator.languages` / `navigator.language`, normalizes regional BCP-47 tags to their primary language subtag, and applies the first matching supported locale when no user-selected locale is saved in `localStorage`, falling back to `"en"` when the browser language is unsupported.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `src/i18n/index.ts` | modified | Added `matchSupportedLocale()` and `detectBrowserLocale()` |
| `src/store/persistence.ts` | modified | Updated `loadLocaleFromLocalStorage()` to fall back to `detectBrowserLocale()` when no stored preference exists |
| `src/store/useSimulationStore.ts` | modified | Updated `resolveInitialLocale()` to use `detectBrowserLocale()` when `localStorage` is unavailable |
| `tests/unit/i18n.test.ts` | added test | Added unit tests for BCP-47 tag normalization, browser locale detection, and `localStorage` priority |

## Diff Highlights (optional)

```typescript
export function matchSupportedLocale(languageTags: readonly string[]): SupportedLocale {
  for (const tag of languageTags) {
    const primarySubtag = tag.split("-")[0]!.toLowerCase();
    const matched = SUPPORTED_LOCALES.find((locale) => locale === primarySubtag);
    if (matched !== undefined) {
      return matched;
    }
  }
  return DEFAULT_LOCALE;
}

export function detectBrowserLocale(): SupportedLocale {
  if (typeof navigator === "undefined") {
    return DEFAULT_LOCALE;
  }
  const tags = navigator.languages.length > 0 ? navigator.languages : [navigator.language];
  return matchSupportedLocale(tags);
}
```

## Tests Added or Updated

- `tests/unit/i18n.test.ts::normalizes BCP-47 browser language tags and matches the first supported locale` — verifies regional language tag normalization (`es-ES` -> `es`, `pt-BR` -> `pt`, `zh-CN` -> `zh`, `fr-CA` -> `fr`) and fallback to `en` for unsupported tags.
- `tests/unit/i18n.test.ts::detects browser locale from navigator and prioritizes stored localStorage locale when present` — verifies `detectBrowserLocale()` and `loadLocaleFromLocalStorage()` detect the browser language when `localStorage` is empty and respect an explicit `localStorage` override when set.

## Local Verification

- Commands run:
  - `npm run typecheck` → passed (`tsc --noEmit` with 0 errors)
  - `npm test` → passed (6 test files, 41 tests passed)
- Manual checks: Verified `resolveInitialLocale()` and `loadLocaleFromLocalStorage()` trace from startup to `changeAppLocale(initialLocale)`.

## Deviations from Assessment

None.

## Follow-ups

- Run `/speckit-bug-test slug=auto-i18n` to validate and record the verification report.
