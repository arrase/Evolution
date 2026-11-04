# Phase 0 Research: Optimización de Velocidad por Turno y Enriquecimiento del Contexto Cognitivo de Decisión

**Feature**: `003-ollama-perf-context`  
**Date**: 2026-11-04

## 1. Compact High-Signal System 1 (`d3:4b`) Context Representation

- **Decision**: Replace the verbose raw JSON state dump (`662–950+ input_tokens` per deme) in `src/ai/ollamaSystemOne.ts` with a compact, structured ecological and behavioral briefing (`buildCompactSystemOneState` and `buildCompactDecisionCriteria`, `~300–345 input_tokens`) that explicitly computes and exposes:
  1. **Caloric Adequacy Ratio (`resourceAdequacyRatio`)**: `currentResources / Math.max(10, totalCellPopulation * 0.48)`, plus the deme's vital status (`thriving`, `stable`, `struggling`, `starving`) and `lastEnergyDelta`.
  2. **Habitat Health & Competition**: `healthPct = Math.round((carryingCapacity / carryingCapacityMax) * 100)`, `totalCellPopulation` (summing all cohabiting demes in the hex), `rivalDemesCount` (different `lineageId`), and `kinDemesCount` (same `lineageId`).
  3. **Trait & Decision Biophysical Vectors**: Include concise biophysical modifiers (`cost`, `extract`, `eco`, `mobility`, `cohesion`) and key affinity cues on both active traits and `criteria` descriptions so `d3:4b` can weigh metabolic cost against extraction yield.
  4. **Adaptive Momentum & Passable Escape Routes**: Include `lastDominantDecisionId`, active Baldwin/Innovation progress, and up to 3 top passable neighbor hexes sorted by per-capita resource opportunity (explicitly flagging uninhabited `coastal_shallows` land bridges and richer frontier biomes).
- **Empirical Benchmark (Live `d3:4b` on RTX 5060 Ti)**:
  - Input tokens dropped from **662 tokens → 301–345 tokens** (**~50% reduction**).
  - Warm inference latency per call dropped from **~115–140 ms → 65–98 ms** (**~43% speedup**).
  - Decision accuracy across the 4 canonical ecological situations (*Rift West Abundant Forest*, *Finite Island Overcrowded Extraction*, *Darwin Open Land Bridge*, *Rift East Seasonal Savanna*) improved from collapsed `dec-cooperate-store` everywhere to **100% alignment with each scenario's scientific hypothesis**.
- **Alternatives Considered**:
  - *Multi-deme single `/v1/systemone` batch request*: Tested empirically and rejected because `ollama.systemone` repeats `criteria` per question key; batching 10 demes in one request exceeded the model's `num_ctx = 4096` window (`ResponseError: status_code 400`).
  - *Keeping raw `DemeDecisionEvaluationInput` JSON in `state`*: Rejected because `d3:4b` lacks the engine's internal demand/competition equations and wastes >300 tokens per call on internal IDs and redundant prose.

## 2. Intra-Turn Cognitive Evaluation Deduplication (`DemeEvaluationSignature`)

- **Decision**: Compute a deterministic per-turn equivalence signature (`computeDemeEvaluationSignature(input)`) in `src/ai/ollamaSystemOne.ts` and use it in `src/engine/turnEngine.ts` to bucket demes sharing the same biome, season, discretized resource-to-demand tier, habitat health tier, cohabitation profile, sorted active trait IDs, prior dominant decision, and top passable neighbor biome/opportunity profile. Within a single generational turn, demes with an identical signature reuse the first evaluated probability distribution (while still building their own deme-specific localized `justification` string).
- **Rationale**: In mid-to-late generations ($G_{10}\text{--}G_{30}$), multiple demes of the same lineage occupy adjacent hexes of the same biome with identical traits and resource bands. Intra-turn signature deduplication eliminates 40%–70% of redundant HTTP calls to Ollama without introducing cross-turn staleness or breaking determinism.
- **Alternatives Considered**:
  - *Cross-turn global LRU cache*: Rejected per KISS & YAGNI because seasonal flips and user brush interventions change world context between turns, whereas an intra-turn `Map<string, DemeDecisionEvaluationOutput>` is stateless, ~15 lines of code, and always fresh.

