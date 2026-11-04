---
description: "Actionable, dependency-ordered task list for Evolution Population Simulator (001-evo-population-sim)"
---

# Tasks: Simulador Evolutivo y Socio-Cultural de Poblaciones (Evolution)

**Input**: Design documents from `/specs/001-evo-population-sim/`
**Prerequisites**: `plan.md` (required), `spec.md` (required for user stories), `research.md`, `data-model.md`, `contracts/`
**Tests**: Included to enforce the Constitution's *Deterministic Core Testability* mandate and verify `SC-001`..`SC-005`.
**Organization**: Tasks are grouped by user story (`US1`..`US4`) to enable independent implementation and verification of each increment.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks)
- **[Story]**: Which user story this task belongs to (`[US1]`, `[US2]`, `[US3]`, `[US4]`)
- Exact file paths and verbatim constraints from `data-model.md` are included in descriptions

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Initialize strict TypeScript ESM project, Vite 8 + React 19 + Tailwind CSS v4 bundler, and Vitest 5 test runner.

- [X] T001 Create project directory structure (`src/types/`, `src/i18n/locales/`, `src/catalog/`, `src/engine/`, `src/ai/`, `src/store/`, `src/components/`, `tests/unit/`, `tests/contract/`, `tests/integration/`) per `specs/001-evo-population-sim/plan.md`
- [X] T002 Initialize `package.json` with `"type": "module"` and exact verified dependencies (`typescript@7.0.2`, `vite@8.3.5`, `@vitejs/plugin-react@6.2.1`, `vitest@5.1.0`, `zod@4.6.7`, `ollama@0.6.4`, `@langchain/ollama@1.3.0`, `@langchain/core@1.3.4`, `honeycomb-grid@4.1.5`, `d3-hierarchy@3.1.3`, `@types/d3-hierarchy@3.1.7`, `react@19.3.1`, `react-dom@19.3.1`, `@types/react@19.3.0`, `@types/react-dom@19.3.0`, `zustand@5.0.16`, `i18next@26.7.1`, `react-i18next@17.1.12`, `tailwindcss@4.3.4`, `@tailwindcss/vite@4.3.4`, `lucide-react@1.67.0`) in `package.json`
- [X] T003 [P] Configure strict TypeScript compiler options (`strict: true`, `noUncheckedIndexedAccess: true`, `moduleResolution: "bundler"`, `target: "ES2023"`) in `tsconfig.json`
- [X] T004 [P] Configure Vite 8 with `@vitejs/plugin-react`, `@tailwindcss/vite`, and Vitest test environment in `vite.config.ts`
- [X] T005 [P] Create HTML shell and Tailwind CSS v4 entrypoint (`@import "tailwindcss";`) in `index.html` and `src/index.css`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core entity schemas, thermodynamic conservation validator, axial hex-grid math, and base catalog definitions required by all user stories.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [X] T006 Define core TypeScript interfaces and `zod@4.6.7` schemas in `src/types/simulation.ts` enforcing verbatim `data-model.md` constraints:
  - `BiophysicalVector`: `metabolicCost` (`[-1.0, 1.0]`), `extractionEfficiency` (`[-1.0, 1.0]`), `ecologicalImpact` (`[-1.0, 1.0]`), `spatialMobility` (`[-1.0, 1.0]`), `socialCohesion` (`[-1.0, 1.0]`), `transmissionThreshold` (`[0.0, 1.0]`)
  - `TraitDefinition`: `id` (`^[a-z0-9-]+$`), `name` (`1..60` chars), `category` (`'biological' | 'cultural'`), `semanticDescriptor` (`10..300` chars), `affinityCondition` (`5..200` chars), `mutuallyExclusiveWith` (`string[]`), `enablesCulturalTransmission` (`boolean`), `biophysicalVector`, `origin` (`'base' | 'user' | 'emergent'`), `freeSandboxMode` (`boolean`)
  - `DecisionDefinition`: `id` (`^[a-z0-9-]+$`), `name` (`1..60` chars), `archetype` (`'forage' | 'overexploit' | 'migrate' | 'cooperate' | 'exchange' | 'dispute' | 'innovate' | 'custom'`), `semanticDescriptor` (`10..300` chars), `requiredTraitIds` (`string[]`), `biophysicalVector`, `origin` (`'base' | 'user'`), `freeSandboxMode` (`boolean`)
  - `HexCell`: `id` (`"${q},${r}"`), `q` and `r` (integers in `[-R, R]`), `biome` (`'tropical_forest' | 'savanna' | 'arid_steppe' | 'tundra' | 'high_mountain' | 'coastal_shallows' | 'ocean'`), `temperature` (`[-1.0, 1.0]`), `humidity` (`[0.0, 1.0]`), `altitude` (`[0.0, 1.0]`), `currentResources` (`[0, carryingCapacityMax * 1.5]`), `carryingCapacity` (`[10, carryingCapacityMax]`), `carryingCapacityMax` (`[50, 2000]`), `seasonalRegenRate` (`[0.02, 0.50]`), `demeIds` (length `0..3`)
  - `Deme`: `id`, `name` (`1..60` chars), `lineageId`, `color` (`^#[0-9A-Fa-f]{6}$`), `hexId`, `population` (integer `>= 10`), `energyReserves` (`>= 0`), `lastEnergyDelta`, `biologicalTraitIds`, `culturalTraitIds`, `baldwinCounters` (`Record<string, number>` integers `>= 0`), `innovationCounter` (`[0.0, 2.0]`), `isolationTurns` (integer `>= 0`), `lastDecisionProbabilities` (`sum(P_i) = 1.0`, each `P_i in [0, 1]`), `lastDominantDecisionId`, `lastJustification` (non-empty string)
  - `SupportedLocale` (`'en' | 'es' | 'zh' | 'fr' | 'de' | 'pt' | 'ja' | 'ru'`, default `'en'`), `LineageNode`, `ChronicleEntry`, `HexEdgeFlow`, `PresetScenario` (`id`, `name`, `description`, `scientificHypothesis`, `glacialSeaLevelCycle`, `createInitialWorld`), and `WorldState` (`season: 'wet_warm' | 'dry_cold'`, `seaLevel: [0.0, 0.50]`, `mapRadius: 4..7`)
