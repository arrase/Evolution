import { z } from "zod";

export const SUPPORTED_LOCALES = ["en", "es", "zh", "fr", "de", "pt", "ja", "ru"] as const;
export const SupportedLocaleSchema = z.enum(SUPPORTED_LOCALES);
export type SupportedLocale = z.infer<typeof SupportedLocaleSchema>;
export const DEFAULT_LOCALE: SupportedLocale = "en";

export const BiophysicalVectorSchema = z.object({
  metabolicCost: z.number().min(-1.0).max(1.0),
  extractionEfficiency: z.number().min(-1.0).max(1.0),
  ecologicalImpact: z.number().min(-1.0).max(1.0),
  spatialMobility: z.number().min(-1.0).max(1.0),
  socialCohesion: z.number().min(-1.0).max(1.0),
  transmissionThreshold: z.number().min(0.0).max(1.0)
});
export type BiophysicalVector = z.infer<typeof BiophysicalVectorSchema>;

export const TraitCategorySchema = z.enum(["biological", "cultural"]);
export type TraitCategory = z.infer<typeof TraitCategorySchema>;

export const TraitOriginSchema = z.enum(["base", "user", "emergent"]);
export type TraitOrigin = z.infer<typeof TraitOriginSchema>;

export const TraitDefinitionSchema = z.object({
  id: z.string().regex(/^[a-z0-9-]+$/),
  name: z.string().min(1).max(60),
  category: TraitCategorySchema,
  semanticDescriptor: z.string().min(10).max(300),
  affinityCondition: z.string().min(5).max(200),
  mutuallyExclusiveWith: z.array(z.string()),
  enablesCulturalTransmission: z.boolean(),
  biophysicalVector: BiophysicalVectorSchema,
  origin: TraitOriginSchema,
  freeSandboxMode: z.boolean()
});
export type TraitDefinition = z.infer<typeof TraitDefinitionSchema>;

export const DecisionArchetypeSchema = z.enum([
  "forage",
  "overexploit",
  "migrate",
  "cooperate",
  "exchange",
  "dispute",
  "innovate",
  "custom"
]);
export type DecisionArchetype = z.infer<typeof DecisionArchetypeSchema>;

export const DecisionOriginSchema = z.enum(["base", "user"]);
export type DecisionOrigin = z.infer<typeof DecisionOriginSchema>;

export const DecisionDefinitionSchema = z.object({
  id: z.string().regex(/^[a-z0-9-]+$/),
  name: z.string().min(1).max(60),
  archetype: DecisionArchetypeSchema,
  semanticDescriptor: z.string().min(10).max(300),
  requiredTraitIds: z.array(z.string()),
  biophysicalVector: BiophysicalVectorSchema,
  origin: DecisionOriginSchema,
  freeSandboxMode: z.boolean()
});
export type DecisionDefinition = z.infer<typeof DecisionDefinitionSchema>;

export const BiomeTypeSchema = z.enum([
  "tropical_forest",
  "savanna",
  "arid_steppe",
  "tundra",
  "high_mountain",
  "coastal_shallows",
  "ocean"
]);
export type BiomeType = z.infer<typeof BiomeTypeSchema>;

export const HexCellSchema = z
  .object({
    id: z.string().regex(/^-?\d+,-?\d+$/),
    q: z.number().int().min(-7).max(7),
    r: z.number().int().min(-7).max(7),
    biome: BiomeTypeSchema,
    temperature: z.number().min(-1.0).max(1.0),
    humidity: z.number().min(0.0).max(1.0),
    altitude: z.number().min(0.0).max(1.0),
    currentResources: z.number().min(0),
    carryingCapacity: z.number().min(10),
    carryingCapacityMax: z.number().min(50).max(2000),
    seasonalRegenRate: z.number().min(0.02).max(0.50),
    demeIds: z.array(z.string()).max(3)
  })
  .superRefine((cell, ctx) => {
    if (cell.carryingCapacity > cell.carryingCapacityMax) {
      ctx.addIssue({
        code: "custom",
        path: ["carryingCapacity"],
        message: "carryingCapacity cannot exceed carryingCapacityMax"
      });
    }
    if (cell.currentResources > cell.carryingCapacityMax * 1.5) {
      ctx.addIssue({
        code: "custom",
        path: ["currentResources"],
        message: "currentResources cannot exceed carryingCapacityMax * 1.5"
      });
    }
  });
export type HexCell = z.infer<typeof HexCellSchema>;