## 3. Intentional Migratory Fission & Intra-Lineage Cohesion Thresholds

- **Decision**: Refine the demographic fission and merging thresholds in `src/engine/biophysicalPhase.ts`:
  1. **Intentional Fission Gate**: Require `pMigrate >= 0.20` OR `deme.lastDominantDecisionId === "dec-selective-migration"` OR `isEmergencyEvacuation` (`currentCell.currentResources < deme.population * 0.20`) before splitting off a migrant daughter deme (in addition to `migrants >= 10` and `deme.population - migrants >= 10`).
  2. **Intra-Lineage Cohesion Merge (`< 0.25`)**: Relax same-lineage cohabitation merging and redundant neighbor colonization blocking from `computeDemeDivergence(demeA, demeB) < 0.10` to `< 0.25` so that demes of the same lineage differing by at most 1 trait out of 5 consolidate instead of fragmenting into 3 permanent sub-clans per hex.
- **Rationale**: Previously, a stationary deme with `population = 230` and `pMigrate = 0.10` spawned a new daughter deme every single turn (`230 * 0.10 * 0.45 = 10`), and a single Baldwin trait (`divergence = 0.20–0.33`) prevented same-lineage demes from ever merging again, causing deme counts to balloon to 35–60+.
- **Alternatives Considered**:
  - *Hard global cap on total demes (e.g., max 10 demes on the map)*: Rejected because it artificially blocks island colonization on large maps; gating fission on actual migration intent (`pMigrate >= 0.20` or emergency) solves the root cause naturally.

## 4. System 2 (`gemma4:e4b-it-qat`) Milestone Pacing, Causal Context & Concise Generation

- **Decision**:
  1. **One Milestone Synthesis Per Turn & Per-Deme Deduplication**: In `src/engine/milestonePhase.ts` (`detectEvolutionaryMilestones`), emit at most 1 milestone candidate per deme (prioritizing `allopatric_speciation` > `baldwin_assimilation` > `cultural_innovation`), and in `src/engine/turnEngine.ts`, process at most **1 milestone synthesis per generational turn** (`slice(0, 1)` instead of `slice(0, 3)`). Remaining eligible demes retain their counters and naturally synthesize on subsequent turns.
  2. **Enriched Causal Context & Duplicate Prevention**: Extend `MilestoneSynthesisInput` with optional ecological/historical context (`energyReserves`, `lastEnergyDelta`, `season`, `currentResources`, `carryingCapacity`, `carryingCapacityMax`, `globalEmergentTraitNames`, `recentChronicleTitles`) so `gemma4:e4b-it-qat` grounds the trait in actual survival pressures and avoids duplicating existing trait names.
  3. **Concise Output Budget (`numPredict: 260`) & Schema Simplification**: Configure `ChatOllama` in `src/ai/langchainSystemTwo.ts` with `numPredict: 260`, `temperature: 0.35`, and explicit 1–2 sentence length instructions (keeping default `numCtx` so Ollama never reloads the runner in VRAM).
- **Empirical Benchmark (Live `gemma4:e4b-it-qat` on RTX 5060 Ti)**:
  - Single warm synthesis dropped from **~9,890–10,217 ms → ~3,260 ms** (**~67% reduction**).
  - Maximum System 2 turn pause dropped from **3 × 10s = 30s → 1 × 3.3s = 3.3s** (**~9× faster milestone turns**).

## 5. Fast Turn Persistence (`saveWorldToLocalStorage`)

- **Decision**: In `src/store/persistence.ts`, use direct compact serialization (`JSON.stringify(world)`) inside `saveWorldToLocalStorage(world)` during generational turns while preserving full `WorldStateSchema.parse(world)` validation in `serializeWorldState(world)` (export) and `deserializeWorldState(jsonPayload)` (import / initial load).
- **Rationale**: Eliminates redundant per-turn Zod `.superRefine` traversal across 91 cells, all demes, and the growing chronicle on every single step.