- [X] T007 [P] Implement `validateAndBalanceThermodynamics(vector, freeSandboxMode)` in `src/engine/thermodynamics.ts` enforcing `positiveAdvantages = max(0, extractionEfficiency) + max(0, spatialMobility) + max(0, socialCohesion)` and `metabolicCost - min(0, ecologicalImpact) >= 0.50 * (positiveAdvantages - 0.60)` when `freeSandboxMode === false` (`FR-007`, `SC-005`)
- [X] T008 [P] Write unit tests for 6-axis thermodynamic validation and auto-compensation in `tests/unit/thermodynamics.test.ts`
- [X] T009 [P] Implement hexagonal grid geometry helpers using `honeycomb-grid@4.1.5` (`Orientation.POINTY`, `spiral({ start: [0, 0], radius })`, `ring({ center: [q, r], radius: 1 })` for 6 equidistant neighbors, `corners` polygon vertices, and passability checks) in `src/engine/hexGrid.ts` (`FR-001`)
- [X] T010 [P] Write unit tests for axial hex creation (`R=4 -> 61 cells`, `R=5 -> 91 cells`), 6-neighbor equidistance, and mountain/ocean passability in `tests/unit/hexGrid.test.ts`
- [X] T011 [P] Populate the 7 base `DecisionDefinition` items (`dec-conservative-forage`, `dec-intensive-overexploit`, `dec-selective-migration`, `dec-cooperate-store`, `dec-exchange-symbiosis`, `dec-territorial-dispute`, `dec-explore-innovate`) with exact 6-axis vectors in `src/catalog/baseDecisions.ts` (`FR-008`)
- [X] T012 [P] Populate the 6 base biological `TraitDefinition` items (`bio-r-strategy`, `bio-k-strategy` mutually exclusive, `bio-digestive-spec`, `bio-thermal-tolerance`, `bio-encephalization`, `bio-social-instinct`) and 5 base cultural `TraitDefinition` items (`cul-fire-processing`, `cul-extraction-tools`, `cul-communal-conservation`, `cul-interdeme-barter`, `cul-warrior-expansion`) with canonical English (`en`) descriptors in `src/catalog/baseTraits.ts` (`FR-008`, `FR-015`)
- [X] T013 [P] Configure `i18next@26.7.1` and `react-i18next@17.1.12` with `lng: "en"` and `fallbackLng: "en"` in `src/i18n/index.ts`, create complete translation dictionaries for all 8 supported world languages (`en`, `es`, `zh`, `fr`, `de`, `pt`, `ja`, `ru`) in `src/i18n/locales/{en,es,zh,fr,de,pt,ja,ru}.json` covering all UI strings, biomes, presets, and the 18 base catalog items, and verify 100% key parity and default `'en'` initialization in `tests/unit/i18n.test.ts` (`FR-015`, `SC-006`)

