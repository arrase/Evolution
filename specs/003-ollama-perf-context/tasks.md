---
description: "Actionable, dependency-ordered task list for 003-ollama-perf-context"
---

# Tasks: Optimización de Velocidad por Turno y Enriquecimiento del Contexto Cognitivo de Decisión

**Input**: Design documents from `/specs/003-ollama-perf-context/` (`plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/cognitive-context-and-pacing.contract.md`, `quickstart.md`)

**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/cognitive-context-and-pacing.contract.md`

**Organization**: Tasks are grouped by user story (`US1`, `US2`, `US3`) to enable independent implementation, verification, and incremental delivery.

## Format: `[ID] [P?] [Story?] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks)
- **[Story]**: User story label (`[US1]`, `[US2]`, `[US3]`) for user story phases only
- Every task includes exact repository-relative file paths

---

## Phase 1: Setup (Baseline Verification)

**Purpose**: Verify baseline TypeScript compilation and deterministic test suite before applying cognitive and demographic optimizations

- [X] T001 Verify baseline TypeScript build and test suite via `package.json` scripts (`npm run typecheck && npm test`)

---

## Phase 2: Foundational (Shared Enriched Cognitive & Milestone Types)

**Purpose**: Extend shared domain interfaces in `src/types/simulation.ts` so all downstream User Stories (`US1`, `US2`, `US3`) have strongly-typed access to enriched demographic, ecological, and causal context fields while preserving backward compatibility

**⚠️ CRITICAL**: Must complete before User Story phases begin

- [X] T002 Extend `DemeDecisionEvaluationInput` and `MilestoneSynthesisInput` in `src/types/simulation.ts` with optional enriched context fields (`lastDominantDecisionId?: string`, `baldwinProgress?: number` in `0..8`, `innovationProgress?: number` in `0.0..2.0`, `biophysicalVector?: BiophysicalVector` on traits and eligible decisions, `archetype?: DecisionArchetype` on eligible decisions, `totalCellPopulation?: number`, `rivalDemesCount?: number`, `kinDemesCount?: number`, neighbor `totalPopulation?: number`, and milestone `season?: SeasonType`, `energyReserves?: number`, `lastEnergyDelta?: number`, `currentResources?: number`, `carryingCapacity?: number`, `carryingCapacityMax?: number`, `globalEmergentTraitNames?: string[]`, `recentChronicleTitles?: string[]`)

**Checkpoint**: Shared TypeScript contracts ready for `US1`, `US2`, and `US3`

---

## Phase 3: User Story 1 - Cadencia de Turno Estable y Fluida en Simulaciones Avanzadas (Priority: P1) 🎯 MVP

**Goal**: Prevent exponential micro-deme proliferation on low migration probabilities, consolidate compatible same-lineage subpopulations (`< 0.25` divergence), deduplicate equivalent System 1 evaluations within each turn via `computeDemeEvaluationSignature`, cap System 2 milestone synthesis to at most 1 per turn, and speed up per-turn `localStorage` persistence (`FR-003`, `FR-004`, `FR-005`, `FR-007`, `SC-002`, `SC-003`).

**Independent Test**: Run a 30-generation simulation across all 3 scientific presets and verify that stationary demes (`pMigrate < 0.15` and non-emergency resources outside land bridges) do not spawn daughter demes every turn, same-lineage demes with `< 0.25` divergence consolidate, equivalent demes in the same turn share a single `evaluateDemeDecisions` call while retaining deme-specific justifications, and `executeGenerationalTurn` executes at most 1 prioritized `synthesizeMilestone` call per turn.

### Implementation for User Story 1

