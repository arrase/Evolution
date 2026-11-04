# Implementation Plan: Visualización 2.5D del Terreno e Interacciones Expresivas de los Habitantes

**Branch**: `002-visual-map-interactions` | **Date**: 2026-11-04 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/002-visual-map-interactions/spec.md`

## Summary

Upgrade the flat 2D hexagonal SVG board into an expressive 2.5D topographic map and overhaul inhabitant (`Deme`) and interaction (`HexEdgeFlow`) visualizations so emergent evolutionary and social dynamics are immediately legible on the board:
- **2.5D Terrain & Ecological Overlays (US1):** Extrude terrestrial hexagons vertically according to `altitude` in back-to-front painter's order, add radial/linear biome gradients and vector biome illustrations (`tropical_forest`, `savanna`, `arid_steppe`, `tundra`, `high_mountain`, `coastal_shallows`, `ocean`), and display integrated resource abundance bars and habitat degradation contours (`carryingCapacity < 0.85 * carryingCapacityMax`) directly in the main view.
- **Expressive Deme Visual Tokens (US2):** Equip every `Deme` token on the board with a shared vital status ring (`thriving`, `stable`, `struggling`, `starving`), a top-right dominant decision archetype icon badge (`forage`, `overexploit`, `migrate`, `cooperate`, `exchange`, `dispute`, `innovate`, `custom`), and a top-left cultural tradition badge when `culturalTraitIds.length > 0`.
- **Direct Animated Deme-to-Deme Interaction Arcs (US3):** Extend `HexEdgeFlow` with an optional `targetDemeId` populated during `resolveBiophysicalAndDemographicPhase` (`src/engine/biophysicalPhase.ts`) and replace ambiguous cell-wide circles/lines with curved, animated quadratic Bézier arcs linking the exact source and target `Deme` token coordinates (both intra-hex and inter-hex) with midpoint interaction badges and enriched hover cards.
- **Interactive Map Camera Pan & Zoom (US4):** Add smooth SVG `viewBox` pan and zoom ($1.0\times\text{--}2.75\times$) via mouse wheel, pointer drag in `inspect` mode, and an accessible bottom-right camera control cluster (`Zoom In`, `Zoom Out`, `Reset View`) plus updated legend and 8-locale `i18n` translations.

## Technical Context

**Language/Version**: TypeScript `7.0.2` (strict mode, ESM `"type": "module"`)

**Primary Dependencies**:
- Build, UI & i18n: `vite@8.3.5`, `@vitejs/plugin-react@6.2.1`, `react@19.3.1`, `react-dom@19.3.1`, `zustand@5.0.16`, `i18next@26.7.1`, `react-i18next@17.1.12`, `tailwindcss@4.3.4`, `@tailwindcss/vite@4.3.4`, `lucide-react@1.67.0`
- Spatial Hex Geometry & Schema Validation: `honeycomb-grid@4.1.5`, `zod@4.6.7`

**Storage**: Client-side `localStorage` and portable JSON export/import validated with `zod@4.6.7` (`targetDemeId` optional for backward compatibility).

**Testing**: `vitest@5.1.0` for deterministic unit tests (`hexGrid.test.ts`, `biophysicalPhase.test.ts`, `i18n.test.ts`), contract tests, and integration tests.

**Target Platform**: Modern Desktop Web Browser.

**Project Type**: Interactive Web Simulation Application (Single-Project SPA with decoupled pure simulation engine).

**Performance Goals**:
- 2.5D SVG projection + deme tokens + animated arcs rendering at 60 fps during pan/zoom and `< 100 ms` turn updates across 61–169 hexagons.

**Constraints**:
- Strict adherence to KISS & YAGNI (Constitution Principle I): pure top-to-bottom functions, zero external canvas/zoom bloat libraries, all imports at top of file, respect `prefers-reduced-motion`.

**Scale/Scope**:
- 7 biome illustrations, 8 decision archetype badges, 4 vital status ring styles, 3 interaction arc styles (intra-hex and inter-hex), pan/zoom camera ($1.0\times\text{--}2.75\times$), and full 8-locale `i18n` parity (`en`, `es`, `zh`, `fr`, `de`, `pt`, `ja`, `ru`).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked and verified after Phase 1 design.*

| Constitution Principle | Pre-Research Check | Post-Design Check | Verification Evidence |
| :--- | :---: | :---: | :--- |
| **I. Radical Simplicity & Zero Defensive Bloat (KISS & YAGNI)** | PASS | PASS | Pure geometry helpers in `src/engine/hexGrid.ts` and `src/components/palette.ts`, native SVG `viewBox` pan/zoom without external wrapper libraries, top-of-file imports only. |
| **II. Scientific Rigor & Bio-Cultural Fidelity** | PASS | PASS | Biophysical laws remain pure and deterministic; `targetDemeId` in `src/engine/biophysicalPhase.ts` records the exact causal counterparty in Hawk-Dove disputes, symbiotic exchanges, and migratory fission. |
| **III. Dual-Frequency Cognitive Architecture (`d3` + `gemma4:e4b-it-qat`)** | PASS | PASS | Untouched and fully preserved; dominant decision archetypes evaluated by System 1 (`d3`) are now surfaced directly on each `Deme` token on the board. |
| **IV. Curated Modern TypeScript Ecosystem** | PASS | PASS | Uses existing `honeycomb-grid@4.1.5`, `lucide-react@1.67.0`, `zod@4.6.7`, and `react-i18next@17.1.12` without adding redundant dependencies. |
| **V. Transparent & Interactive Sandbox UX** | PASS | PASS | Directly enhances the Hexagonal Grid Map (5 visual layers per hex), hover inspector, legend, and 8-locale `i18n` support with English (`en`) as default. |

## Project Structure

### Documentation (this feature)

```text
specs/002-visual-map-interactions/
├── plan.md                                  # Implementation plan (/speckit-plan)
├── research.md                              # Phase 0 architectural & visual research
├── data-model.md                            # Phase 1 entities, 2.5D geometry & flow extensions
├── quickstart.md                            # Phase 1 validation & test guide
├── checklists/
│   ├── requirements.md                      # Spec quality checklist (/speckit-specify)
│   └── visual-ux.md                         # Domain & visual UX checklist (/speckit-checklist)
├── contracts/
│   └── visual-map.contract.md               # 2.5D terrain, deme token & direct flow contracts
└── tasks.md                                 # Phase 2 actionable tasks (/speckit-tasks)
```

### Source Code (repository root)

```text
src/
├── types/
│   └── simulation.ts                        # Extend HexEdgeFlowSchema with optional targetDemeId
├── engine/
│   ├── hexGrid.ts                           # Add computeHex25DGeometry & painter's order sorting
│   └── biophysicalPhase.ts                  # Populate targetDemeId in dispute, exchange & migration flows
├── components/
│   ├── palette.ts                           # Add getDemeStatus, DEME_STATUS_RINGS, BIOME_RELIEF_COLORS, DECISION_ARCHETYPE_VISUALS
│   ├── HexMapCanvas.tsx                     # 2.5D terrain, biome motifs, ecological bars, expressive deme tokens, direct Bézier arcs & pan/zoom
│   ├── ContextPanel.tsx                     # Reuse shared getDemeStatus from palette.ts
│   └── MapLegend.tsx                        # Include vital status & dominant action archetype legend keys
├── i18n/
│   └── locales/                             # Add map camera, archetype & interaction keys across all 8 locales (en.json, es.json, zh.json, fr.json, de.json, pt.json, ja.json, ru.json)
└── index.css                                # Add animated dash flow rules respecting prefers-reduced-motion

tests/
├── unit/
│   ├── hexGrid.test.ts                      # Test computeHex25DGeometry elevation & painter's order
│   ├── biophysicalPhase.test.ts             # Test targetDemeId emission on dispute, exchange & migration flows
│   └── i18n.test.ts                         # Verify 100% locale key parity across all 8 languages
```

**Structure Decision**: Extend the existing single-project modules (`src/types/`, `src/engine/`, `src/components/`, `src/i18n/`, `tests/unit/`) in place without introducing unnecessary intermediate folders or wrapper layers.

## Complexity Tracking

No Constitution violations exist. All 5 Core Principles pass without exception.