**Checkpoint**: Foundational types, thermodynamic laws, hex geometry, base catalog, and 8-language i18n setup (default `en`) are ready and unit-tested.

---

## Phase 3: User Story 1 - Simulación Generacional sobre Rejilla Hexagonal con Presets Científicos (Priority: P1) 🎯 MVP

**Goal**: Deliver the complete 4-phase generational turn simulation over a hexagonal grid with the 3 Scientific Presets, System 1 (`d3:4b`) probabilistic decision scoring, biophysical resolution, demographic fission/fusion, playback controls, live i18n switcher (default `en`), and JSON/`localStorage` persistence.

**Independent Test**: Load any of the 3 Scientific Presets (starting in English `en` by default), advance 20–30 generations in step or auto-play mode, verify that all 5 hex visual layers update in `< 100 ms`, decision probabilities sum to `1.0`, preset phenomena (`SC-001`) emerge deterministically, language switching across `en, es, zh, fr, de, pt, ja, ru` updates all labels instantly (`SC-006`), and world state exports/imports cleanly.

### Tests for User Story 1

- [X] T014 [P] [US1] Write unit tests for Phase 1 (seasonality, sea-level land-bridge submergence/emergence, $K$ regeneration) and Phase 3 (energy extraction, Hawk-Dove matrix, Tragedy of the Commons $K$ degradation, migrant fission $\ge 10$, Jaccard fusion $< 0.10$, cultural bottleneck loss $\ge 50\%$ or $< 50$ pop, extinction $< 10$ pop) in `tests/unit/biophysicalPhase.test.ts`
- [X] T015 [P] [US1] Write contract tests for System 1 (`d3:4b`) probability normalization ($\sum P_i = 1.0$) and timeout fail-safe handling in `tests/contract/cognitiveSchemas.test.ts`
- [X] T016 [P] [US1] Write 30-generation integration verification tests for all 3 Scientific Presets (`preset-rift-savanna`, `preset-darwin-archipelago`, `preset-finite-island`) verifying `SC-001` and `< 100 ms` turn execution (`SC-002`) in `tests/integration/scientificPresets.test.ts`

### Implementation for User Story 1

