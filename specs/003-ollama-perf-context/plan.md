# Implementation Plan: Optimización de Velocidad por Turno y Enriquecimiento del Contexto Cognitivo de Decisión

**Branch**: `003-ollama-perf-context` | **Date**: 2026-11-04 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/003-ollama-perf-context/spec.md`

## Summary

Eliminate the progressive turn-by-turn slowdown in mid-to-late simulation generations ($G_{10}\text{--}G_{40}$) and significantly improve the ecological, energetic, and social context provided to the AI models (`d3:4b` System 1 and `gemma4:e4b-it-qat` System 2):
- **Compact High-Signal System 1 Context (`US2`, `FR-001`, `FR-002`):** Replace the raw `DemeDecisionEvaluationInput` JSON dump (`~662–950+ input_tokens`) in `src/ai/ollamaSystemOne.ts` with `buildCompactSystemOneState` and `buildCompactDecisionCriteria` (`~300–345 input_tokens`, ~50% token reduction and ~43% faster inference), explicitly exposing caloric adequacy (`resources / totalCellDemand`), deme vitality, habitat health ($K / K_{\max}$), cohabiting rival vs. kin populations, trait/decision biophysical vector modifiers, adaptive momentum (`lastDominantDecisionId` & Baldwin progress), and top passable neighbor escape routes.
- **Intra-Turn Evaluation Deduplication & Reusable Client (`US1`, `FR-003`):** Add `computeDemeEvaluationSignature` to bucket demes with equivalent ecological/competitive/trait state within the same turn in `src/engine/turnEngine.ts`, reusing the evaluated probability distribution while formatting deme-specific localized justifications, and reuse a single `Ollama` browser client instance per host.
- **Intentional Migratory Fission & Intra-Lineage Cohesion (`US1`, `FR-004`):** Gate migratory fission in `src/engine/biophysicalPhase.ts` on meaningful migration intent (`pMigrate >= 0.15`, dominant decision `dec-selective-migration`, active `coastal_shallows` land-bridge transit, or emergency resource depletion `< 20%` of population) and relax same-lineage cohabitation merging/blocking from `< 0.10` to `< 0.25` Jaccard divergence to stop exponential micro-deme fragmentation while preserving savanna and archipelago colonization.
- **System 2 Milestone Pacing, Causal Context & Concise Generation (`US1`, `US3`, `FR-005`, `FR-006`):** Keep `detectEvolutionaryMilestones` returning all eligible milestone candidates enriched with causal context (for unit test compatibility), and in `executeGenerationalTurn` prioritize candidates (`allopatric_speciation` > `baldwin_assimilation` > `cultural_innovation`), deduplicate per deme, and cap synthesis to at most **1 System 2 milestone synthesis per turn** (`slice(0, 1)` instead of `slice(0, 3)`). Enrich `MilestoneSynthesisInput` with causal habitat/energy/chronicle context and existing emergent trait names to prevent duplicates, and configure `ChatOllama` with `numPredict: 260` and concise field rules (cutting single milestone synthesis from `~10–16 s` to `~3.3 s` and max milestone turn duration from `~30 s` to `~3.3 s`).
- **Fast Turn Persistence (`US1`, `FR-007`):** Avoid redundant full-world Zod `.superRefine` parsing inside `saveWorldToLocalStorage` on every turn while keeping full schema validation on import/export and initial load.

## Technical Context

**Language/Version**: TypeScript `7.0.2` (strict mode, ESM `"type": "module"`)

**Primary Dependencies**:
- AI & Schema Validation: `ollama@0.6.4` (`ollama/browser`), `@langchain/ollama@1.3.0`, `@langchain/core@1.3.4`, `zod@4.6.7`
- Build, UI & State: `vite@8.3.5`, `react@19.3.1`, `zustand@5.0.16`, `honeycomb-grid@4.1.5`, `i18next@26.7.1`, `react-i18next@17.1.12`

**Storage**: Client-side `localStorage` (`saveWorldToLocalStorage` fast path for turn saves; `WorldStateSchema.parse` for import/export and initial load).

**Testing**: `vitest@5.1.0` for unit tests (`tests/unit/`), contract tests (`tests/contract/cognitiveSchemas.test.ts`), and 30-generation preset integration benchmarks (`tests/integration/scientificPresets.test.ts`).

**Target Platform**: Modern Desktop Web Browser + local Ollama server (`http://127.0.0.1:11434`).

**Project Type**: Interactive Web Simulation Application (Single-Project SPA with decoupled pure simulation engine).

**Performance Goals**:
- System 1 (`d3:4b`) input payload `< 360 tokens` (`>= 35%` reduction from 662 tokens) and `< 100 ms` warm evaluation per unique deme signature.
- `>= 50%` reduction in total System 1 evaluations across 30-generation preset runs via intentional fission gating, `< 0.25` intra-lineage merging, and intra-turn signature deduplication.
- System 2 (`gemma4:e4b-it-qat`) warm milestone synthesis `< 4.5 s` (down from `~10–16 s`) and capped at max `1` synthesis per turn.

