# Phase 0 Research: Arquitectura Cognitiva Dual de Decisión por Población y Síntesis Ligera en VRAM

**Feature**: `004-dual-decision-models`  
**Date**: 2026-11-04

## 1. Coexistencia en VRAM de `d3:4b`, `tev1:4b` y `gemma4:e2b` (RTX 5060 Ti 16 GB)

- **Decision**: Adopt `d3:4b` (primary System 1 decision model), `tev1:4b` (secondary System 1 decision model), and `gemma4:e2b` (System 2 generative synthesis LLM) with `keep_alive: "30m"`.
- **Empirical Benchmark (NVIDIA GeForce RTX 5060 Ti, `16,311 MiB` total VRAM)**:
  - Baseline VRAM (0 models loaded): `1,009 MiB` used / `14,838 MiB` free.
  - With `d3:4b` (`6.3 GB`, `100% GPU`, `num_ctx = 4096`): `7,863 MiB` used / `7,984 MiB` free; warm `/v1/systemone` latency `~30–38 ms`.
  - With `d3:4b` + `tev1:4b` (`5.7 GB`, `100% GPU`, `num_ctx = 8192`): `13,480 MiB` used / `2,367 MiB` free; warm `/v1/systemone` latency `~33–36 ms`.
  - With `d3:4b` + `tev1:4b` + `gemma4:e2b` (`100% GPU`, `num_ctx = 4096`): `15,032 MiB` used / `816 MiB` free; warm structured JSON synthesis latency `~1,881 ms` (a **42% reduction** compared to `gemma4:e4b-it-qat`'s `~3,260 ms`).
- **Rationale**: Replacing `gemma4:e4b-it-qat` (`~3.1 GB` VRAM) with `gemma4:e2b` (`~1.55 GB` VRAM delta) frees the exact headroom required for both `d3:4b` and `tev1:4b` to stay resident at `100% GPU` simultaneously without model eviction or disk swapping.
- **Alternatives Considered**:
  - *Keeping `gemma4:e4b-it-qat` alongside `d3:4b` and `tev1:4b`*: Rejected because total VRAM exceeds `16,311 MiB`, forcing CPU/GPU split or per-turn model unloading (`2–5 s` penalty).

## 2. Asignación Determinista de Modelo de Decisión por Población (`resolveDemeDecisionModelTag`)

- **Decision**: Implement a pure deterministic function `resolveDemeDecisionModelTag(demeId: string, primaryTag?: string, secondaryTag?: string): string` in `src/ai/ollamaSystemOne.ts`:
  - Known preset founder demes and deterministic ID hashing assign each deme to either `d3:4b` (`DEFAULT_SYSTEM_ONE_MODEL`) or `tev1:4b` (`SECONDARY_SYSTEM_ONE_MODEL`):
    - In *The Rift and the Savanna*: `deme-rift-west` → `d3:4b`, `deme-rift-east` → `tev1:4b`.
    - In *The Finite Island*: `deme-island-1` → `d3:4b`, `deme-island-2` → `tev1:4b`, `deme-island-3` → `d3:4b`.
    - For all other demes (including migrant daughter demes `-m{gen}-{q}_{r}` in *Darwin's Archipelago*), a deterministic character-code hash of `demeId` assigns `even -> primaryTag (d3:4b)` and `odd -> secondaryTag (tev1:4b)`.
- **Rationale**: Guarantees reproducible assignment across turns and saves without mutating saved world schemas or requiring manual user configuration, while ensuring both `d3:4b` and `tev1:4b` actively govern subpopulations in multi-deme scenarios.
- **Alternatives Considered**:
  - *Random per-turn model selection*: Rejected because a deme would flip cognitive personalities every generation, breaking behavioral continuity (Baldwin effect).

## 3. Firma de Equivalencia Consciente del Modelo y Despacho Concurrente (`Promise.all`)

- **Decision**:
  1. Extend `DemeDecisionEvaluationInput["deme"]` with optional `decisionModelTag?: string`.
  2. Include `input.deme.decisionModelTag ?? DEFAULT_SYSTEM_ONE_MODEL` in `computeDemeEvaluationSignature(input)` so demes assigned to `d3:4b` and `tev1:4b` never collide in the intra-turn cache, while demes sharing the **same** model and ecological state still deduplicate.
  3. In `executeGenerationalTurn` (`src/engine/turnEngine.ts`), pre-group all demes by their computed `signature`, evaluate all unique signatures concurrently via `Promise.all`, and then populate `decisionsByDemeId` with deme-specific localized justifications (including the model tag when `decisionModelTag` is set).
- **Rationale**: Pre-grouping by `signature` before `Promise.all` avoids duplicate in-flight requests for identical signatures while dispatching `d3:4b` and `tev1:4b` evaluations concurrently.