- [X] T017 [P] [US1] Implement Phase 1 environmental update (`runEnvironmentalPhase`: seasonal alternation `'wet_warm' | 'dry_cold'`, glacial sea-level land bridges, forced displacement on cell submergence, and $K$ / biomass regeneration) in `src/engine/environmentalPhase.ts` (`FR-002`, `FR-004`)
- [X] T018 [P] [US1] Implement Phase 3 biophysical and demographic resolution (`resolveBiophysicalAndDemographicPhase`, `computeDemeDivergence`: 6-axis effective vector calculation, Hawk-Hawk / Hawk-Dove / Symbiosis game theory, horizontal cultural diffusion, Tragedy of the Commons $K$ decay, $r/K$ growth, migrant fission $\ge 10$ with trait inheritance and counter reset, Jaccard $< 0.10$ same-lineage fusion, cultural loss on $\ge 50\%$ drop or `< 50` pop, and extinction `< 10` pop) in `src/engine/biophysicalPhase.ts` (`FR-003`, `FR-004`, `FR-009`)
- [X] T019 [P] [US1] Implement the 3 calibrated `PresetScenario` builders (`preset-rift-savanna` $R=5$, `preset-darwin-archipelago` $R=5$ with `coastal_shallows` land bridges, `preset-finite-island` $R=4$) in `src/catalog/presets.ts` (`FR-014`, `SC-001`)
- [X] T020 [US1] Implement System 1 `d3:4b` client using `import { Ollama } from "ollama/browser"` and `ollamaClient.systemone()` with `5000 ms` timeout, probability normalization ($\sum P_i = 1.0$), and localized contextual justification builder (`locale`, default `"en"`) in `src/ai/ollamaSystemOne.ts` (`FR-006`, `FR-015`, `SC-002`, `SC-003`)
- [X] T021 [US1] Implement `CognitiveProvider` facade (connecting `ollamaSystemOne`, `checkStatus()` via `ollamaClient.list()`, and deterministic `MockCognitiveProvider` for automated testing) in `src/ai/cognitiveProvider.ts` (`FR-006`)
- [X] T022 [US1] Implement the 4-phase generational orchestrator (`executeGenerationalTurn`) in `src/engine/turnEngine.ts` (`FR-004`)
- [X] T023 [P] [US1] Implement portable JSON export/import (`zod` schema validation) and automatic `localStorage` session and locale persistence in `src/store/persistence.ts` (`FR-014`, `FR-015`)
- [X] T024 [US1] Implement core `useSimulationStore` in `src/store/useSimulationStore.ts` managing `locale` (default `"en"`), `setLocale`, `WorldState`, preset loading, `stepGeneration()`, `Auto-Play` loop (`playing_normal` at `1500 ms`, `playing_fast` at `300 ms`), clean fail-safe pause on Ollama error (`error_paused`), and JSON import/export (`FR-004`, `FR-005`, `FR-014`, `FR-015`)
- [X] T025 [P] [US1] Create `HexMapCanvas.tsx` in `src/components/HexMapCanvas.tsx` rendering the interactive SVG hexagonal grid with all 5 visual layers: (1) biome/altitude polygon, (2) resource badge, (3) $K / K_{\max}$ ecological health ring, (4) up to 3 deme population clusters, and (5) animated directional edge vectors for `migration`, `exchange`, and `dispute` (`FR-001`, `SC-002`)
- [X] T026 [P] [US1] Create `TopControlBar.tsx` in `src/components/TopControlBar.tsx` with preset selector, live language selector (`en` default, `es`, `zh`, `fr`, `de`, `pt`, `ja`, `ru`), generation/season/sea-level badges, playback controls (`Pause`, `Step +1 Gen`, `Auto-Play Normal`, `Auto-Play Fast`), `Auto-Pause on Milestones` toggle, and JSON Export/Import buttons (`FR-005`, `FR-010`, `FR-014`, `FR-015`)
- [X] T027 [P] [US1] Create `OllamaDiagnosticsModal.tsx` in `src/components/OllamaDiagnosticsModal.tsx` displaying localized connection health, `ollama pull d3:4b` / `ollama pull gemma4:e4b-it-qat` setup commands, and `Retry Turn` button (`Edge Case 2`, `FR-015`)

**Checkpoint**: User Story 1 (MVP) is complete and independently verifiable via both `vitest` and the interactive hexagonal web UI.

---

## Phase 4: User Story 2 - Intervención Ambiental (Pincel de Presión Selectiva) e Inspector Cognitivo en Vivo (Priority: P2)

**Goal**: Empower the player as the Selective Pressure with a live Cognitive Inspector Panel showing `d3` probability distributions and energy breakdowns, plus environmental brush tools regulated by regenerating Selective Pressure Points.

**Independent Test**: Select a deme on the hex map to inspect its live `d3` probability bars and energy delta, paint a mountain barrier or arid savanna across hexagons using the Selective Pressure Brush, advance 1 generation, and verify the updated environmental properties and shifted `d3` probabilities.

- [X] T028 [P] [US2] Implement selective pressure brush actions (`setActiveBrush`, `applyBrushToHex` supporting `set_biome`, `adjust_altitude`, `adjust_carrying_capacity` with radius `1 | 2` via `honeycomb-grid` `spiral`, and `adjust_sea_level`, pressure point deduction, per-turn point regeneration, and `toggleUnlimitedPressure`) in `src/store/useSimulationStore.ts` (`FR-011`)
- [X] T029 [P] [US2] Create `CognitiveInspectorPanel.tsx` in `src/components/CognitiveInspectorPanel.tsx` displaying localized hex properties (`q, r`, biome, $T$, humidity, altitude, $R$, $K / K_{\max}$), deme selector, demographic/caloric metrics ($\Delta E$, Baldwin/innovation/isolation counters), sorted horizontal `d3` probability bars summing to `100%`, contextual justification text, and active biological/cultural traits (`FR-010`, `FR-015`, `SC-003`)
- [X] T030 [P] [US2] Create `SelectivePressureToolbar.tsx` in `src/components/SelectivePressureToolbar.tsx` providing localized brush selectors (`Inspect`, `Biome/Climate`, `Altitude +/-`, `Carrying Capacity K +/-`, `Global Sea Level`), brush radius selector (`1 | 2`), available `selectivePressurePoints` counter, and `Unlimited Budget` toggle (`FR-010`, `FR-011`, `FR-015`)

