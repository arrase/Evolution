# Contract: Enriched Compact Cognitive Context & Turn Pacing (`003-ollama-perf-context`)

**Feature**: `003-ollama-perf-context`  
**Modules**: `src/ai/ollamaSystemOne.ts`, `src/ai/langchainSystemTwo.ts`, `src/engine/turnEngine.ts`, `src/engine/biophysicalPhase.ts`, `src/engine/milestonePhase.ts`, `src/store/persistence.ts`  
**Requirements Covered**: `FR-001`..`FR-007`, `SC-001`..`SC-004`

---

## 1. Compact System 1 State & Criteria Builder (`src/ai/ollamaSystemOne.ts`)

### `buildCompactSystemOneState(input: DemeDecisionEvaluationInput): string`
Builds a single high-signal text block (`~140–190 tokens`, reducing total `input_tokens` from `~662` to `~300–350`) containing:
1. **Habitat & Season Line**: Biome, season, temperature, humidity, current resources vs carrying capacity, habitat health percentage ($K / K_{\max}$), and `resourceAdequacyRatio` ($\text{resources} / \max(10, \text{totalCellPopulation} \times 0.48)$).
2. **Deme & Competition Line**: Population, vital status (`thriving` | `stable` | `struggling` | `starving`), energy reserves, `lastEnergyDelta`, cohabiting rival count, cohabiting kin count, and `totalCellPopulation`.
3. **Active Traits Line**: Trait names paired with concise biophysical highlights (e.g. `[extract:+0.65, eco:-0.25]`) and core affinity cues, omitting internal IDs and verbose prose.
4. **Adaptive Momentum & Passable Neighbors Line**: `lastDominantDecisionId`, active Baldwin/Innovation progress, and top passable neighbor cells sorted by per-capita resource opportunity (highlighting uninhabited `coastal_shallows` land bridges and richer frontiers).
5. **Synthesized Ecological Pressure Cue**: A deterministic 1-sentence situational summary derived from the deme's vital/ecological metrics (e.g., open land bridge colonization opportunity, multi-clan extraction pressure, abundant stable canopy, or seasonal savanna aridity).

### `buildCompactDecisionCriteria(eligibleDecisions: DemeDecisionEvaluationInput["eligibleDecisions"]): Record<string, string>`
Maps each eligible decision ID to a concise 1-line descriptor (`<= 120 chars`) combining its core behavioral intent and key biophysical vector trade-offs.

### `computeDemeEvaluationSignature(input: DemeDecisionEvaluationInput): string`
Returns a deterministic equivalence key for intra-turn deduplication so demes with identical ecological/competitive/trait buckets in the same generation share a single System 1 evaluation while receiving their own localized `buildContextualJustification(...)` string.

---

## 2. Generational Turn Orchestration & Milestone Pacing (`src/engine/turnEngine.ts` & `src/engine/milestonePhase.ts`)

1. **Intra-Turn Deduplication & Localized Justification (`U1`)**:
   - `executeGenerationalTurn` maintains a per-turn `Map<string, DemeDecisionEvaluationOutput>` keyed by `computeDemeEvaluationSignature(evaluationInput)`.
   - On a cache hit within the same turn, `probabilities` (`{ ...cached.probabilities }`), `dominantDecisionId`, and `confidence` are reused and `justification` is freshly formatted with the target deme's exact resource/trait labels via `buildContextualJustification(evaluationInput, cached.dominantDecisionId, cached.probabilities[cached.dominantDecisionId]!, cached.confidence)`.
2. **Single-Milestone Turn Cap & Unit Test Compatibility (`I1`)**:
   - `detectEvolutionaryMilestones` continues returning all eligible milestone candidates across demes (preserving 100% compatibility with unit tests that inspect all simultaneous milestone triggers on a deme), enriched with causal context fields.
   - `executeGenerationalTurn` sorts detected candidates by evolutionary priority (`allopatric_speciation` > `baldwin_assimilation` > `cultural_innovation`), deduplicates at most 1 candidate per `deme.id`, and processes `.slice(0, 1)` milestone synthesis per turn (instead of `.slice(0, 3)`), preventing multi-call System 2 pauses while preserving remaining demes' counters for subsequent turns.

---

## 3. Intentional Migratory Fission & Intra-Lineage Cohesion (`src/engine/biophysicalPhase.ts`)

1. **Intentional Fission Gate (`FR-004`, `I2`)**:
   - A deme with `population >= 20` and `migrants >= 10` (`deme.population - migrants >= 10`) only splits off a daughter deme if:
     - `pMigrate >= 0.15`, OR
     - `deme.lastDominantDecisionId === "dec-selective-migration"`, OR
     - `currentCell.biome === "coastal_shallows"` (active land-bridge transit toward uninhabited island hexes), OR
     - `isEmergencyEvacuation` (`currentCell.currentResources < deme.population * 0.20`).
   - Stationary forest and island demes with low migration probability (`pMigrate <= 0.12`) and non-emergency resources remain cohesive without spawning daughter demes every turn.
2. **Intra-Lineage Cohesion Threshold (`< 0.25`)**:
   - Same-lineage demes cohabiting in the same hex merge when `computeDemeDivergence(demeA, demeB) < 0.25` (and non-emergency migration avoids invading neighbor cells already occupied by a same-lineage deme with divergence `< 0.25`).

---

## 4. Concise & Enriched System 2 Synthesis (`src/ai/langchainSystemTwo.ts`)

- `ChatOllama` is configured with `temperature: 0.35`, `think: false`, `numPredict: 260`, `keepAlive: "30m"`.
- Prompt includes causal context (`energyReserves`, `lastEnergyDelta`, `season`, `currentResources / carryingCapacity`, `globalEmergentTraitNames` to forbid duplicates, and `recentChronicleTitles`) and strict conciseness rules (`semanticDescriptor <= 150 chars`, `affinityCondition <= 100 chars`, `chronicleBody <= 180 chars`).
