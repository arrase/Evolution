# Implementation Plan: Arquitectura Cognitiva Dual de Decisión por Población y Síntesis Ligera en VRAM

**Branch**: `004-dual-decision-models` | **Date**: 2026-11-04 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/004-dual-decision-models/spec.md`

## Summary

Enable each subpopulation (*deme*) to be deterministically governed by one of two System 1 decision models (`d3:4b` and `tev1:4b`) evaluated concurrently per turn while switching the System 2 generative LLM to `gemma4:e2b` so all three models remain resident at `100% GPU` in a 16 GB VRAM budget (`~15.0 GB` used):
- **Deterministic Dual Decision Model Assignment (`US1`, `FR-001`):** Add `SECONDARY_SYSTEM_ONE_MODEL = "tev1:4b"` and `resolveDemeDecisionModelTag(demeId, primaryTag, secondaryTag)` in `src/ai/ollamaSystemOne.ts` so populations across presets (*The Rift and the Savanna*, *The Finite Island*, *Darwin's Archipelago*) are deterministically split between `d3:4b` and `tev1:4b`.
- **Model-Partitioned Intra-Turn Deduplication & Concurrent Dispatch (`US1`, `FR-002`, `FR-003`):** Include `decisionModelTag` in `computeDemeEvaluationSignature` so `d3:4b` and `tev1:4b` evaluations never collide in cache while preserving intra-model deduplication; pre-group demes by signature in `executeGenerationalTurn` (`src/engine/turnEngine.ts`) and evaluate unique signatures concurrently with `Promise.all`; include the active `decisionModelTag` in `buildContextualJustification` when provided.
- **Compact System 2 LLM (`gemma4:e2b`) (`US2`, `FR-004`):** Update `DEFAULT_SYSTEM_TWO_MODEL` in `src/ai/langchainSystemTwo.ts` from `"gemma4:e4b-it-qat"` to `"gemma4:e2b"`, reducing System 2 VRAM by `~1.55 GB` and warm milestone synthesis latency from `~3.26 s` to `~1.88 s`.
- **Tri-Model Diagnostics & Status Reporting (`US3`, `FR-005`):** Update `OllamaStatusReport` (`src/types/simulation.ts`), `LiveCognitiveProvider` (`src/ai/cognitiveProvider.ts`), and `OllamaDiagnosticsModal` (`src/components/OllamaDiagnosticsModal.tsx`) to verify and display readiness and `ollama pull` commands for `d3:4b`, `tev1:4b`, and `gemma4:e2b`.

## Technical Context

**Language/Version**: TypeScript `7.0.2` (strict mode, ESM `"type": "module"`)

**Primary Dependencies**:
- AI & Schema Validation: `ollama@0.6.4` (`ollama/browser`), `@langchain/ollama@1.3.0`, `@langchain/core@1.3.4`, `zod@4.6.7`
- Build, UI & State: `vite@8.3.5`, `react@19.3.1`, `zustand@5.0.16`, `honeycomb-grid@4.1.5`, `i18next@26.7.1`, `react-i18next@17.1.12`

**Storage**: Client-side `localStorage` (unchanged schema; `decisionModelTag` is deterministically resolved at evaluation time).

**Testing**: `vitest@5.1.0` for unit tests (`tests/unit/`), contract tests (`tests/contract/cognitiveSchemas.test.ts`), and 30-generation preset integration tests (`tests/integration/scientificPresets.test.ts`).

**Target Platform**: Modern Desktop Web Browser + local Ollama server (`http://127.0.0.1:11434`) on a 16 GB GPU.

**Project Type**: Interactive Web Simulation Application (Single-Project SPA with decoupled pure simulation engine).

**Performance Goals**:
- All 3 models (`d3:4b`, `tev1:4b`, `gemma4:e2b`) resident at `100% GPU` within `< 15.5 GB` VRAM (`15,032 MiB` measured on RTX 5060 Ti 16 GB).
- System 1 warm decision evaluation `< 100 ms` (`~30–38 ms` measured for both `d3:4b` and `tev1:4b`).
- System 2 (`gemma4:e2b`) warm milestone synthesis `< 3.0 s` (`~1.88 s` measured).