**Checkpoint**: User Stories 1 and 2 work seamlessly in the single-view layout.

---

## Phase 5: User Story 3 - Editor Abierto del Catálogo de Rasgos y Decisiones con Asistente de Co-Diseño (Priority: P3)

**Goal**: Provide the Open Catalog Laboratory modal where players can edit or create Biological Traits, Cultural Traditions, and Behavioral Decisions manually (with 6-axis sliders and thermodynamic validation) or via natural-language co-design powered by `gemma4:e4b-it-qat` in the active `locale` (default `en`), and experimentally inject traits into a selected deme.

**Independent Test**: Open the Catalog Laboratory, enter a natural-language concept to generate a balanced 6-axis trait or decision via `gemma4:e4b-it-qat` in the active language, save it to the catalog, inject it into a deme, advance 1 generation, and verify its inclusion in `d3` scoring and biophysical resolution.

- [X] T031 [P] [US3] Implement `coDesignCatalogItem` in `src/ai/langchainSystemTwo.ts` using `ChatOllama` (`@langchain/ollama@1.3.0`, `model: "gemma4:e4b-it-qat"`, `think: false`, `timeout: 15000`), passing `input.locale` (default `"en"`) in the prompt instructions, and `.withStructuredOutput(UserCoDesignOutputSchema, { method: "jsonSchema" })` post-processed by `validateAndBalanceThermodynamics` (`FR-012`, `FR-015`, `SC-004`, `SC-005`)
- [X] T032 [P] [US3] Add contract test for `UserCoDesignOutputSchema` and thermodynamic auto-balancing in `tests/contract/cognitiveSchemas.test.ts` (`SC-004`, `SC-005`)
- [X] T033 [US3] Implement catalog mutation and experimental injection actions (`upsertTrait`, `upsertDecision`, `injectTraitIntoDeme` respecting `mutuallyExclusiveWith` and `enablesCulturalTransmission`) in `src/store/useSimulationStore.ts` (`FR-007`, `FR-008`, `FR-012`)
- [X] T034 [US3] Create `CatalogLabModal.tsx` in `src/components/CatalogLabModal.tsx` with localized tabs for Biological Traits, Cultural Traditions, and Decisions, 6-axis biophysical sliders (`metabolicCost`, `extractionEfficiency`, `ecologicalImpact`, `spatialMobility`, `socialCohesion`, `transmissionThreshold`), real-time thermodynamic budget indicator, `Free Sandbox Mode` override checkbox, natural-language AI co-design input, and `+ Inject into Deme` action (`FR-007`, `FR-012`, `FR-015`, `SC-004`, `SC-005`)

**Checkpoint**: User Stories 1, 2, and 3 are complete and independently functional.

---

## Phase 6: User Story 4 - Emergencia Autónoma de Hitos Evolutivos/Culturales y Cuaderno del Naturalista (Priority: P4)

**Goal**: Enable open-ended evolution in Phase 4 (`Baldwin assimilation` at $N=8$ gens, `Cultural Innovation` at $\ge 1.0$, and `Allopatric Speciation` at $M=10$ isolated gens) synthesized by `gemma4:e4b-it-qat` in the active `locale` (default `en`), with automatic milestone pause, the Naturalist Notebook chronicle feed, and the interactive `d3-hierarchy` Phylo-Cultural Tree.

**Independent Test**: Run a deme until it crosses the Baldwin ($N=8$), Innovation ($\ge 1.0$), or Isolation ($M=10$) threshold; verify that auto-play pauses when `Auto-Pause on Milestones` is active, a new emergent trait/tradition or species node is synthesized in the active language, the Naturalist Notebook logs the causal chronicle, and clicking the node in the Phylo-Cultural Tree highlights its living demes on the hex map.

