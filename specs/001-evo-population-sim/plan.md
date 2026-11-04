# Implementation Plan: Simulador Evolutivo y Socio-Cultural de Poblaciones (Evolution)

**Branch**: `001-evo-population-sim` | **Date**: 2026-11-03 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-evo-population-sim/spec.md`

## Summary

Design and build a single-page interactive evolutionary and socio-cultural population simulation game on a hexagonal grid in strict TypeScript. The architecture separates a pure, deterministic biophysical simulation engine (energy conservation, carrying capacity $K$, $r/K$ demography, Hawk-Dove evolutionary game theory, Baldwin genetic assimilation, Dual Inheritance cultural traditions, and allopatric speciation) from a Dual-Frequency Cognitive AI Engine powered by local Ollama models:
- **System 1 (`d3:4b` via `ollama/browser` `systemone()` API):** Evaluates each local subpopulation (*deme*) and its 6 equidistant neighboring hexagons every generational turn to return normalized decision probabilities in ~58 ms per deme without text generation bloat.
- **System 2 (`gemma4:e4b-it-qat` via `@langchain/ollama` `ChatOllama.withStructuredOutput()` with `think: false`):** Synthesizes open-ended emergent biological traits and cultural traditions at evolutionary milestones, assists the player in co-designing new catalog items within strict thermodynamic bounds, and writes causal entries in the Naturalist Notebook.

## Technical Context

**Language/Version**: TypeScript `7.0.2` (strict mode, ESM `"type": "module"`)

**Primary Dependencies**:
- Build, UI & i18n: `vite@8.3.5`, `@vitejs/plugin-react@6.2.1`, `react@19.3.1`, `react-dom@19.3.1`, `zustand@5.0.16`, `i18next@26.7.1`, `react-i18next@17.1.12`, `tailwindcss@4.3.4`, `@tailwindcss/vite@4.3.4`, `lucide-react@1.67.0`
- AI & Schema Validation: `ollama@0.6.4` (`ollama/browser` entrypoint for `systemone()`), `@langchain/ollama@1.3.0`, `@langchain/core@1.3.4`, `zod@4.6.7`
- Spatial Hex Geometry & Tree Layout: `honeycomb-grid@4.1.5`, `d3-hierarchy@3.1.3` (`@types/d3-hierarchy@3.1.7`)

**Storage**: Client-side persistence via `localStorage` and portable JSON file export/import validated with `zod@4.6.7`.

**Testing**: `vitest@5.1.0` for deterministic unit tests, contract validation tests, and 30-generation scientific preset verification suites.

**Target Platform**: Modern Desktop Web Browser connected to local Ollama server (`http://127.0.0.1:11434`).

**Project Type**: Interactive Web Simulation Application (Single-Project SPA with decoupled pure simulation engine).

**Performance Goals**:
- Biophysical phase resolution + SVG rendering of 61–169 hexagons and inter-hex edge flows: `< 100 ms` per generational turn (`SC-002`).
- Full cognitive turn evaluation for up to 15 active demes with `d3:4b`: `< 3.0 s` per turn (`SC-002`, empirically measured at `~0.85 s`).

**Constraints**:
- Strict adherence to KISS & YAGNI (Principle I): no WebGL scene-graph bloat (`pixi.js` rejected in favor of declarative React SVG + `honeycomb-grid`), no speculative fallback AI engine in production (clean fail-safe pause on Ollama timeout), top-of-file imports only.
- Strict thermodynamic conservation (`SC-005`) enforced on all user-edited and AI-synthesized 6-axis biophysical vectors.

**Scale/Scope**:
- Hexagonal maps of radius $R \in [4, 7]$ ($61\text{--}169$ hex cells), up to 3 cohabiting demes per cell, 3 curated Scientific Presets, 18 base catalog items (7 Decisions, 6 Biological Traits, 5 Cultural Traditions) extensible at runtime.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked and verified after Phase 1 design.*

| Constitution Principle | Pre-Research Check | Post-Design Check | Verification Evidence |
| :--- | :---: | :---: | :--- |
| **I. Radical Simplicity & Zero Defensive Bloat (KISS & YAGNI)** | PASS | PASS | Pure top-to-bottom functions in `src/engine/`, single `zustand` store, declarative SVG rendering without imperative WebGL wrappers, no speculative fallback bloat. |
| **II. Scientific Rigor & Bio-Cultural Fidelity** | PASS | PASS | Explicit mathematical formulas in [simulation-engine.contract.md](./contracts/simulation-engine.contract.md) for $K$ degradation/regeneration, $r/K$ growth, Hawk-Dove, Baldwin assimilation, cultural loss on collapse, and allopatric speciation. |
| **III. Dual-Frequency Cognitive Architecture (`d3` + `gemma4:e4b-it-qat`)** | PASS | PASS | `d3:4b` invoked via `ollama/browser` `systemone()` in the turn loop; `gemma4:e4b-it-qat` invoked via `@langchain/ollama` (`think: false`) strictly on milestones and catalog co-design ([cognitive-engine.contract.md](./contracts/cognitive-engine.contract.md)). |
| **IV. Curated Modern TypeScript Ecosystem** | PASS | PASS | Verified latest stable npm versions in [research.md](./research.md): `typescript@7.0.2`, `ollama@0.6.4`, `@langchain/ollama@1.3.0`, `zod@4.6.7`, `honeycomb-grid@4.1.5`, `d3-hierarchy@3.1.3`. |
| **V. Transparent & Interactive Sandbox UX** | PASS | PASS | Single-view 4-panel layout, 5 visual layers per hex, live `d3` probability bars in Inspector, Selective Pressure Brush, Open Catalog Lab, and 3 Scientific Presets ([ui-store.contract.md](./contracts/ui-store.contract.md)). |

