# Bug Assessment: Automatic Browser Locale Detection on Initial Startup

- **Slug**: auto-i18n
- **Created**: 2026-11-04
- **Source**: pasted text
- **Verdict**: valid
- **Severity**: medium

## Report (verbatim or summarized)

> "Cuando se abre la aplicacion en el navegador debe detectar el idioma, ahora se inicia siempre en ingles y dependemos del selector manual"

## Symptom

When opening the application in the browser without a previously saved language preference in `localStorage`, the UI always initializes in English (`"en"`) instead of automatically detecting and applying a matching supported browser locale (`navigator.languages` / `navigator.language`), forcing users to manually switch the language in the settings menu.

## Reproduction

1. Open the application in a browser configured with a supported non-English preferred language (e.g., `es-ES` or `es`) in a clean session where `localStorage.getItem("evolution_sim_locale_v1")` is empty.
2. Observe the Welcome Dialog and Top Control Bar UI text.
3. All text renders in English (`"en"`) rather than Spanish (`"es"`), requiring manual changes via the Settings language selector (`#locale-select`).

## Suspected Code Paths

- `src/store/persistence.ts:40-46` — `loadLocaleFromLocalStorage()` checks `localStorage.getItem(LOCALE_STORAGE_KEY)` and immediately falls back to `DEFAULT_LOCALE` (`"en"`) when `stored === null`, never inspecting browser language preferences.
- `src/store/useSimulationStore.ts:273-278` — `resolveInitialLocale()` delegates directly to `loadLocaleFromLocalStorage()` and returns `"en"` when `localStorage` is unavailable or unpopulated.
- `src/i18n/index.ts:35-42` — Initializes `i18next` with `lng: DEFAULT_LOCALE` before `useSimulationStore` calls `changeAppLocale(initialLocale)`.

## Root Cause Hypothesis

Confidence: **high**. `loadLocaleFromLocalStorage()` in `src/store/persistence.ts` only checks `localStorage` for `LOCALE_STORAGE_KEY` (`"evolution_sim_locale_v1"`) and unconditionally returns `DEFAULT_LOCALE` (`"en"`) when no stored value exists. Neither `src/store/persistence.ts`, `src/store/useSimulationStore.ts`, nor `src/i18n/index.ts` inspects `navigator.languages` or `navigator.language` to match the user's browser locale (e.g., normalizing BCP-47 tags like `"es-ES"` or `"pt-BR"` to their base language code `"es"` or `"pt"` against `SUPPORTED_LOCALES`).

## Proposed Remediation

**Preferred**: Add a pure browser-locale detection helper (e.g., `detectBrowserLocale()` in `src/i18n/index.ts` or `src/store/persistence.ts`) that inspects `navigator.languages` (and `navigator.language`), extracts the primary language subtag (`tag.split("-")[0].toLowerCase()`), and returns the first candidate matching `SUPPORTED_LOCALES` (`"en" | "es" | "zh" | "fr" | "de" | "pt" | "ja" | "ru"`), falling back to `DEFAULT_LOCALE` (`"en"`) if no match is found or `navigator` is unavailable. Update `loadLocaleFromLocalStorage()` / `resolveInitialLocale()` so that:
1. An explicit user selection saved in `localStorage` (`LOCALE_STORAGE_KEY`) takes highest priority.
2. When no stored preference exists in `localStorage`, the detected browser locale is used.
3. If the browser locale is not among `SUPPORTED_LOCALES`, `DEFAULT_LOCALE` (`"en"`) is used as fallback.

**Alternatives** (optional):
- Add `i18next-browser-languagedetector` as an external dependency — rejected under KISS principles since normalizing `navigator.languages` against the 8-element `SUPPORTED_LOCALES` tuple takes ~10 lines of dependency-free TypeScript and keeps store state (`useSimulationStore.getState().locale`) and `i18n.language` synchronized from a single source of truth.

**Files likely to change**:
- `src/store/persistence.ts`
- `src/store/useSimulationStore.ts`
- `src/i18n/index.ts`
- `tests/unit/i18n.test.ts`

**Tests to add or update**:
- Unit tests in `tests/unit/i18n.test.ts` verifying:
  - Browser language tag normalization and matching (e.g., `["es-ES", "en-US"]` -> `"es"`, `["pt-BR"]` -> `"pt"`, `["zh-CN"]` -> `"zh"`).
  - Fallback to `"en"` when browser languages are unsupported (e.g., `["it-IT", "nl"]` -> `"en"`).
  - Priority of stored `localStorage` locale (`evolution_sim_locale_v1`) over browser language detection when the user has manually selected a language.

## Risks & Considerations

- Existing unit tests in `tests/unit/i18n.test.ts` assert `expect(i18n.language).toBe("en")` in the Vitest Node environment; ensuring fallback to `"en"` when `navigator` is undefined or set to English preserves existing test behavior while allowing explicit unit testing of browser locale detection.
- Must normalize regional BCP-47 tags (such as `es-419`, `es-MX`, `zh-TW`, `fr-CA`) by matching the base language code so all regional variants map cleanly to the 8 supported locales.

## Open Questions

- None.