- [X] T035 [P] [US4] Implement deterministic Phase 4 milestone detection and application (`detectEvolutionaryMilestones` for `baldwinCounters[i] >= 8` with $P_i \ge 0.35$, `innovationCounter >= 1.0` with `enablesCulturalTransmission`, and `isolationTurns >= 10` with divergence $\ge 0.30$; and `applySynthesizedMilestone`) in `src/engine/milestonePhase.ts` (`FR-013`)
- [X] T036 [P] [US4] Implement `synthesizeMilestone` in `src/ai/langchainSystemTwo.ts` using `ChatOllama` (`model: "gemma4:e4b-it-qat"`, `think: false`), instructing the model to generate `name`, `semanticDescriptor`, `affinityCondition`, `chronicleTitle`, and `chronicleBody` in `input.locale` (default `"en"`), and `.withStructuredOutput(SynthesizedTraitProposalSchema, { method: "jsonSchema" })` post-processed by `validateAndBalanceThermodynamics` (`FR-013`, `FR-015`, `SC-005`)
- [X] T037 [P] [US4] Write unit and contract tests for Phase 4 threshold detection (`N=8`, `>= 1.0`, `M=10`) and `SynthesizedTraitProposalSchema` validation in `tests/unit/biophysicalPhase.test.ts` and `tests/contract/cognitiveSchemas.test.ts` (`FR-013`)
- [X] T038 [US4] Wire Phase 4 milestone synthesis and `autoPauseOnMilestone` transition (`playbackMode = "milestone_paused"`) into `src/engine/turnEngine.ts` and `src/store/useSimulationStore.ts` (`FR-005`, `FR-013`)
- [X] T039 [P] [US4] Create `PhyloCulturalTreeModal.tsx` in `src/components/PhyloCulturalTreeModal.tsx` using `d3-hierarchy@3.1.3` (`stratify` and `tree`) to render the interactive SVG genealogy of `LineageNode` items, acquired traits, divergence reasons, and click-to-highlight lineage filtering on the hex map (`FR-010`, `FR-013`, `FR-015`)
- [X] T040 [P] [US4] Create `NaturalistNotebookModal.tsx` in `src/components/NaturalistNotebookModal.tsx` displaying the localized chronological feed of `ChronicleEntry` cards (Baldwin assimilations, cultural innovations, allopatric speciations, cultural bottlenecks, and extinctions) and the milestone alert banner (`FR-010`, `FR-013`, `FR-015`)

**Checkpoint**: All 4 User Stories are complete and integrated.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Final integration of the single-view layout (`App.tsx`), i18n initialization in `main.tsx`, end-to-end validation against `quickstart.md`, and strict compliance check.

- [X] T041 Assemble the complete single-view 4-panel workspace (`TopControlBar`, `HexMapCanvas`, `CognitiveInspectorPanel`, `SelectivePressureToolbar`, and modals `CatalogLabModal`, `PhyloCulturalTreeModal`, `NaturalistNotebookModal`, `OllamaDiagnosticsModal`) and initialize `src/i18n/index.ts` in `src/App.tsx` and `src/main.tsx` (`FR-010`, `FR-015`)
- [X] T042 Run full validation suite (`npm test` and `npm run typecheck`) verifying all unit (including 8-locale `i18n.test.ts`), contract, and 30-generation preset integration tests pass per `specs/001-evo-population-sim/quickstart.md`

---

## Phase 8: Convergence

- [X] T043 [US1] Set `autoPauseOnMilestone: false` by default across all 3 scientific presets in `src/catalog/presets.ts` and extend `ChronicleEntryTypeSchema` (`'single_survivor' | 'ecological_equilibrium'`) and `WorldStateSchema` (`quietTurns?: number`) in `src/types/simulation.ts` per `FR-005` (`contradicts`)
- [X] T044 [US1] Enforce minimum 1-individual decline on net caloric deficit (`effectiveDeltaE < 0`) and prevent redundant migration-fusion ping-pong into hexes already hosting a `< 0.10` divergent same-lineage deme in `src/engine/biophysicalPhase.ts` per `FR-004` (`partial`)
- [X] T045 [US4] Cap emergent trait synthesis at `< 3` per category per deme and implement `evaluateMacroEvolutionaryOutcome` (`single_survivor` and `ecological_equilibrium` after `quietTurns >= 8` at `generation >= 30`) in `src/engine/milestonePhase.ts` and `src/engine/turnEngine.ts` per `FR-005` and `FR-013` (`missing`)
- [X] T046 [P] [US4] Update `stepGeneration` in `src/store/useSimulationStore.ts` and localized chronicle type labels in `src/i18n/locales/{en,es,zh,fr,de,pt,ja,ru}.json` so `Auto-Play` runs continuously across milestones by default and pauses automatically on `total_extinction`, `single_survivor`, or `ecological_equilibrium` per `FR-005` and `FR-015` (`partial`)
- [X] T047 [US1] Add unit and integration tests verifying `autoPauseOnMilestone === false` default, continuous `Auto-Play` through milestones, and automatic stop on `total_extinction`, `single_survivor`, and `ecological_equilibrium` in `tests/unit/biophysicalPhase.test.ts` and `tests/integration/scientificPresets.test.ts` per `FR-005` (`missing`)