## Project Structure

### Documentation (this feature)

```text
specs/001-evo-population-sim/
├── plan.md                                  # Implementation plan (/speckit-plan)
├── research.md                              # Phase 0 library & empirical Ollama research
├── data-model.md                            # Phase 1 entities, schemas, base catalog & transitions
├── quickstart.md                            # Phase 1 setup & runnable validation scenarios
├── checklists/
│   ├── requirements.md                      # Spec quality checklist (/speckit-specify)
│   ├── scientific-and-ux.md                 # Domain requirements checklist (/speckit-checklist)
│   └── architecture-and-ai.md               # Cognitive & architecture checklist (/speckit-checklist)
├── contracts/
│   ├── cognitive-engine.contract.md         # System 1 (d3) & System 2 (gemma4) contracts
│   ├── simulation-engine.contract.md        # Pure biophysical & preset mathematical contracts
│   └── ui-store.contract.md                 # Single-view UI & Zustand store contracts
└── tasks.md                                 # Phase 2 actionable tasks (/speckit-tasks)
```

### Source Code (repository root)

```text
src/
├── types/
│   └── simulation.ts                        # Core entities, Zod v4 schemas, SupportedLocale, and types
├── i18n/
│   ├── index.ts                             # i18next@26.7.1 + react-i18next@17.1.12 setup (default: "en")
│   └── locales/                             # Complete dictionaries for en, es, zh, fr, de, pt, ja, ru
├── catalog/
│   ├── baseDecisions.ts                     # 7 initial DecisionDefinitions with 6-axis vectors
│   ├── baseTraits.ts                        # 6 Biological Traits & 5 Cultural Traditions
│   └── presets.ts                           # 3 Scientific Presets (Rift, Darwin, Finite Island)
├── engine/
│   ├── hexGrid.ts                           # honeycomb-grid@4.1.5 axial geometry, rings, neighbors
│   ├── thermodynamics.ts                    # 6-axis thermodynamic conservation validator & balancer
│   ├── environmentalPhase.ts                # Phase 1: seasonality, sea-level land bridges, K regen
│   ├── biophysicalPhase.ts                  # Phase 3: extraction, Hawk-Dove, fission, fusion, collapse
│   ├── milestonePhase.ts                    # Phase 4: Baldwin, innovation, allopatric speciation
│   └── turnEngine.ts                        # Complete 4-phase generational orchestrator
├── ai/
│   ├── ollamaSystemOne.ts                   # d3:4b decision scoring via ollama/browser systemone()
│   ├── langchainSystemTwo.ts                # gemma4:e4b-it-qat synthesis via @langchain/ollama
│   └── cognitiveProvider.ts                 # Live & Deterministic Mock providers + health check
├── store/
│   ├── persistence.ts                       # JSON export/import and localStorage persistence
│   └── useSimulationStore.ts                # Zustand store, playback loop & selective pressure actions
├── components/
│   ├── TopControlBar.tsx                    # Presets, turn playback controls, season/sea indicators
│   ├── HexMapCanvas.tsx                     # Interactive SVG hex grid with 5 visual layers & flows
│   ├── SelectivePressureToolbar.tsx         # Biome, altitude, K & sea-level brushes + budget
│   ├── CognitiveInspectorPanel.tsx          # Live d3 probability bars, energy delta & trait injector
│   ├── CatalogLabModal.tsx                  # Trait/Decision editor with sliders & AI co-design
│   ├── PhyloCulturalTreeModal.tsx           # d3-hierarchy lineage tree visualization
│   ├── NaturalistNotebookModal.tsx          # Causal chronicle feed & milestone cards
│   └── OllamaDiagnosticsModal.tsx           # Connection status, pull commands & retry control
├── App.tsx                                  # Single-view integrated layout container
├── main.tsx                                 # Application entrypoint
└── index.css                                # Tailwind CSS v4 (@import "tailwindcss";)

tests/
├── unit/
│   ├── thermodynamics.test.ts               # Tests SC-005 6-axis thermodynamic inequality
│   ├── hexGrid.test.ts                      # Tests honeycomb-grid neighbors, spiral & passability
│   ├── biophysicalPhase.test.ts             # Tests fission, Jaccard fusion, Hawk-Dove & cultural loss
│   └── i18n.test.ts                         # Tests default "en" locale & 100% key parity across 8 locales (SC-006)
├── contract/
│   └── cognitiveSchemas.test.ts             # Tests System 1 normalization & System 2 Zod schemas
└── integration/
    └── scientificPresets.test.ts            # Tests 30-generation emergence across all 3 Presets (SC-001)
```

**Structure Decision**: Single-project TypeScript web application (`src/` and `tests/` at repository root) with strict architectural separation between pure simulation logic (`src/engine/`, `src/catalog/`), AI orchestration (`src/ai/`), reactive state (`src/store/`), and declarative UI views (`src/components/`).

## Complexity Tracking

No Constitution violations exist. All 5 Core Principles pass without exception.
