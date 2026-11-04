import { create } from "zustand";
import { LiveCognitiveProvider } from "../ai/cognitiveProvider";
import { demeHasCulturalCapacity } from "../catalog/baseTraits";
import { getPresetById } from "../catalog/presets";
import { getExistingNeighborCells, getHexIdsInRadius } from "../engine/hexGrid";
import { validateAndBalanceThermodynamics } from "../engine/thermodynamics";
import { executeGenerationalTurn } from "../engine/turnEngine";
import { changeAppLocale } from "../i18n";
import {
  DEFAULT_LOCALE,
  DecisionDefinitionSchema,
  TraitDefinitionSchema,
  type BiomeType,
  type BrushTool,
  type ChronicleEntry,
  type CognitiveProvider,
  type DecisionDefinition,
  type Deme,
  type HexCell,
  type HexEdgeFlow,
  type LineageNode,
  type PlaybackMode,
  type SimulationStore,
  type SupportedLocale,
  type TraitDefinition,
  type UserCoDesignInput,
  type UserCoDesignOutput,
  type WorldState
} from "../types/simulation";
import {
  deserializeWorldState,
  loadFirstStepsDismissed,
  loadLocaleFromLocalStorage,
  loadWorldFromLocalStorage,
  saveFirstStepsDismissed,
  saveLocaleToLocalStorage,
  saveWorldToLocalStorage,
  serializeWorldState
} from "./persistence";

export type MapLens = "biome" | "food" | "health";
export type PlaybackSpeed = "normal" | "fast";

export interface FirstSteps {
  play: boolean;
  select: boolean;
  tool: boolean;
}

export type Toast =
  | { id: string; kind: "event"; entry: ChronicleEntry }
  | { id: string; kind: "error"; messageKey: string };

export const SEA_LEVEL_COST = 25;
const MAX_VISIBLE_TOASTS = 4;

export interface ExtendedSimulationStore extends SimulationStore {
  playbackSpeed: PlaybackSpeed;
  mapLens: MapLens;
  toasts: Toast[];
  chronicleSeenCount: number;
  firstSteps: FirstSteps;
  firstStepsDismissed: boolean;
  setActiveModal: (modal: SimulationStore["activeModal"]) => void;
  setHighlightedLineageId: (lineageId: string | null) => void;
  dismissMilestoneBanner: () => void;
  coDesignWithAI: (input: UserCoDesignInput) => Promise<UserCoDesignOutput>;
  togglePlayback: () => void;
  setPlaybackSpeed: (speed: PlaybackSpeed) => void;
  setMapLens: (lens: MapLens) => void;
  adjustSeaLevel: (delta: number) => void;
  dismissToast: (toastId: string) => void;
  completeFirstStep: (step: keyof FirstSteps) => void;
  dismissFirstSteps: () => void;
}

const BIOME_CLIMATE_DEFAULTS: Record<
  BiomeType,
  { temperature: number; humidity: number; minAltitude: number; maxAltitude: number }
> = {
  tropical_forest: { temperature: 0.45, humidity: 0.85, minAltitude: 0.28, maxAltitude: 0.65 },
  savanna: { temperature: 0.50, humidity: 0.40, minAltitude: 0.28, maxAltitude: 0.65 },
  arid_steppe: { temperature: 0.65, humidity: 0.20, minAltitude: 0.30, maxAltitude: 0.70 },
  tundra: { temperature: -0.55, humidity: 0.35, minAltitude: 0.35, maxAltitude: 0.74 },
  high_mountain: { temperature: -0.40, humidity: 0.25, minAltitude: 0.78, maxAltitude: 0.98 },
  coastal_shallows: { temperature: 0.20, humidity: 0.70, minAltitude: 0.14, maxAltitude: 0.24 },
  ocean: { temperature: 0.10, humidity: 0.90, minAltitude: 0.02, maxAltitude: 0.08 }
};

const MILESTONE_CHRONICLE_TYPES = new Set<ChronicleEntry["type"]>([
  "baldwin_trait",
  "cultural_innovation",
  "allopatric_speciation"
]);