---

## Dependencies & Execution Order

### Phase Dependencies

1. **Phase 1 (Setup)**: `T001`..`T005` — No dependencies; starts immediately.
2. **Phase 2 (Foundational)**: `T006`..`T013` — Depends on Phase 1; blocks all User Stories.
3. **Phase 3 (US1 - MVP)**: `T014`..`T027` — Depends on Phase 2.
4. **Phase 4 (US2 - Inspector & Brush)**: `T028`..`T030` — Depends on Phase 2 and integrates with US1 store/map.
5. **Phase 5 (US3 - Catalog Lab & Co-Design)**: `T031`..`T034` — Depends on Phase 2 and integrates with US1 store.
6. **Phase 6 (US4 - Milestones, Notebook & Phylo Tree)**: `T035`..`T040` — Depends on Phase 2 and integrates with US1 turn engine.
7. **Phase 7 (Polish & Validation)**: `T041`..`T042` — Depends on Phases 3–6.

### Parallel Opportunities

- Within Phase 2: `T007` (`thermodynamics.ts`), `T009` (`hexGrid.ts`), `T011` (`baseDecisions.ts`), `T012` (`baseTraits.ts`), and `T013` (`src/i18n/`) operate on independent files and can execute in parallel after `T006` (`simulation.ts`).
- Within Phase 3 (US1): Engine modules (`T017`, `T018`, `T019`), AI client (`T020`), persistence (`T023`), and UI components (`T025`, `T026`, `T027`) can be developed in parallel.
- Across User Stories: Once Phase 3 store/engine core is in place, UI panels and AI extensions in Phases 4, 5, and 6 (`CognitiveInspectorPanel.tsx`, `SelectivePressureToolbar.tsx`, `CatalogLabModal.tsx`, `PhyloCulturalTreeModal.tsx`, `NaturalistNotebookModal.tsx`) can be built in parallel.

---

## Parallel Example: User Story 1

```bash
# Run independent engine & preset implementations in parallel:
Task T017: "Implement Phase 1 environmental update in src/engine/environmentalPhase.ts"
Task T018: "Implement Phase 3 biophysical and demographic resolution in src/engine/biophysicalPhase.ts"
Task T019: "Implement the 3 calibrated PresetScenario builders in src/catalog/presets.ts"

# Run independent UI components in parallel:
Task T025: "Create HexMapCanvas.tsx in src/components/HexMapCanvas.tsx"
Task T026: "Create TopControlBar.tsx in src/components/TopControlBar.tsx"
Task T027: "Create OllamaDiagnosticsModal.tsx in src/components/OllamaDiagnosticsModal.tsx"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1 (Setup) + Phase 2 (Foundational).
2. Complete Phase 3 (User Story 1: Hex Grid + 4-Phase Turn Loop + `d3:4b` System 1 + 3 Scientific Presets + Playback & Persistence).
3. Validate deterministic 30-generation preset tests (`SC-001`) and `< 100 ms` turn resolution (`SC-002`).

### Incremental Delivery

1. Add Phase 4 (User Story 2): Live Cognitive Inspector + Selective Pressure Brush.
2. Add Phase 5 (User Story 3): Open Catalog Laboratory + `gemma4:e4b-it-qat` Co-Design Assistant.
3. Add Phase 6 (User Story 4): Phase 4 Evolutionary Milestones + Naturalist Notebook + `d3-hierarchy` Phylo-Cultural Tree.
4. Complete Phase 7: Full workspace assembly and end-to-end quickstart verification.