**Constraints**:
- Strict adherence to KISS & YAGNI (Constitution Principle I): pure top-to-bottom functions, zero external caching libraries, all imports at top of file, 100% backward compatibility with existing test suites and saved worlds.

**Scale/Scope**:
- 6 core modules (`src/types/simulation.ts`, `src/ai/ollamaSystemOne.ts`, `src/ai/langchainSystemTwo.ts`, `src/engine/turnEngine.ts`, `src/engine/biophysicalPhase.ts`, `src/engine/milestonePhase.ts`, `src/store/persistence.ts`) + contract and unit tests.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked and verified after Phase 1 design.*

| Constitution Principle | Pre-Research Check | Post-Design Check | Verification Evidence |
| :--- | :---: | :---: | :--- |
| **I. Radical Simplicity & Zero Defensive Bloat (KISS & YAGNI)** | PASS | PASS | Pure string/signature helpers in `ollamaSystemOne.ts`, simple per-turn `Map` in `turnEngine.ts`, zero extra dependencies, all imports at top of file. |
| **II. Scientific Rigor & Bio-Cultural Fidelity** | PASS | PASS | Exposing caloric adequacy, total cell competition, and biophysical vectors allows `d3:4b` to respond authentically to $r/K$ trade-offs, Tragedy of the Commons, and allopatric land bridges; intentional fission gate prevents unscientific cloning when migration probability is marginal. |
| **III. Dual-Frequency Cognitive Architecture (`d3` + `gemma4:e4b-it-qat`)** | PASS | PASS | Preserves `d3` via `ollama/browser` for System 1 and `gemma4:e4b-it-qat` via `@langchain/ollama` + `zod` for System 2 while dramatically improving both latency and context richness. |
| **IV. Curated Modern TypeScript Ecosystem** | PASS | PASS | Uses existing `ollama@0.6.4`, `@langchain/ollama@1.3.0`, and `zod@4.6.7` without custom HTTP wrappers or external caching packages. |
| **V. Transparent & Interactive Sandbox UX** | PASS | PASS | Eliminates multi-second UI freezes during `Auto-Play` and enriches localized System 1 justifications and System 2 Naturalist Notebook chronicles across all 8 supported languages. |

## Project Structure

### Documentation (this feature)

```text
specs/003-ollama-perf-context/
├── plan.md                                                  # This file (/speckit-plan output)
├── research.md                                              # Phase 0 empirical & architectural research
├── data-model.md                                            # Phase 1 enriched input & signature models
├── quickstart.md                                            # Phase 1 validation & benchmark guide
├── checklists/
│   └── requirements.md                                      # Spec quality checklist (/speckit-specify)
├── contracts/
│   └── cognitive-context-and-pacing.contract.md             # Phase 1 System 1/2 context & turn pacing contracts
└── tasks.md                                                 # Phase 2 actionable tasks (/speckit-tasks)
```

### Source Code (repository root)

```text
src/
├── types/
│   └── simulation.ts                        # Extend DemeDecisionEvaluationInput & MilestoneSynthesisInput with enriched context fields
├── ai/
│   ├── ollamaSystemOne.ts                   # Add buildCompactSystemOneState, buildCompactDecisionCriteria, computeDemeEvaluationSignature
│   ├── langchainSystemTwo.ts                # Enrich causal prompt, forbid duplicate trait names, set numPredict: 260 & concise output rules
│   └── cognitiveProvider.ts                 # Align MockCognitiveProvider with enriched context & anti-duplication
├── engine/
│   ├── turnEngine.ts                        # Populate enriched context fields, apply intra-turn signature deduplication, prioritize & cap milestones to 1/turn
│   ├── biophysicalPhase.ts                  # Intentional migratory fission gate (pMigrate >= 0.15 / dominant / bridge / emergency) & < 0.25 lineage merge
│   └── milestonePhase.ts                    # Priority helper + populate causal context fields while preserving full candidate detection
└── store/
    └── persistence.ts                       # Fast JSON.stringify in saveWorldToLocalStorage while keeping schema parse on import/export

tests/
├── contract/
│   └── cognitiveSchemas.test.ts             # Test compact System 1 state (>35% token reduction), signature deduplication & enriched System 2 inputs
├── unit/
│   └── biophysicalPhase.test.ts             # Test intentional migratory fission gate, < 0.25 intra-lineage merge & 1-milestone-per-turn cap
└── integration/
    └── scientificPresets.test.ts            # Verify 30-generation preset benchmarks & bounded System 1/2 call counts
```

**Structure Decision**: Modify existing single-project modules in place (`src/types/`, `src/ai/`, `src/engine/`, `src/store/`, `tests/`) without introducing extra abstraction layers or folders.

## Complexity Tracking

No Constitution violations exist. All 5 Core Principles pass without exception.