const MACRO_OUTCOME_CHRONICLE_TYPES = new Set<ChronicleEntry["type"]>([
  "single_survivor",
  "ecological_equilibrium"
]);

let activeCognitiveProvider: CognitiveProvider = new LiveCognitiveProvider();
let autoPlayTimerId: ReturnType<typeof setTimeout> | null = null;
let isTurnInFlight = false;
let worldEpoch = 0;
let errorToastSeq = 0;

export function setSimulationCognitiveProvider(provider: CognitiveProvider): void {
  activeCognitiveProvider = provider;
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}

function clearAutoPlayTimer(): void {
  if (autoPlayTimerId !== null) {
    clearTimeout(autoPlayTimerId);
    autoPlayTimerId = null;
  }
}

function scheduleNextAutoPlayStep(
  mode: PlaybackMode,
  get: () => ExtendedSimulationStore
): void {
  clearAutoPlayTimer();
  if (mode !== "playing_normal" && mode !== "playing_fast") {
    return;
  }
  const intervalMs = mode === "playing_fast" ? 300 : 1500;
  autoPlayTimerId = setTimeout(() => {
    autoPlayTimerId = null;
    void get().stepGeneration();
  }, intervalMs);
}

function resolveInitialSelection(world: WorldState): {
  selectedHexId: string | null;
  selectedDemeId: string | null;
} {
  const firstDeme = Object.values(world.demes)[0];
  if (firstDeme !== undefined) {
    return {
      selectedHexId: firstDeme.hexId,
      selectedDemeId: firstDeme.id
    };
  }
  return {
    selectedHexId: "0,0" in world.cells ? "0,0" : null,
    selectedDemeId: null
  };
}

function reconcileSelection(
  world: WorldState,
  preferredHexId: string | null,
  preferredDemeId: string | null
): {
  selectedHexId: string | null;
  selectedDemeId: string | null;
} {
  if (preferredDemeId !== null && world.demes[preferredDemeId] !== undefined) {
    return {
      selectedHexId: world.demes[preferredDemeId].hexId,
      selectedDemeId: preferredDemeId
    };
  }
  if (preferredHexId !== null && world.cells[preferredHexId] !== undefined) {
    const firstInHex = world.cells[preferredHexId].demeIds[0];
    if (firstInHex !== undefined) {
      return {
        selectedHexId: preferredHexId,
        selectedDemeId: firstInHex
      };
    }
    return {
      selectedHexId: preferredHexId,
      selectedDemeId: null
    };
  }
  return resolveInitialSelection(world);
}

function displaceSubmergedDemes(
  cells: Record<string, HexCell>,
  demes: Record<string, Deme>,
  lineageTree: Record<string, LineageNode>,
  chronicle: ChronicleEntry[],
  currentTurnFlows: HexEdgeFlow[],
  generation: number
): void {
  for (const cell of Object.values(cells)) {
    if (cell.biome !== "ocean" || cell.demeIds.length === 0) {
      continue;
    }

    const residentIds = [...cell.demeIds];
    cell.demeIds = [];

    for (const demeId of residentIds) {
      const deme = demes[demeId];
      if (deme === undefined) {
        continue;
      }

      const candidates = getExistingNeighborCells(cell, cells)
        .filter((neighbor) => neighbor.biome !== "ocean" && neighbor.demeIds.length < 3)
        .sort((a, b) => b.currentResources - a.currentResources);

      const targetCell = candidates[0];
      if (targetCell !== undefined) {
        deme.hexId = targetCell.id;
        deme.energyReserves = Number((deme.energyReserves * 0.80).toFixed(2));
        targetCell.demeIds.push(deme.id);
        currentTurnFlows.push({
          fromHexId: cell.id,
          toHexId: targetCell.id,
          demeId: deme.id,
          color: deme.color,
          type: "migration",
          intensity: 0.65
        });
      } else {
        delete demes[demeId];
        chronicle.push({
          id: `chronicle-submerge-brush-${generation}-${deme.id}`,
          generation,
          type: "extinction",
          title: `${deme.name} Submerged`,
          body: `${deme.name} went extinct when cell (${cell.id}) submerged into ocean with no accessible terrestrial refuge.`,
          demeId: deme.id,
          lineageId: deme.lineageId,
          hexId: cell.id
        });

        const hasLivingRelatives = Object.values(demes).some(
          (remaining) => remaining.lineageId === deme.lineageId
        );
        const lineageNode = lineageTree[deme.lineageId];
        if (!hasLivingRelatives && lineageNode !== undefined) {
          lineageNode.extinctGeneration = generation;
        }
      }
    }
  }
}

