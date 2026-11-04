# Phase 1 Data Model: Arquitectura Cognitiva Dual de Decisión por Población y Síntesis Ligera en VRAM

**Feature**: `004-dual-decision-models`  
**Date**: 2026-11-04

## 1. Extended `DemeDecisionEvaluationInput` (`src/types/simulation.ts`)

Adds optional `decisionModelTag?: string` to `DemeDecisionEvaluationInput["deme"]`:

| Field Path | Type | Constraints / Validation Rules | Purpose |
| :--- | :--- | :--- | :--- |
| `deme.decisionModelTag` | `string \| undefined` | Non-empty model tag when provided (e.g., `"d3:4b"` or `"tev1:4b"`). Defaults to `DEFAULT_SYSTEM_ONE_MODEL` (`"d3:4b"`) when omitted. | Routes the deme's evaluation to its assigned System 1 model (`d3:4b` or `tev1:4b`), partitions the intra-turn equivalence signature by model, and annotates the localized justification. |

## 2. Extended `OllamaStatusReport` (`src/types/simulation.ts`)

Extends the status report with secondary System 1 model readiness while keeping full backward compatibility:

| Field Path | Type | Constraints / Validation Rules | Purpose |
| :--- | :--- | :--- | :--- |
| `connected` | `boolean` | Required boolean | Whether the Ollama server responded to `/api/tags`. |
| `host` | `string` | Required URL string | Ollama base URL (`http://127.0.0.1:11434`). |
| `systemOneModelReady` | `boolean` | `true` iff **both** primary (`d3:4b`) and secondary (`tev1:4b`) System 1 decision models are installed | Aggregate readiness gate for System 1 used by `App.tsx`, `TopControlBar.tsx`, and `OllamaDiagnosticsModal.tsx`. |
| `resolvedSystemOneTag` | `string` | Resolved primary System 1 tag (default `"d3:4b"`) | Tag used for primary System 1 evaluations. |
| `secondarySystemOneModelReady` | `boolean \| undefined` | `true` iff `tev1:4b` (or `tev1:*`) is installed | Individual readiness flag for the second decision model. |
| `resolvedSecondarySystemOneTag` | `string \| undefined` | Resolved secondary System 1 tag (default `"tev1:4b"`) | Tag used for secondary System 1 evaluations. |
| `systemTwoModelReady` | `boolean` | `true` iff `gemma4:e2b` (or `gemma4:*`) is installed | Readiness gate for System 2 generative synthesis. |
| `resolvedSystemTwoTag` | `string` | Resolved System 2 tag (default `"gemma4:e2b"`) | Tag used for System 2 milestone synthesis and catalog co-design. |
| `missingCommands` | `string[]` | Subset of `["ollama pull d3:4b", "ollama pull tev1:4b", "ollama pull gemma4:e2b"]` | CLI commands for any missing models. |

## 3. Model-Partitioned `DemeEvaluationSignature` (`src/ai/ollamaSystemOne.ts`)

Deterministic intra-turn cache key incorporating `modelKey`:

```text
{modelKey}|{season}|{biome}|{adequacyTier}|{healthTier}|{vitality}|{competitionKey}|{traitsKey}|{dominantKey}|{neighborKey}
```

- `modelKey`: `input.deme.decisionModelTag ?? DEFAULT_SYSTEM_ONE_MODEL` (`"d3:4b"` or `"tev1:4b"`).
- Ensures demes governed by `d3:4b` and `tev1:4b` never share cached evaluations, while demes governed by the same model with equivalent ecological state still reuse the single turn evaluation.
