# Data Model: Optimización de Velocidad por Turno y Enriquecimiento del Contexto Cognitivo de Decisión

**Feature**: `003-ollama-perf-context`  
**Date**: 2026-11-04

## 1. Extended `DemeDecisionEvaluationInput` (`src/types/simulation.ts`)

To provide System 1 (`d3:4b`) with biophysical vectors, competitive pressure, and behavioral momentum while maintaining 100% backward compatibility with existing unit and contract tests, `DemeDecisionEvaluationInput` is extended with optional enriched fields (always populated by `executeGenerationalTurn` in `src/engine/turnEngine.ts`):

```typescript
export interface DemeDecisionEvaluationInput {
  locale: SupportedLocale;
  generation: number;
  season: SeasonType;
  deme: {
    id: string;
    name: string;
    population: number;
    energyReserves: number;
    lastEnergyDelta: number;
    lastDominantDecisionId?: string;
    baldwinProgress?: number;      // Max active Baldwin counter (0..8)
    innovationProgress?: number;   // Active cultural innovation counter (0.0..2.0)
    activeBiologicalTraits: Array<{
      id: string;
      name: string;
      semanticDescriptor: string;
      affinityCondition: string;
      biophysicalVector?: BiophysicalVector;
    }>;
    activeCulturalTraits: Array<{
      id: string;
      name: string;
      semanticDescriptor: string;
      affinityCondition: string;
      biophysicalVector?: BiophysicalVector;
    }>;
  };
  currentCell: {
    id: string;
    biome: string;
    temperature: number;
    humidity: number;
    altitude: number;
    currentResources: number;
    carryingCapacity: number;
    carryingCapacityMax: number;
    cohabitingDemesCount: number;
    totalCellPopulation?: number;  // Sum of populations of all demes in currentCell
    rivalDemesCount?: number;      // Count of cohabiting demes with a different lineageId
    kinDemesCount?: number;        // Count of cohabiting demes with the same lineageId
  };
  neighborCells: Array<{
    id: string;
    biome: string;
    temperature: number;
    humidity: number;
    altitude: number;
    currentResources: number;
    carryingCapacity: number;
    demesCount: number;
    totalPopulation?: number;      // Sum of populations of demes in neighbor cell
    isPassable: boolean;
  }>;
  eligibleDecisions: Array<{
    id: string;
    name: string;
    archetype?: DecisionArchetype;
    semanticDescriptor: string;
    biophysicalVector?: BiophysicalVector;
  }>;
}
```

### Validation & Derivation Rules
- `totalCellPopulation`: Sum of `deme.population` for all `demeIds` in `currentCell` ($\ge \text{deme.population}$).
- `rivalDemesCount`: Count of other demes in `currentCell` where `other.lineageId !== deme.lineageId`.
- `kinDemesCount`: Count of other demes in `currentCell` where `other.lineageId === deme.lineageId`.
- `resourceAdequacyRatio` (computed in `buildCompactSystemOneState`):
  $$\text{resourceAdequacyRatio} = \frac{\text{currentCell.currentResources}}{\max(10, \text{totalCellPopulation} \times 0.48)}$$

---

## 2. Intra-Turn Equivalence Signature (`DemeEvaluationSignature`)

Computed by `computeDemeEvaluationSignature(input: DemeDecisionEvaluationInput): string` in `src/ai/ollamaSystemOne.ts` (and consumed in `src/engine/turnEngine.ts`):

| Component | Discretization / Format | Purpose |
| :--- | :--- | :--- |
| `season` | `"wet_warm"` \| `"dry_cold"` | Captures seasonal climate state |
| `biome` | `currentCell.biome` | Primary habitat classification |
| `adequacyTier` | `Math.min(6, Math.floor(resourceAdequacyRatio * 2))` | Buckets resource-to-demand ratio into 0.5x bands |
| `healthTier` | `Math.floor((carryingCapacity / carryingCapacityMax) * 4)` | Buckets habitat health ($K / K_{\max}$) into quartiles |
| `vitality` | `"thriving"` \| `"stable"` \| `"struggling"` \| `"starving"` | Captures deme energy reserve & delta status |
| `competitionKey` | `${rivalDemesCount}:${kinDemesCount}:${deme.population >= 40 ? "viable" : "small"}` | Distinguishes solitary, kin-shared, and rival-crowded cells |
| `traitsKey` | Sorted `[...bioIds, ...culturalIds].join(",")` | Exact adaptive repertoire |
| `dominantKey` | `deme.lastDominantDecisionId ?? ""` | Preserves behavioral momentum |
| `neighborKey` | Top 2 passable neighbors sorted by per-capita resources (`${biome}:${demesCount === 0 ? "empty" : "occupied"}:${Math.round(currentResources / 100)}`) | Captures open land bridges and frontier opportunities |

---

## 3. Extended `MilestoneSynthesisInput` (`src/types/simulation.ts`)

Extended with optional causal and anti-duplication fields populated by `detectEvolutionaryMilestones` (`src/engine/milestonePhase.ts`) and `executeGenerationalTurn` (`src/engine/turnEngine.ts`):

```typescript
export interface MilestoneSynthesisInput {
  locale: SupportedLocale;
  triggerType: "baldwin_assimilation" | "cultural_innovation" | "allopatric_speciation";
  generation: number;
  season?: SeasonType;
  triggeredByDecisionId?: string;
  deme: {
    id: string;
    name: string;
    population: number;
    energyReserves?: number;
    lastEnergyDelta?: number;
    dominantDecisionName: string;
    existingTraitNames: string[];
  };
  cell: {
    biome: string;
    temperature: number;
    humidity: number;
    altitude: number;
    currentResources?: number;
    carryingCapacity?: number;
    carryingCapacityMax?: number;
  };
  globalEmergentTraitNames?: string[];
  recentChronicleTitles?: string[];
}
```