function canAfford(world: WorldState, cost: number): boolean {
  return world.unlimitedPressureMode || world.selectivePressurePoints >= cost;
}

function editWorldTerrain(
  world: WorldState,
  cost: number,
  nextSeaLevel: number,
  editCells: (cells: Record<string, HexCell>) => void
): WorldState {
  const cells: Record<string, HexCell> = {};
  for (const [id, cell] of Object.entries(world.cells)) {
    cells[id] = {
      ...cell,
      demeIds: [...cell.demeIds]
    };
  }

  const demes: Record<string, Deme> = {};
  for (const [id, deme] of Object.entries(world.demes)) {
    demes[id] = {
      ...deme,
      biologicalTraitIds: [...deme.biologicalTraitIds],
      culturalTraitIds: [...deme.culturalTraitIds],
      baldwinCounters: { ...deme.baldwinCounters },
      lastDecisionProbabilities: { ...deme.lastDecisionProbabilities }
    };
  }

  const lineageTree: Record<string, LineageNode> = {};
  for (const [id, node] of Object.entries(world.lineageTree)) {
    lineageTree[id] = {
      ...node,
      acquiredTraitIds: [...node.acquiredTraitIds]
    };
  }

  const chronicle: ChronicleEntry[] = [...world.chronicle];
  const currentTurnFlows: HexEdgeFlow[] = [...world.currentTurnFlows];

  editCells(cells);

  displaceSubmergedDemes(
    cells,
    demes,
    lineageTree,
    chronicle,
    currentTurnFlows,
    world.generation
  );

  return {
    ...world,
    seaLevel: nextSeaLevel,
    selectivePressurePoints: world.unlimitedPressureMode
      ? world.selectivePressurePoints
      : world.selectivePressurePoints - cost,
    cells,
    demes,
    lineageTree,
    chronicle,
    currentTurnFlows
  };
}

function resolveInitialLocale(): SupportedLocale {
  if (typeof localStorage === "undefined") {
    return DEFAULT_LOCALE;
  }
  return loadLocaleFromLocalStorage();
}

function loadStoredWorld(): WorldState | null {
  if (typeof localStorage === "undefined") {
    return null;
  }
  return loadWorldFromLocalStorage();
}

function resolveInitialFirstStepsDismissed(): boolean {
  if (typeof localStorage === "undefined") {
    return true;
  }
  return loadFirstStepsDismissed();
}

function persistWorldIfAvailable(world: WorldState): void {
  if (typeof localStorage !== "undefined") {
    saveWorldToLocalStorage(world);
  }
}

function persistLocaleIfAvailable(locale: SupportedLocale): void {
  if (typeof localStorage !== "undefined") {
    saveLocaleToLocalStorage(locale);
  }
}

function persistFirstStepsDismissedIfAvailable(): void {
  if (typeof localStorage !== "undefined") {
    saveFirstStepsDismissed();
  }
}

function buildEventToasts(entries: ChronicleEntry[]): Toast[] {
  return entries
    .filter(
      (entry) =>
        !MILESTONE_CHRONICLE_TYPES.has(entry.type) &&
        !MACRO_OUTCOME_CHRONICLE_TYPES.has(entry.type)
    )
    .map((entry): Toast => ({ id: entry.id, kind: "event", entry }));
}

const initialLocale = resolveInitialLocale();
void changeAppLocale(initialLocale);
const storedWorld = loadStoredWorld();
const initialWorld =
  storedWorld !== null ? storedWorld : getPresetById("preset-rift-savanna").createInitialWorld();