- [X] T003 [P] [US1] Implement `computeDemeEvaluationSignature(input: DemeDecisionEvaluationInput): string` and reusable `Ollama` client caching per host in `src/ai/ollamaSystemOne.ts` (`season`, `biome`, `adequacyTier` bucketed by `Math.min(6, Math.floor(resourceAdequacyRatio * 2))`, `healthTier` bucketed by `Math.floor((carryingCapacity / carryingCapacityMax) * 4)`, `vitality`, `competitionKey`, sorted `traitsKey`, `dominantKey`, and top 2 passable `neighborKey`)
- [X] T004 [P] [US1] Implement intentional migratory fission gating (`pMigrate >= 0.15` or `deme.lastDominantDecisionId === "dec-selective-migration"` or `currentCell.biome === "coastal_shallows"` or emergency `currentCell.currentResources < deme.population * 0.20`, alongside `migrants >= 10` and `deme.population - migrants >= 10`) and relax same-lineage cohabitation merging and neighbor colonization blocking to `computeDemeDivergence(demeA, demeB) < 0.25` in `src/engine/biophysicalPhase.ts`
- [X] T005 [P] [US1] Add deterministic milestone priority helper (`allopatric_speciation` > `baldwin_assimilation` > `cultural_innovation`) in `src/engine/milestonePhase.ts` while preserving `detectEvolutionaryMilestones` full-candidate return contract for existing unit tests
- [X] T006 [P] [US1] Optimize `saveWorldToLocalStorage` in `src/store/persistence.ts` to serialize `JSON.stringify(world)` directly during turn updates while preserving `WorldStateSchema.parse` in `serializeWorldState` and `deserializeWorldState`
- [X] T007 [US1] Update `executeGenerationalTurn` in `src/engine/turnEngine.ts` to deduplicate System 1 calls within a turn using `computeDemeEvaluationSignature` (cloning cached `probabilities` and rebuilding each deme's localized justification via `buildContextualJustification(evaluationInput, cached.dominantDecisionId, cached.probabilities[cached.dominantDecisionId]!, cached.confidence)`) and sort/deduplicate detected milestones by priority to process at most `.slice(0, 1)` synthesis per turn
- [X] T008 [US1] Add unit and integration tests for intentional migratory fission gating, `< 0.25` intra-lineage consolidation, 1-milestone-per-turn pacing, and intra-turn evaluation deduplication in `tests/unit/biophysicalPhase.test.ts` and `tests/integration/scientificPresets.test.ts`

**Checkpoint**: User Story 1 is independently functional and verified (`FR-003`, `FR-004`, `FR-005`, `FR-007`, `SC-002`)

---

## Phase 4: User Story 2 - Contexto Ecológico, Energético y Competitivo Rico para Decisiones Coherentes (Priority: P1)

**Goal**: Build a compact, high-signal System 1 representation (`buildCompactSystemOneState` and `buildCompactDecisionCriteria`) that cuts input tokens by `>= 35%` while exposing caloric adequacy (`currentResources / Math.max(10, totalCellPopulation * 0.48)`), vital status, habitat health ($K / K_{\max}$), cohabiting rival vs. kin populations, trait and decision biophysical vectors, behavioral momentum (`lastDominantDecisionId` & Baldwin/Innovation counters), and top passable neighbor escape routes (`FR-001`, `FR-002`, `SC-001`, `SC-004`).

**Independent Test**: Verify via contract tests in `tests/contract/cognitiveSchemas.test.ts` that `buildCompactSystemOneState` reduces serialized prompt character/token length by `>= 35%` compared to the raw JSON input, includes all required ecological/competitive/biophysical signals, and produces distinct, hypothesis-aligned decision distributions across the 3 scientific preset archetypes.

### Implementation for User Story 2

- [X] T009 [US2] Populate enriched `DemeDecisionEvaluationInput` fields (`lastDominantDecisionId`, `baldwinProgress`, `innovationProgress`, trait `biophysicalVector`, decision `archetype` and `biophysicalVector`, `totalCellPopulation`, `rivalDemesCount`, `kinDemesCount`, and neighbor `totalPopulation`) in `src/engine/turnEngine.ts`
- [X] T010 [P] [US2] Implement `buildCompactSystemOneState(input: DemeDecisionEvaluationInput): string` and `buildCompactDecisionCriteria(eligibleDecisions: DemeDecisionEvaluationInput["eligibleDecisions"]): Record<string, string>` in `src/ai/ollamaSystemOne.ts` and wire them into `evaluateDemeWithOllamaSystemOne`
- [X] T011 [P] [US2] Update `MockCognitiveProvider.evaluateDemeDecisions` in `src/ai/cognitiveProvider.ts` to leverage the enriched caloric adequacy, cohabiting competition, and open land-bridge signals consistently with `buildCompactSystemOneState`
- [X] T012 [US2] Add contract tests for `buildCompactSystemOneState`, `buildCompactDecisionCriteria`, and `computeDemeEvaluationSignature` verifying `>= 35%` payload reduction and ecological signal presence in `tests/contract/cognitiveSchemas.test.ts`

**Checkpoint**: User Stories 1 and 2 are both independently functional and verified (`FR-001`, `FR-002`, `SC-001`, `SC-004`)

---

## Phase 5: User Story 3 - Síntesis de Hitos Evolutivos y Culturales Contextualizada y Concisa (Priority: P2)

**Goal**: Provide System 2 (`gemma4:e4b-it-qat`) with rich causal context (deme energy reserves/delta, habitat resources and health $K / K_{\max}$, season, recent lineage chronicle titles, and global emergent trait names to prevent duplicates) and strict conciseness rules (`numPredict: 260`, 1–2 sentence constraints) to cut synthesis latency by `>= 30%` (`FR-006`, `SC-003`).

**Independent Test**: Trigger milestone synthesis and verify that the prompt/input includes habitat resource/health metrics, existing emergent trait names to exclude duplicates, and concise field length limits (`name <= 60 chars`, `semanticDescriptor 10-300 chars`, `affinityCondition 5-200 chars`) validated by `SynthesizedTraitProposalSchema`.

### Implementation for User Story 3

- [X] T013 [P] [US3] Populate enriched causal fields on `MilestoneSynthesisInput` (`season`, `energyReserves`, `lastEnergyDelta`, `currentResources`, `carryingCapacity`, `carryingCapacityMax`, `globalEmergentTraitNames`, `recentChronicleTitles`) in `src/engine/milestonePhase.ts` and `src/engine/turnEngine.ts`
- [X] T014 [P] [US3] Update `synthesizeMilestoneWithGemma` and `coDesignCatalogItemWithGemma` in `src/ai/langchainSystemTwo.ts` (and `MockCognitiveProvider.synthesizeMilestone` in `src/ai/cognitiveProvider.ts`) to include causal habitat/energy/history context, forbid duplicate trait names, reuse `ChatOllama` configuration with `numPredict: 260` and `temperature: 0.35`, and enforce concise 1–2 sentence field generation
- [X] T015 [US3] Add contract tests in `tests/contract/cognitiveSchemas.test.ts` verifying enriched `MilestoneSynthesisInput` handling and duplicate trait name prevention across locales

**Checkpoint**: All 3 user stories (`US1`, `US2`, `US3`) are independently functional and verified

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: End-to-end validation across all unit, contract, and 30-generation integration benchmarks and quickstart verification

- [X] T016 Run full typecheck, unit, contract, and integration test suites (`npm run typecheck && npm test`) and verify all criteria in `specs/003-ollama-perf-context/quickstart.md`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies — runs immediately (`T001`).
- **Phase 2 (Foundational)**: Depends on `T001` — extends shared TypeScript interfaces in `src/types/simulation.ts` (`T002`) and blocks all user story phases.
- **Phase 3 (US1 - Turn Pacing & Deduplication, P1)**: Depends on `T002`. Tasks `T003`, `T004`, `T005`, `T006` touch distinct files and can run in parallel before `T007` and `T008`.
- **Phase 4 (US2 - Enriched Compact System 1 Context, P1)**: Depends on `T002` (and integrates cleanly with `T003`/`T007` in `src/ai/ollamaSystemOne.ts` and `src/engine/turnEngine.ts`). Tasks `T010` and `T011` can run in parallel.
- **Phase 5 (US3 - Enriched & Concise System 2 Synthesis, P2)**: Depends on `T002`. Tasks `T013` and `T014` can run in parallel before `T015`.
- **Phase 6 (Polish)**: Depends on completion of Phases 3, 4, and 5 (`T016`).

### Parallel Opportunities

- **Within US1**: `T003` (`src/ai/ollamaSystemOne.ts`), `T004` (`src/engine/biophysicalPhase.ts`), `T005` (`src/engine/milestonePhase.ts`), and `T006` (`src/store/persistence.ts`) operate on separate files and can be executed in parallel.
- **Within US2**: `T010` (`src/ai/ollamaSystemOne.ts`) and `T011` (`src/ai/cognitiveProvider.ts`) operate on separate files and can be executed in parallel.
- **Within US3**: `T013` (`src/engine/milestonePhase.ts` / `src/engine/turnEngine.ts`) and `T014` (`src/ai/langchainSystemTwo.ts` / `src/ai/cognitiveProvider.ts`) can be executed in parallel.

---

## Parallel Example: User Story 1

```bash
# Execute parallel engine, AI signature, and persistence tasks for US1:
Task T003: "Implement computeDemeEvaluationSignature and reusable Ollama client in src/ai/ollamaSystemOne.ts"
Task T004: "Implement intentional migratory fission gating and < 0.25 intra-lineage merging in src/engine/biophysicalPhase.ts"
Task T005: "Add deterministic milestone priority helper in src/engine/milestonePhase.ts"
Task T006: "Optimize saveWorldToLocalStorage in src/store/persistence.ts"
```

---

## Implementation Strategy

### MVP First (User Story 1 + User Story 2)

1. Complete Phase 1 (`T001`) and Phase 2 (`T002`).
2. Complete Phase 3 (`US1`: `T003`–`T008`) to stop exponential micro-deme fission, deduplicate equivalent turn evaluations, and cap milestone synthesis to 1 per turn.
3. Complete Phase 4 (`US2`: `T009`–`T012`) to cut System 1 input tokens by ~50% and expose caloric adequacy, competition, and biophysical vectors to `d3:4b`.
4. Complete Phase 5 (`US3`: `T013`–`T015`) to enrich and accelerate System 2 (`gemma4:e4b-it-qat`) synthesis.
5. Run Phase 6 (`T016`) to validate 100% of unit, contract, and 30-generation integration tests.
