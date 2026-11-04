---
description: "Actionable, dependency-ordered task list for 004-dual-decision-models"
---

# Tasks: Arquitectura Cognitiva Dual de Decisión por Población y Síntesis Ligera en VRAM

**Input**: Design documents from `/specs/004-dual-decision-models/` (`plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/dual-decision-models.contract.md`, `quickstart.md`)

**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/dual-decision-models.contract.md`

**Organization**: Tasks are grouped by user story (`US1`, `US2`, `US3`) to enable independent implementation, verification, and incremental delivery.

## Format: `[ID] [P?] [Story?] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks)
- **[Story]**: User story label (`[US1]`, `[US2]`, `[US3]`) for user story phases only
- Every task includes exact repository-relative file paths

---

## Phase 1: Setup (Baseline Verification)

**Purpose**: Verify baseline TypeScript compilation and test suite before implementing dual decision model orchestration

- [X] T001 Verify baseline TypeScript build and test suite via `package.json` scripts (`npm run typecheck && npm test`)

---

## Phase 2: Foundational (Shared Multi-Model Types)

**Purpose**: Extend shared domain interfaces in `src/types/simulation.ts` so all downstream User Stories (`US1`, `US2`, `US3`) have strongly-typed access to `decisionModelTag` and tri-model status fields

**⚠️ CRITICAL**: Must complete before User Story phases begin

- [X] T002 Extend `DemeDecisionEvaluationInput` and `OllamaStatusReport` in `src/types/simulation.ts` with `deme.decisionModelTag?: string` (Non-empty model tag when provided, e.g., `"d3:4b"` or `"tev1:4b"`, defaulting to `DEFAULT_SYSTEM_ONE_MODEL` `"d3:4b"` when omitted) and optional tri-model readiness fields `secondarySystemOneModelReady?: boolean` (`true` iff `tev1:4b` or `tev1:*` is installed) and `resolvedSecondarySystemOneTag?: string` (Resolved secondary System 1 tag, default `"tev1:4b"`)

**Checkpoint**: Shared TypeScript contracts ready for `US1`, `US2`, and `US3`

---

## Phase 3: User Story 1 - Gestión Cognitiva de Poblaciones con Dos Modelos de Decisión Distintos (Priority: P1) 🎯 MVP

**Goal**: Deterministically assign each subpopulation (*deme*) to either `d3:4b` (`DEFAULT_SYSTEM_ONE_MODEL`) or `tev1:4b` (`SECONDARY_SYSTEM_ONE_MODEL`), isolate intra-turn equivalence signatures by assigned model (`{modelKey}|{season}|...`), dispatch unique turn evaluations concurrently via `Promise.all`, and include the assigned model in localized justifications (`FR-001`, `FR-002`, `FR-003`, `SC-002`, `SC-003`).

**Independent Test**: Run a generational turn across multi-deme scenarios (*The Rift and the Savanna* and *The Finite Island*) and verify that populations are deterministically assigned to `d3:4b` and `tev1:4b`, that two demes with identical ecological context but different assigned models produce distinct signatures and invoke their respective models concurrently without cache collision, and that their justification strings identify the assigned decision model.

### Implementation for User Story 1

- [X] T003 [P] [US1] Add `SECONDARY_SYSTEM_ONE_MODEL = "tev1:4b"`, implement `resolveDemeDecisionModelTag(demeId: string, primaryTag?: string, secondaryTag?: string): string`, include `input.deme.decisionModelTag ?? DEFAULT_SYSTEM_ONE_MODEL` in `computeDemeEvaluationSignature`, and include `input.deme.decisionModelTag` in `buildContextualJustification` when provided in `src/ai/ollamaSystemOne.ts`
- [X] T004 [US1] Update `LiveCognitiveProvider` in `src/ai/cognitiveProvider.ts` to accept `secondarySystemOneTag?: string` in `LiveCognitiveProviderOptions` and route `evaluateDemeDecisions(input)` to `this.resolvedSecondarySystemOneTag` when `input.deme.decisionModelTag` matches `SECONDARY_SYSTEM_ONE_MODEL` or `this.resolvedSecondarySystemOneTag` (and to `this.resolvedSystemOneTag` otherwise)
- [X] T005 [US1] Update `executeGenerationalTurn` in `src/engine/turnEngine.ts` to assign `decisionModelTag: resolveDemeDecisionModelTag(deme.id)` on each deme's `evaluationInput`, pre-group demes by `computeDemeEvaluationSignature(evaluationInput)`, evaluate all unique signatures concurrently via `Promise.all`, and populate `decisionsByDemeId` with deme-specific localized justifications
- [X] T006 [US1] Add contract and integration tests verifying deterministic per-population model assignment (`d3:4b` vs `tev1:4b`), model-partitioned `computeDemeEvaluationSignature`, justification model attribution, and concurrent multi-deme evaluation in `tests/contract/cognitiveSchemas.test.ts` and `tests/integration/scientificPresets.test.ts`

**Checkpoint**: User Story 1 is independently functional and verified (`FR-001`, `FR-002`, `FR-003`, `SC-003`)

---

## Phase 4: User Story 2 - Síntesis Generativa Ligera para Coexistencia de los Tres Modelos en Memoria de Vídeo (Priority: P1)

**Goal**: Switch the default System 2 generative model to `gemma4:e2b` so that `d3:4b`, `tev1:4b`, and `gemma4:e2b` remain simultaneously resident at `100% GPU` within a `< 15.5 GB` VRAM footprint and complete warm milestone synthesis in `< 3.0 s` (`FR-004`, `SC-001`, `SC-002`).

**Independent Test**: Verify that `DEFAULT_SYSTEM_TWO_MODEL` is `"gemma4:e2b"`, that `LiveCognitiveProvider` resolves `"gemma4:e2b"`, and that milestone synthesis and catalog co-design contracts pass across all 8 supported locales.