const initialSelection = resolveInitialSelection(initialWorld);

export const useSimulationStore = create<ExtendedSimulationStore>((set, get) => ({
  locale: initialLocale,
  world: initialWorld,
  playbackMode: "paused",
  selectedHexId: initialSelection.selectedHexId,
  selectedDemeId: initialSelection.selectedDemeId,
  activeBrush: { kind: "inspect" },
  activeModal: storedWorld !== null ? "none" : "welcome",
  highlightedLineageId: null,
  latestMilestoneChronicle: null,
  ollamaStatus: null,
  lastError: null,
  playbackSpeed: "normal",
  mapLens: "biome",
  toasts: [],
  chronicleSeenCount: initialWorld.chronicle.length,
  firstSteps: { play: false, select: false, tool: false },
  firstStepsDismissed: resolveInitialFirstStepsDismissed(),

  setLocale: (locale: SupportedLocale) => {
    persistLocaleIfAvailable(locale);
    void changeAppLocale(locale);
    set({ locale });
  },

  loadPreset: (presetId: string) => {
    worldEpoch += 1;
    isTurnInFlight = false;
    clearAutoPlayTimer();
    const preset = getPresetById(presetId);
    const freshWorld = preset.createInitialWorld();
    persistWorldIfAvailable(freshWorld);
    const selection = resolveInitialSelection(freshWorld);
    set({
      world: freshWorld,
      playbackMode: "paused",
      selectedHexId: selection.selectedHexId,
      selectedDemeId: selection.selectedDemeId,
      highlightedLineageId: null,
      latestMilestoneChronicle: null,
      lastError: null,
      toasts: [],
      chronicleSeenCount: 0
    });
  },

  stepGeneration: async () => {
    if (isTurnInFlight) {
      return;
    }

    const turnEpoch = worldEpoch;
    const preTurnState = get();
    const wasAutoPlaying =
      preTurnState.playbackMode === "playing_normal" ||
      preTurnState.playbackMode === "playing_fast";

    if (!wasAutoPlaying) {
      set({ playbackMode: "stepping", lastError: null });
    } else {
      set({ lastError: null });
    }

    isTurnInFlight = true;
    get().completeFirstStep("play");
    const previousChronicleLength = preTurnState.world.chronicle.length;

    try {
      const nextWorld = await executeGenerationalTurn(
        preTurnState.world,
        activeCognitiveProvider,
        preTurnState.locale
      );

      if (turnEpoch !== worldEpoch) {
        return;
      }
      isTurnInFlight = false;

      const currentOllamaStatus = get().ollamaStatus;
      if (currentOllamaStatus === null || !currentOllamaStatus.connected) {
        void get().refreshOllamaStatus();
      }

      persistWorldIfAvailable(nextWorld);

      const addedChronicleEntries = nextWorld.chronicle.slice(previousChronicleLength);
      const foundMilestone = [...addedChronicleEntries]
        .reverse()
        .find((entry) => MILESTONE_CHRONICLE_TYPES.has(entry.type));
      const latestMilestone = foundMilestone !== undefined ? foundMilestone : null;
      const foundOutcome = [...addedChronicleEntries]
        .reverse()
        .find((entry) => MACRO_OUTCOME_CHRONICLE_TYPES.has(entry.type));
      const latestOutcome = foundOutcome !== undefined ? foundOutcome : null;

      let nextSelection = reconcileSelection(
        nextWorld,
        get().selectedHexId,
        get().selectedDemeId
      );
      if (nextSelection.selectedDemeId === null) {
        const firstGlobalDeme = Object.values(nextWorld.demes)[0];
        if (firstGlobalDeme !== undefined) {
          nextSelection = {
            selectedHexId: firstGlobalDeme.hexId,
            selectedDemeId: firstGlobalDeme.id
          };
        }
      }

      const allDemesExtinct = Object.keys(nextWorld.demes).length === 0;
      const shouldOutcomePause = allDemesExtinct || latestOutcome !== null;
      const shouldMilestonePause =
        latestMilestone !== null && nextWorld.autoPauseOnMilestone;

      let nextPlaybackMode: PlaybackMode = "paused";
      const currentMode = get().playbackMode;
      const isCurrentlyAutoPlaying =
        currentMode === "playing_normal" || currentMode === "playing_fast";

      if (shouldOutcomePause) {
        clearAutoPlayTimer();
        nextPlaybackMode = "paused";
      } else if (shouldMilestonePause) {
        clearAutoPlayTimer();
        nextPlaybackMode = "milestone_paused";
      } else if (isCurrentlyAutoPlaying) {
        nextPlaybackMode = currentMode;
      } else {
        clearAutoPlayTimer();
        nextPlaybackMode = "paused";
      }

      const foundTerminalExtinction = allDemesExtinct
        ? [...addedChronicleEntries].reverse().find((entry) => entry.type === "extinction")
        : undefined;
      const nextBannerChronicle =
        latestOutcome !== null
          ? latestOutcome
          : latestMilestone !== null
            ? latestMilestone
            : foundTerminalExtinction !== undefined
              ? foundTerminalExtinction
              : get().latestMilestoneChronicle;

      set({
        world: nextWorld,
        playbackMode: nextPlaybackMode,
        selectedHexId: nextSelection.selectedHexId,
        selectedDemeId: nextSelection.selectedDemeId,
        latestMilestoneChronicle: nextBannerChronicle,
        lastError: null,
        toasts: [...get().toasts, ...buildEventToasts(addedChronicleEntries)].slice(
          -MAX_VISIBLE_TOASTS
        )
      });

      if (nextPlaybackMode === "playing_normal" || nextPlaybackMode === "playing_fast") {
        scheduleNextAutoPlayStep(nextPlaybackMode, get);
      }
    } catch (error) {
      if (turnEpoch !== worldEpoch) {
        return;
      }
      isTurnInFlight = false;
      clearAutoPlayTimer();
      const message = error instanceof Error ? error.message : String(error);
      set({
        playbackMode: "error_paused",
        lastError: message,
        activeModal: "ollama_diagnostics"
      });
      await get().refreshOllamaStatus();
    }
  },

  setPlaybackMode: (mode: PlaybackMode) => {
    clearAutoPlayTimer();
    set({
      playbackMode: mode,
      lastError: mode === "error_paused" ? get().lastError : null
    });
    if (mode === "playing_normal" || mode === "playing_fast") {
      get().completeFirstStep("play");
      scheduleNextAutoPlayStep(mode, get);
    }
  },

  togglePlayback: () => {
    const { playbackMode, playbackSpeed } = get();
    const isPlaying = playbackMode === "playing_normal" || playbackMode === "playing_fast";
    if (isPlaying) {
      get().setPlaybackMode("paused");
      return;
    }
    get().setPlaybackMode(playbackSpeed === "fast" ? "playing_fast" : "playing_normal");
  },

  setPlaybackSpeed: (speed: PlaybackSpeed) => {
    const { playbackMode } = get();
    set({ playbackSpeed: speed });
    if (playbackMode === "playing_normal" || playbackMode === "playing_fast") {
      get().setPlaybackMode(speed === "fast" ? "playing_fast" : "playing_normal");
    }
  },

  toggleAutoPauseOnMilestone: () => {
    const currentWorld = get().world;
    const nextWorld: WorldState = {
      ...currentWorld,
      autoPauseOnMilestone: !currentWorld.autoPauseOnMilestone
    };
    persistWorldIfAvailable(nextWorld);
    set({ world: nextWorld });
  },

  toggleUnlimitedPressure: () => {
    const currentWorld = get().world;
    const nextWorld: WorldState = {
      ...currentWorld,
      unlimitedPressureMode: !currentWorld.unlimitedPressureMode
    };
    persistWorldIfAvailable(nextWorld);
    set({ world: nextWorld });
  },

  selectHex: (hexId: string) => {
    const { world, selectedDemeId } = get();
    const cell = world.cells[hexId];
    if (cell === undefined) {
      return;
    }

    const keepsCurrentDeme =
      selectedDemeId !== null && cell.demeIds.includes(selectedDemeId);
    const firstDemeInHex = cell.demeIds[0];

    set({
      selectedHexId: hexId,
      selectedDemeId: keepsCurrentDeme
        ? selectedDemeId
        : firstDemeInHex !== undefined
          ? firstDemeInHex
          : null
    });

    if (firstDemeInHex !== undefined) {
      get().completeFirstStep("select");
    }
  },

  selectDeme: (demeId: string) => {
    const { world } = get();
    const deme = world.demes[demeId];
    if (deme === undefined) {
      return;
    }
    set({
      selectedDemeId: deme.id,
      selectedHexId: deme.hexId
    });
    get().completeFirstStep("select");
  },

  setActiveBrush: (brush: BrushTool) => {
    set({ activeBrush: brush });
  },

  applyBrushToHex: (hexId: string) => {
    const { activeBrush, world } = get();
    if (activeBrush.kind === "inspect") {
      get().selectHex(hexId);
      return;
    }

    const centerCell = world.cells[hexId];
    if (centerCell === undefined || !canAfford(world, activeBrush.cost)) {
      return;
    }

    const seaLevel = world.seaLevel;
    const nextWorld = editWorldTerrain(world, activeBrush.cost, seaLevel, (cells) => {
      const targetHexIds = getHexIdsInRadius(
        centerCell.q,
        centerCell.r,
        activeBrush.radius,
        cells
      );

      for (const targetId of targetHexIds) {
        const target = cells[targetId];
        if (target === undefined) {
          continue;
        }

        if (activeBrush.kind === "set_biome") {
          const climate = BIOME_CLIMATE_DEFAULTS[activeBrush.biome];
          target.biome = activeBrush.biome;
          target.temperature = climate.temperature;
          target.humidity = climate.humidity;
          target.altitude = Number(
            clamp(target.altitude, climate.minAltitude, climate.maxAltitude).toFixed(2)
          );

          if (activeBrush.biome === "ocean") {
            target.currentResources = 0;
          } else {
            if (target.altitude < seaLevel) {
              target.altitude = Number(Math.min(1.0, seaLevel + 0.05).toFixed(2));
            }
            if (target.carryingCapacityMax < 120) {
              target.carryingCapacityMax = 300;
            } else if (target.carryingCapacityMax < 220) {
              target.carryingCapacityMax = 220;
            }
            if (target.carryingCapacity < 80) {
              target.carryingCapacity = Math.min(
                target.carryingCapacityMax,
                Math.max(target.carryingCapacity, 220)
              );
              target.currentResources = Math.min(target.carryingCapacity, 180);
            }
          }
        } else if (activeBrush.kind === "adjust_altitude") {
          const nextAlt = Number(clamp(target.altitude + activeBrush.delta, 0.0, 1.0).toFixed(2));
          target.altitude = nextAlt;

          if (nextAlt < seaLevel) {
            target.biome = "ocean";
            target.currentResources = 0;
          } else if (target.biome === "ocean" && nextAlt >= seaLevel) {
            target.biome = nextAlt < 0.25 ? "coastal_shallows" : "savanna";
            target.carryingCapacityMax = Math.max(200, target.carryingCapacityMax);
            target.carryingCapacity = Math.max(120, target.carryingCapacity);
            target.currentResources = Math.max(80, target.currentResources);
          } else if (nextAlt >= 0.78) {
            target.biome = "high_mountain";
            target.temperature = Math.min(target.temperature, -0.30);
          } else if (
            activeBrush.delta < 0 &&
            target.biome === "high_mountain" &&
            nextAlt < 0.78
          ) {
            target.biome = nextAlt < 0.55 ? "savanna" : "arid_steppe";
            target.temperature = Math.max(target.temperature, 0.20);
          }
        } else {
          const factor = 1 + activeBrush.deltaFactor;
          const nextK = Number(
            clamp(target.carryingCapacity * factor, 10, target.carryingCapacityMax).toFixed(2)
          );
          target.carryingCapacity = nextK;
          if (activeBrush.deltaFactor > 0) {
            const addedResources = Math.max(
              target.currentResources * factor,
              target.currentResources + target.carryingCapacity * activeBrush.deltaFactor
            );
            target.currentResources = clamp(Math.round(addedResources), 0, nextK);
          } else {
            target.currentResources = Number(
              clamp(target.currentResources * factor, 0, nextK).toFixed(2)
            );
          }
        }
      }
    });

    const nextSelection = reconcileSelection(nextWorld, hexId, null);
    persistWorldIfAvailable(nextWorld);
    set({
      world: nextWorld,
      selectedHexId: nextSelection.selectedHexId,
      selectedDemeId: nextSelection.selectedDemeId
    });
    get().completeFirstStep("tool");
  },

  adjustSeaLevel: (delta: number) => {
    const { world } = get();
    if (!canAfford(world, SEA_LEVEL_COST)) {
      return;
    }

    const nextSeaLevel = Number(clamp(world.seaLevel + delta, 0.0, 0.50).toFixed(2));
    const nextWorld = editWorldTerrain(world, SEA_LEVEL_COST, nextSeaLevel, (cells) => {
      for (const cell of Object.values(cells)) {
        if (cell.altitude < nextSeaLevel && cell.biome !== "ocean") {
          cell.biome = "ocean";
          cell.currentResources = 0;
        } else if (cell.altitude >= nextSeaLevel && cell.biome === "ocean") {
          cell.biome =
            cell.altitude < 0.25
              ? "coastal_shallows"
              : cell.altitude < 0.55
                ? "savanna"
                : cell.altitude < 0.78
                  ? "arid_steppe"
                  : "high_mountain";
          cell.carryingCapacityMax = Math.max(160, cell.carryingCapacityMax);
          cell.carryingCapacity = Math.max(
            Math.round(cell.carryingCapacityMax * 0.88),
            cell.carryingCapacity
          );
          cell.currentResources = Math.max(
            cell.currentResources,
            Math.round(cell.carryingCapacity * 0.35)
          );
        }
      }
    });

    const nextSelection = reconcileSelection(
      nextWorld,
      get().selectedHexId,
      get().selectedDemeId
    );
    persistWorldIfAvailable(nextWorld);
    set({
      world: nextWorld,
      selectedHexId: nextSelection.selectedHexId,
      selectedDemeId: nextSelection.selectedDemeId
    });
    get().completeFirstStep("tool");
  },

  upsertTrait: (trait: TraitDefinition) => {
    const { balancedVector } = validateAndBalanceThermodynamics(
      trait.biophysicalVector,
      trait.freeSandboxMode
    );
    const validatedTrait = TraitDefinitionSchema.parse({
      ...trait,
      biophysicalVector: balancedVector
    });

    const currentWorld = get().world;
    const nextWorld: WorldState = {
      ...currentWorld,
      traitsCatalog: {
        ...currentWorld.traitsCatalog,
        [validatedTrait.id]: validatedTrait
      }
    };

    persistWorldIfAvailable(nextWorld);
    set({ world: nextWorld });
  },

  upsertDecision: (decision: DecisionDefinition) => {
    const { balancedVector } = validateAndBalanceThermodynamics(
      decision.biophysicalVector,
      decision.freeSandboxMode
    );
    const validatedDecision = DecisionDefinitionSchema.parse({
      ...decision,
      biophysicalVector: balancedVector
    });

    const currentWorld = get().world;
    const nextWorld: WorldState = {
      ...currentWorld,
      decisionsCatalog: {
        ...currentWorld.decisionsCatalog,
        [validatedDecision.id]: validatedDecision
      }
    };

    persistWorldIfAvailable(nextWorld);
    set({ world: nextWorld });
  },

  injectTraitIntoDeme: (demeId: string, traitId: string) => {
    const currentWorld = get().world;
    const targetDeme = currentWorld.demes[demeId];
    const trait = currentWorld.traitsCatalog[traitId];

    if (targetDeme === undefined || trait === undefined) {
      return;
    }

    const excludedIds = new Set(trait.mutuallyExclusiveWith);
    for (const existingTrait of Object.values(currentWorld.traitsCatalog)) {
      if (existingTrait.mutuallyExclusiveWith.includes(traitId)) {
        excludedIds.add(existingTrait.id);
      }
    }

    const nextBioTraitIds = targetDeme.biologicalTraitIds.filter((id) => !excludedIds.has(id));
    const nextCulTraitIds = targetDeme.culturalTraitIds.filter((id) => !excludedIds.has(id));

    if (trait.category === "biological") {
      if (!nextBioTraitIds.includes(traitId)) {
        nextBioTraitIds.push(traitId);
      }
    } else {
      const hasCapacity = demeHasCulturalCapacity(
        { biologicalTraitIds: nextBioTraitIds },
        currentWorld.traitsCatalog
      );
      if (!hasCapacity) {
        set({
          toasts: [
            ...get().toasts,
            {
              id: `error-${Date.now()}-${++errorToastSeq}`,
              kind: "error" as const,
              messageKey: "panel.culturalCapacityRequired"
            }
          ].slice(-MAX_VISIBLE_TOASTS)
        });
        return;
      }
      if (!nextCulTraitIds.includes(traitId)) {
        nextCulTraitIds.push(traitId);
      }
    }

    const updatedDeme: Deme = {
      ...targetDeme,
      biologicalTraitIds: nextBioTraitIds,
      culturalTraitIds: nextCulTraitIds
    };

    const nextWorld: WorldState = {
      ...currentWorld,
      demes: {
        ...currentWorld.demes,
        [demeId]: updatedDeme
      }
    };

    persistWorldIfAvailable(nextWorld);
    set({ world: nextWorld });
  },

  exportWorldJson: () => {
    return serializeWorldState(get().world);
  },

  importWorldJson: (jsonPayload: string) => {
    worldEpoch += 1;
    isTurnInFlight = false;
    clearAutoPlayTimer();
    const importedWorld = deserializeWorldState(jsonPayload);
    persistWorldIfAvailable(importedWorld);
    const selection = resolveInitialSelection(importedWorld);
    set({
      world: importedWorld,
      playbackMode: "paused",
      selectedHexId: selection.selectedHexId,
      selectedDemeId: selection.selectedDemeId,
      highlightedLineageId: null,
      latestMilestoneChronicle: null,
      lastError: null,
      toasts: [],
      chronicleSeenCount: importedWorld.chronicle.length
    });
  },

  refreshOllamaStatus: async () => {
    const status = await activeCognitiveProvider.checkStatus();
    set({ ollamaStatus: status });
  },

  setActiveModal: (modal: SimulationStore["activeModal"]) => {
    if (modal === "naturalist_notebook") {
      set({ activeModal: modal, chronicleSeenCount: get().world.chronicle.length });
      return;
    }
    set({ activeModal: modal });
  },

  setHighlightedLineageId: (lineageId: string | null) => {
    set({ highlightedLineageId: lineageId });
  },

  dismissMilestoneBanner: () => {
    set({ latestMilestoneChronicle: null });
  },

  coDesignWithAI: async (input: UserCoDesignInput) => {
    return activeCognitiveProvider.coDesignCatalogItem(input);
  },

  setMapLens: (lens: MapLens) => {
    set({ mapLens: lens });
  },

  dismissToast: (toastId: string) => {
    set({ toasts: get().toasts.filter((toast) => toast.id !== toastId) });
  },

  completeFirstStep: (step: keyof FirstSteps) => {
    const { firstSteps, firstStepsDismissed } = get();
    if (firstStepsDismissed || firstSteps[step]) {
      return;
    }
    const nextSteps: FirstSteps = { ...firstSteps, [step]: true };
    set({ firstSteps: nextSteps });
    if (nextSteps.play && nextSteps.select && nextSteps.tool) {
      get().dismissFirstSteps();
    }
  },

  dismissFirstSteps: () => {
    persistFirstStepsDismissedIfAvailable();
    set({ firstStepsDismissed: true });
  }
}));
