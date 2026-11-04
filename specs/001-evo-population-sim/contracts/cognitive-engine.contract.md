# Contract: Dual Cognitive Engine (`d3` + `gemma4:e4b-it-qat`)

**Feature**: `001-evo-population-sim`
**Module**: `src/ai/cognitiveProvider.ts`, `src/ai/ollamaSystemOne.ts`, `src/ai/langchainSystemTwo.ts`
**Requirements Covered**: `FR-006`, `FR-012`, `FR-013`, `FR-015`, `SC-002`..`SC-006`

## 1. Interfaz Desacoplada del Proveedor Cognitivo (`CognitiveProvider`)

Para cumplir con el mandato constitucional **Deterministic Core Testability**, toda comunicación con Ollama se realiza a través de la interfaz `CognitiveProvider`:

```typescript
export type SupportedLocale = "en" | "es" | "zh" | "fr" | "de" | "pt" | "ja" | "ru";

export interface OllamaStatusReport {
  connected: boolean;
  host: string;
  systemOneModelReady: boolean;
  resolvedSystemOneTag: string; // e.g., "d3:4b"
  systemTwoModelReady: boolean;
  resolvedSystemTwoTag: string; // e.g., "gemma4:e4b-it-qat"
  missingCommands: string[];    // e.g., ["ollama pull d3:4b", "ollama pull gemma4:e4b-it-qat"]
}

export interface DemeDecisionEvaluationInput {
  locale: SupportedLocale;      // Default: "en"
  generation: number;
  season: "wet_warm" | "dry_cold";
  deme: {
    id: string;
    name: string;
    population: number;
    energyReserves: number;
    lastEnergyDelta: number;
    activeBiologicalTraits: Array<{ id: string; name: string; semanticDescriptor: string; affinityCondition: string }>;
    activeCulturalTraits: Array<{ id: string; name: string; semanticDescriptor: string; affinityCondition: string }>;
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
    isPassable: boolean;
  }>;
  eligibleDecisions: Array<{
    id: string;
    name: string;
    semanticDescriptor: string;
  }>;
}

export interface DemeDecisionEvaluationOutput {
  probabilities: Record<string, number>; // Normalizado: sum(P_i) === 1.0
  dominantDecisionId: string;
  confidence: number;
  justification: string;
}

export interface MilestoneSynthesisInput {
  locale: SupportedLocale;      // Default: "en" (System 2 generates name, descriptors, and chronicle in this language)
  triggerType: "baldwin_assimilation" | "cultural_innovation" | "allopatric_speciation";
  generation: number;
  deme: {
    id: string;
    name: string;
    population: number;
    dominantDecisionName: string;
    existingTraitNames: string[];
  };
  cell: {
    biome: string;
    temperature: number;
    humidity: number;
    altitude: number;
  };
}

export interface SynthesizedTraitProposal {
  name: string;
  category: "biological" | "cultural";
  semanticDescriptor: string;
  affinityCondition: string;
  biophysicalVector: BiophysicalVector;
  chronicleTitle: string;
  chronicleBody: string;
}

export interface UserCoDesignInput {
  locale: SupportedLocale;      // Default: "en"
  userConcept: string;
  targetType: "biological_trait" | "cultural_trait" | "decision";
}

export interface UserCoDesignOutput {
  name: string;
  semanticDescriptor: string;
  affinityCondition: string;
  archetype: DecisionDefinition["archetype"];
  biophysicalVector: BiophysicalVector;
}

export interface CognitiveProvider {
  checkStatus(): Promise<OllamaStatusReport>;
  evaluateDemeDecisions(input: DemeDecisionEvaluationInput): Promise<DemeDecisionEvaluationOutput>;
  synthesizeMilestone(input: MilestoneSynthesisInput): Promise<SynthesizedTraitProposal>;
  coDesignCatalogItem(input: UserCoDesignInput): Promise<UserCoDesignOutput>;
}
```

---

## 2. Contrato de Ejecución del Sistema 1 (`d3:4b` via `ollama/browser`)

- **Endpoint SDK**: `ollamaClient.systemone(request)` sobre `http://127.0.0.1:11434`.
- **Timeout por turno**: `5000 ms` mediante `AbortSignal.timeout(5000)`.
- **Normalización Garantizada**: Las probabilidades devueltas por `answer.probabilities` para las decisiones elegibles se normalizan dividiendo cada $P_i$ por $\sum P_i$ (con redondeo a 4 decimales y ajuste del residuo en la decisión dominante para garantizar $\sum P_i === 1.0$).
- **Generación de Justificación (`SC-003`)**: Se construye una cadena determinista a partir del estado evaluado:
  `"[Bioma: ${biome} | Recursos: ${currentResources}/${carryingCapacity} | Rasgos clave: ${traitNames}] → Decisión dominante: ${dominantDecisionName} (${(maxP * 100).toFixed(1)}%, confianza ${(confidence * 100).toFixed(0)}%)"`.

---

## 3. Contrato de Ejecución del Sistema 2 (`gemma4:e4b-it-qat` via `@langchain/ollama`)

- **Configuración de `ChatOllama`**:
  - `model: "gemma4:e4b-it-qat"`
  - `baseUrl: "http://127.0.0.1:11434"`
  - `temperature: 0.4`
  - `think: false` (obligatorio para desactivar trazas de pensamiento internas y responder en ~2.5 s)
  - `keepAlive: "30m"`
- **Timeout por operación**: `15000 ms`.
- **Post-Procesado Termodinámico Obligatorio**: Todo `biophysicalVector` devuelto por `gemma4:e4b-it-qat` en `synthesizeMilestone` o `coDesignCatalogItem` pasa inmediatamente por `validateAndBalanceThermodynamics(vector, false)` antes de entregarse al motor o al editor de la UI, garantizando el cumplimiento del 100% de `SC-005`.

---

## 4. Manejo de Errores y Fail-Safe (`Edge Case 2`)

Si `evaluateDemeDecisions` o `synthesizeMilestone` lanza un error de red, timeout o modelo no encontrado:
1. El error se propaga al controlador de turno antes de aplicar cambios sobre `WorldState`.
2. El store cambia a estado `playbackMode = "error_paused"` y almacena el `OllamaStatusReport` actualizado para mostrar el modal de diagnóstico con el botón `Reintentar Turno`.