export const DemeSchema = z
  .object({
    id: z.string().min(1),
    name: z.string().min(1).max(60),
    lineageId: z.string().min(1),
    color: z.string().regex(/^#[0-9A-Fa-f]{6}$/),
    hexId: z.string().regex(/^-?\d+,-?\d+$/),
    population: z.number().int().min(10),
    energyReserves: z.number().min(0),
    lastEnergyDelta: z.number(),
    biologicalTraitIds: z.array(z.string()),
    culturalTraitIds: z.array(z.string()),
    baldwinCounters: z.record(z.string(), z.number().int().min(0)),
    innovationCounter: z.number().min(0.0).max(2.0),
    isolationTurns: z.number().int().min(0),
    lastDecisionProbabilities: z.record(z.string(), z.number().min(0).max(1)),
    lastDominantDecisionId: z.string().min(1),
    lastJustification: z.string().min(1)
  })
  .superRefine((deme, ctx) => {
    const probs = Object.values(deme.lastDecisionProbabilities);
    if (probs.length === 0) {
      ctx.addIssue({
        code: "custom",
        path: ["lastDecisionProbabilities"],
        message: "lastDecisionProbabilities cannot be empty"
      });
      return;
    }
    const sum = probs.reduce((acc, p) => acc + p, 0);
    if (Math.abs(sum - 1.0) > 1e-3) {
      ctx.addIssue({
        code: "custom",
        path: ["lastDecisionProbabilities"],
        message: `Decision probabilities must sum to 1.0 (got ${sum})`
      });
    }
  });
export type Deme = z.infer<typeof DemeSchema>;

export const DivergenceReasonSchema = z.enum([
  "initial",
  "allopatric_speciation",
  "cultural_schism",
  "baldwin_assimilation"
]);
export type DivergenceReason = z.infer<typeof DivergenceReasonSchema>;

export const LineageNodeSchema = z.object({
  id: z.string().min(1),
  parentId: z.string().nullable(),
  name: z.string().min(1),
  color: z.string().regex(/^#[0-9A-Fa-f]{6}$/),
  foundedGeneration: z.number().int().min(0),
  extinctGeneration: z.number().int().min(0).nullable(),
  founderHexId: z.string().regex(/^-?\d+,-?\d+$/),
  acquiredTraitIds: z.array(z.string()),
  divergenceReason: DivergenceReasonSchema
});
export type LineageNode = z.infer<typeof LineageNodeSchema>;

export const ChronicleEntryTypeSchema = z.enum([
  "baldwin_trait",
  "cultural_innovation",
  "allopatric_speciation",
  "cultural_loss",
  "extinction",
  "tragedy_of_commons",
  "symbiosis",
  "single_survivor",
  "ecological_equilibrium"
]);
export type ChronicleEntryType = z.infer<typeof ChronicleEntryTypeSchema>;

export const ChronicleEntrySchema = z.object({
  id: z.string().min(1),
  generation: z.number().int().min(0),
  type: ChronicleEntryTypeSchema,
  title: z.string().min(1),
  body: z.string().min(1),
  demeId: z.string().min(1),
  lineageId: z.string().min(1),
  hexId: z.string().regex(/^-?\d+,-?\d+$/)
});
export type ChronicleEntry = z.infer<typeof ChronicleEntrySchema>;

export const HexEdgeFlowTypeSchema = z.enum(["migration", "exchange", "dispute"]);
export type HexEdgeFlowType = z.infer<typeof HexEdgeFlowTypeSchema>;

export const HexEdgeFlowSchema = z.object({
  fromHexId: z.string().regex(/^-?\d+,-?\d+$/),
  toHexId: z.string().regex(/^-?\d+,-?\d+$/),
  demeId: z.string().min(1),
  targetDemeId: z.string().min(1).optional(),
  color: z.string().regex(/^#[0-9A-Fa-f]{6}$/),
  type: HexEdgeFlowTypeSchema,
  intensity: z.number().min(0.05).max(1.0)
});
export type HexEdgeFlow = z.infer<typeof HexEdgeFlowSchema>;

export const SeasonTypeSchema = z.enum(["wet_warm", "dry_cold"]);
export type SeasonType = z.infer<typeof SeasonTypeSchema>;

export const WorldStateSchema = z.object({
  presetId: z.string().min(1),
  generation: z.number().int().min(0),
  season: SeasonTypeSchema,
  seaLevel: z.number().min(0.0).max(0.50),
  selectivePressurePoints: z.number().int().min(0),
  selectivePressureRegenPerTurn: z.number().int().min(0),
  unlimitedPressureMode: z.boolean(),
  autoPauseOnMilestone: z.boolean(),
  quietTurns: z.number().int().min(0).optional(),
  mapRadius: z.number().int().min(4).max(7),
  cells: z.record(z.string(), HexCellSchema),
  demes: z.record(z.string(), DemeSchema),
  traitsCatalog: z.record(z.string(), TraitDefinitionSchema),
  decisionsCatalog: z.record(z.string(), DecisionDefinitionSchema),
  lineageTree: z.record(z.string(), LineageNodeSchema),
  chronicle: z.array(ChronicleEntrySchema),
  currentTurnFlows: z.array(HexEdgeFlowSchema)
});
export type WorldState = z.infer<typeof WorldStateSchema>;

export interface PresetScenario {
  id: string;
  name: string;
  description: string;
  scientificHypothesis: string;
  glacialSeaLevelCycle: boolean;
  createInitialWorld: () => WorldState;
}

export interface OllamaStatusReport {
  connected: boolean;
  host: string;
  systemOneModelReady: boolean;
  resolvedSystemOneTag: string;
  secondarySystemOneModelReady?: boolean;
  resolvedSecondarySystemOneTag?: string;
  systemTwoModelReady: boolean;
  resolvedSystemTwoTag: string;
  missingCommands: string[];
}

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
    decisionModelTag?: string;
    lastDominantDecisionId?: string;
    baldwinProgress?: number;
    innovationProgress?: number;
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
    totalCellPopulation?: number;
    rivalDemesCount?: number;
    kinDemesCount?: number;
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
    totalPopulation?: number;
    isPassable: boolean;
  }>;
  eligibleDecisions: Array<{
    id: string;
    name: string;
    semanticDescriptor: string;
    archetype?: DecisionArchetype;
    biophysicalVector?: BiophysicalVector;
  }>;
}

export interface DemeDecisionEvaluationOutput {
  probabilities: Record<string, number>;
  dominantDecisionId: string;
  confidence: number;
  justification: string;
}

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

export const SynthesizedTraitProposalSchema = z.object({
  name: z.string().min(1).max(60),
  category: TraitCategorySchema,
  semanticDescriptor: z.string().min(10).max(300),
  affinityCondition: z.string().min(5).max(200),
  biophysicalVector: BiophysicalVectorSchema,
  chronicleTitle: z.string().min(1),
  chronicleBody: z.string().min(1)
});
export type SynthesizedTraitProposal = z.infer<typeof SynthesizedTraitProposalSchema>;

export interface UserCoDesignInput {
  locale: SupportedLocale;
  userConcept: string;
  targetType: "biological_trait" | "cultural_trait" | "decision";
}

export const UserCoDesignOutputSchema = z.object({
  name: z.string().min(1).max(60),
  semanticDescriptor: z.string().min(10).max(300),
  affinityCondition: z.string().min(5).max(200),
  archetype: DecisionArchetypeSchema,
  biophysicalVector: BiophysicalVectorSchema
});
export type UserCoDesignOutput = z.infer<typeof UserCoDesignOutputSchema>;

export interface CognitiveProvider {
  checkStatus(): Promise<OllamaStatusReport>;
  evaluateDemeDecisions(input: DemeDecisionEvaluationInput): Promise<DemeDecisionEvaluationOutput>;
  synthesizeMilestone(input: MilestoneSynthesisInput): Promise<SynthesizedTraitProposal>;
  coDesignCatalogItem(input: UserCoDesignInput): Promise<UserCoDesignOutput>;
}

export type PlaybackMode =
  | "paused"
  | "stepping"
  | "playing_normal"
  | "playing_fast"
  | "milestone_paused"
  | "error_paused";

export type BrushTool =
  | { kind: "inspect" }
  | { kind: "set_biome"; biome: BiomeType; radius: 1 | 2; cost: number }
  | { kind: "adjust_altitude"; delta: number; radius: 1 | 2; cost: number }
  | { kind: "adjust_carrying_capacity"; deltaFactor: number; radius: 1 | 2; cost: number };

export interface SimulationStore {
  locale: SupportedLocale;
  world: WorldState;
  playbackMode: PlaybackMode;
  selectedHexId: string | null;
  selectedDemeId: string | null;
  activeBrush: BrushTool;
  activeModal: "none" | "welcome" | "catalog_lab" | "phylo_tree" | "naturalist_notebook" | "ollama_diagnostics";
  highlightedLineageId: string | null;
  latestMilestoneChronicle: ChronicleEntry | null;
  ollamaStatus: OllamaStatusReport | null;
  lastError: string | null;

  setLocale: (locale: SupportedLocale) => void;
  loadPreset: (presetId: string) => void;
  stepGeneration: () => Promise<void>;
  setPlaybackMode: (mode: PlaybackMode) => void;
  toggleAutoPauseOnMilestone: () => void;
  toggleUnlimitedPressure: () => void;
  selectHex: (hexId: string) => void;
  selectDeme: (demeId: string) => void;
  setActiveBrush: (brush: BrushTool) => void;
  applyBrushToHex: (hexId: string) => void;
  upsertTrait: (trait: TraitDefinition) => void;
  upsertDecision: (decision: DecisionDefinition) => void;
  injectTraitIntoDeme: (demeId: string, traitId: string) => void;
  exportWorldJson: () => string;
  importWorldJson: (jsonPayload: string) => void;
  refreshOllamaStatus: () => Promise<void>;
}