**Constraints**:
- Strict adherence to KISS & YAGNI (Constitution Principle I): pure top-to-bottom functions, zero extra dependencies, all imports at top of file, 100% backward compatibility with existing tests and saved worlds.

**Scale/Scope**:
- 6 core files (`src/types/simulation.ts`, `src/ai/ollamaSystemOne.ts`, `src/ai/langchainSystemTwo.ts`, `src/ai/cognitiveProvider.ts`, `src/engine/turnEngine.ts`, `src/components/OllamaDiagnosticsModal.tsx`) + contract and integration tests.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked and verified after Phase 1 design.*

| Constitution Principle | Pre-Research Check | Post-Design Check | Verification Evidence |
| :--- | :---: | :---: | :--- |
| **I. Radical Simplicity & Zero Defensive Bloat (KISS & YAGNI)** | PASS | PASS | Deterministic helper `resolveDemeDecisionModelTag`, signature pre-grouping with `Promise.all` in `turnEngine.ts`, zero extra classes or dependencies, all imports at top of file. |
| **II. Scientific Rigor & Bio-Cultural Fidelity** | PASS | PASS | Deterministic deme-to-model mapping preserves behavioral continuity across generations while allowing distinct cognitive models (`d3:4b` vs `tev1:4b`) to govern competing populations. |
| **III. Dual-Frequency Multi-Model Cognitive Architecture (`d3:4b` + `tev1:4b` & `gemma4:e2b`)** | PASS | PASS | Directly implements dual System 1 decision models (`d3:4b` and `tev1:4b`) and compact System 2 synthesis (`gemma4:e2b`) coexisting 100% in GPU VRAM. |
| **IV. Curated Modern TypeScript Ecosystem** | PASS | PASS | Uses official `ollama/browser` and `@langchain/ollama` SDKs without custom wrappers. |
| **V. Transparent & Interactive Sandbox UX** | PASS | PASS | Exposes the active decision model in deme justifications and shows readiness/install commands for all 3 models in `OllamaDiagnosticsModal.tsx`. |

## Project Structure

### Documentation (this feature)

```text
specs/004-dual-decision-models/
├── plan.md                                      # This file (/speckit-plan output)
├── research.md                                  # Phase 0 VRAM & latency benchmarks and design decisions
├── data-model.md                                # Phase 1 input, signature & status report models
├── quickstart.md                                # Phase 1 validation & VRAM check guide
├── checklists/
│   └── requirements.md                          # Spec quality checklist (/speckit-specify)
├── contracts/
│   └── dual-decision-models.contract.md         # Phase 1 System 1/2 multi-model contracts
└── tasks.md                                     # Phase 2 actionable tasks (/speckit-tasks)
```

### Source Code (repository root)

```text
src/
├── types/
│   └── simulation.ts                            # Add decisionModelTag to DemeDecisionEvaluationInput & secondary System 1 fields to OllamaStatusReport
├── ai/
│   ├── ollamaSystemOne.ts                       # Add SECONDARY_SYSTEM_ONE_MODEL ("tev1:4b"), resolveDemeDecisionModelTag, model-aware signature & justification
│   ├── langchainSystemTwo.ts                    # Update DEFAULT_SYSTEM_TWO_MODEL to "gemma4:e2b"
│   └── cognitiveProvider.ts                     # Route deme evaluations to d3:4b or tev1:4b and check status for all 3 models
├── engine/
│   └── turnEngine.ts                            # Assign decisionModelTag per deme, pre-group by signature, and dispatch unique evaluations via Promise.all
└── components/
    └── OllamaDiagnosticsModal.tsx               # List ollama pull commands and status badges for d3:4b, tev1:4b, and gemma4:e2b

tests/
├── contract/
│   └── cognitiveSchemas.test.ts                 # Test dual-model assignment, model-partitioned signatures, and 3-model checkStatus
└── integration/
    └── scientificPresets.test.ts                # Verify multi-deme turns evaluate both d3:4b and tev1:4b concurrently without cross-model cache collisions
```

**Structure Decision**: Update existing modules in place (`src/types/`, `src/ai/`, `src/engine/`, `src/components/`, `tests/`) with zero new files or abstraction layers.

## Complexity Tracking

No Constitution violations exist. All 5 Core Principles pass without exception.