### Implementation for User Story 2

- [X] T007 [P] [US2] Update `DEFAULT_SYSTEM_TWO_MODEL` to `"gemma4:e2b"` in `src/ai/langchainSystemTwo.ts` and update `LiveCognitiveProvider.checkStatus()` in `src/ai/cognitiveProvider.ts` to prefer matching `"gemma4:e2b"` (or `gemma4:*`)

**Checkpoint**: User Stories 1 and 2 are both independently functional and verified (`FR-004`, `SC-001`, `SC-002`)

---

## Phase 5: User Story 3 - Diagnóstico y Verificación de Disponibilidad de los Tres Modelos (Priority: P2)

**Goal**: Verify availability of all three required models (`d3:4b`, `tev1:4b`, and `gemma4:e2b`) in `LiveCognitiveProvider.checkStatus()` and display their readiness status and `ollama pull` commands in `OllamaDiagnosticsModal.tsx` (`FR-005`, `SC-003`).

**Independent Test**: Query `checkStatus()` on `LiveCognitiveProvider` and inspect `OllamaDiagnosticsModal.tsx` to verify that `systemOneModelReady` requires both `d3:4b` and `tev1:4b`, `secondarySystemOneModelReady` and `resolvedSecondarySystemOneTag` are populated, and `missingCommands` and CLI instructions list `ollama pull d3:4b`, `ollama pull tev1:4b`, and `ollama pull gemma4:e2b`.

### Implementation for User Story 3

- [X] T008 [P] [US3] Update `LiveCognitiveProvider.checkStatus()` and `MockCognitiveProvider.checkStatus()` in `src/ai/cognitiveProvider.ts` to check and report `d3:4b`, `tev1:4b`, and `gemma4:e2b` (`secondarySystemOneModelReady`, `resolvedSecondarySystemOneTag`, `systemOneModelReady = Boolean(matchedD3 && matchedTev1)`, and `missingCommands` containing `"ollama pull d3:4b"`, `"ollama pull tev1:4b"`, `"ollama pull gemma4:e2b"`)
- [X] T009 [P] [US3] Update `REQUIRED_CLI_COMMANDS` and model readiness badges in `src/components/OllamaDiagnosticsModal.tsx` to display `d3:4b`, `tev1:4b`, and `gemma4:e2b`
- [X] T010 [US3] Update contract tests in `tests/contract/cognitiveSchemas.test.ts` to assert tri-model `checkStatus()` reporting (`ollama pull d3:4b`, `ollama pull tev1:4b`, `ollama pull gemma4:e2b`)

**Checkpoint**: All 3 user stories (`US1`, `US2`, `US3`) are independently functional and verified

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: End-to-end validation of TypeScript build, unit/contract/integration tests, and live 3-model VRAM and turn execution

- [X] T011 Run full typecheck, unit, contract, and integration test suites (`npm run typecheck && npm test`) and verify live 3-model coexistence (`d3:4b`, `tev1:4b`, `gemma4:e2b`) per `specs/004-dual-decision-models/quickstart.md`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies — runs immediately (`T001`).
- **Phase 2 (Foundational)**: Depends on `T001` — extends shared TypeScript interfaces in `src/types/simulation.ts` (`T002`) and blocks all user story phases.
- **Phase 3 (US1 - Dual Decision Model Assignment & Concurrent Turn Evaluation, P1)**: Depends on `T002` (`T003` → `T004` → `T005` → `T006`).
- **Phase 4 (US2 - Compact `gemma4:e2b` System 2 Model, P1)**: Depends on `T002` (`T007`). Can run in parallel with `T003` (`src/ai/ollamaSystemOne.ts`).
- **Phase 5 (US3 - Tri-Model Diagnostics & Status Reporting, P2)**: Depends on `T002` (`T008`, `T009`, `T010`). `T009` (`src/components/OllamaDiagnosticsModal.tsx`) can run in parallel with `T008` (`src/ai/cognitiveProvider.ts`).
- **Phase 6 (Polish)**: Depends on completion of Phases 3, 4, and 5 (`T011`).

### Parallel Opportunities

- `T003` (`src/ai/ollamaSystemOne.ts`), `T007` (`src/ai/langchainSystemTwo.ts`), and `T009` (`src/components/OllamaDiagnosticsModal.tsx`) operate on distinct files and can be executed in parallel once `T002` completes.

---

## Parallel Example: User Stories 1, 2 & 3

```bash
# After T002 completes, execute tasks on separate files in parallel:
Task T003: "Implement SECONDARY_SYSTEM_ONE_MODEL and resolveDemeDecisionModelTag in src/ai/ollamaSystemOne.ts"
Task T007: "Update DEFAULT_SYSTEM_TWO_MODEL to gemma4:e2b in src/ai/langchainSystemTwo.ts"
Task T009: "Update REQUIRED_CLI_COMMANDS and badges in src/components/OllamaDiagnosticsModal.tsx"
```

---

## Implementation Strategy

### MVP First (User Story 1 + User Story 2)

1. Complete Phase 1 (`T001`) and Phase 2 (`T002`).
2. Complete Phase 3 (`US1`: `T003`–`T006`) to enable dual decision models (`d3:4b` + `tev1:4b`) per population with model-isolated signatures and concurrent turn evaluation.
3. Complete Phase 4 (`US2`: `T007`) to switch System 2 to `gemma4:e2b` so all 3 models coexist at `100% GPU` in 16 GB VRAM.
4. Complete Phase 5 (`US3`: `T008`–`T010`) to update tri-model status checks and the diagnostics modal.
5. Run Phase 6 (`T011`) to verify 100% test pass rate and live 3-model execution.
