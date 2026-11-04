# Contract: Dual Decision Models (`d3:4b` + `tev1:4b`) & Compact System 2 (`gemma4:e2b`)

**Feature**: `004-dual-decision-models`  
**Modules**: `src/types/simulation.ts`, `src/ai/ollamaSystemOne.ts`, `src/ai/langchainSystemTwo.ts`, `src/ai/cognitiveProvider.ts`, `src/engine/turnEngine.ts`, `src/components/OllamaDiagnosticsModal.tsx`

## 1. Model Constants Contract

- `DEFAULT_SYSTEM_ONE_MODEL` in `src/ai/ollamaSystemOne.ts` MUST equal `"d3:4b"`.
- `SECONDARY_SYSTEM_ONE_MODEL` in `src/ai/ollamaSystemOne.ts` MUST equal `"tev1:4b"`.
- `DEFAULT_SYSTEM_TWO_MODEL` in `src/ai/langchainSystemTwo.ts` MUST equal `"gemma4:e2b"`.

## 2. Deterministic Per-Population Model Assignment Contract (`FR-001`)

```ts
export function resolveDemeDecisionModelTag(
  demeId: string,
  primaryTag: string = DEFAULT_SYSTEM_ONE_MODEL,
  secondaryTag: string = SECONDARY_SYSTEM_ONE_MODEL
): string;
```

- MUST deterministically return either `primaryTag` (`"d3:4b"`) or `secondaryTag` (`"tev1:4b"`) for any `demeId`.
- For preset multi-population worlds:
  - `deme-rift-west` → `primaryTag` (`"d3:4b"`) and `deme-rift-east` → `secondaryTag` (`"tev1:4b"`).
  - `deme-island-1` → `primaryTag` (`"d3:4b"`), `deme-island-2` → `secondaryTag` (`"tev1:4b"`), `deme-island-3` → `primaryTag` (`"d3:4b"`).
- For any other `demeId`, MUST compute a deterministic hash so both models are assigned reproducibly across subpopulations.

## 3. Model-Aware Signature & Concurrent Turn Evaluation Contract (`FR-002`, `FR-003`)

- `computeDemeEvaluationSignature(input)` MUST include `input.deme.decisionModelTag ?? DEFAULT_SYSTEM_ONE_MODEL` so two inputs identical in all fields except `decisionModelTag` (`"d3:4b"` vs `"tev1:4b"`) produce distinct signatures, while two inputs with the same `decisionModelTag` (or both omitted) and equivalent ecological state produce identical signatures.
- `executeGenerationalTurn` MUST assign `decisionModelTag` to each deme's `evaluationInput`, group demes by `signature` to deduplicate within the same model, and evaluate unique signatures concurrently via `Promise.all`.
- When `input.deme.decisionModelTag` is defined, `buildContextualJustification` MUST include the model tag in the header bracket (e.g., `[Model: tev1:4b | Biome: savanna | ...]`).

## 4. Tri-Model Status & Diagnostics Contract (`FR-004`, `FR-005`)

- `LiveCognitiveProvider.checkStatus()` MUST check for `d3:4b`, `tev1:4b`, and `gemma4:e2b`.
- If the server is unreachable, `missingCommands` MUST contain `"ollama pull d3:4b"`, `"ollama pull tev1:4b"`, and `"ollama pull gemma4:e2b"`.
- `LiveCognitiveProvider.evaluateDemeDecisions(input)` MUST route the evaluation to `this.resolvedSecondarySystemOneTag` when `input.deme.decisionModelTag` matches `SECONDARY_SYSTEM_ONE_MODEL` or `this.resolvedSecondarySystemOneTag`, and to `this.resolvedSystemOneTag` otherwise.
