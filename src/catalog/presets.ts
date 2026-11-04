import { computeHexDistance, createHexGridCoordinates } from "../engine/hexGrid";
import type { Deme, HexCell, LineageNode, PresetScenario, WorldState } from "../types/simulation";
import { createBaseDecisionsCatalog } from "./baseDecisions";
import { createBaseTraitsCatalog } from "./baseTraits";

function createRiftSavannaWorld(): WorldState {
  const mapRadius = 5;
  const coords = createHexGridCoordinates(mapRadius);
  const cells: Record<string, HexCell> = {};

  for (const coord of coords) {
    if (coord.q === 0 && coord.r === 0) {
      cells[coord.id] = {
        id: coord.id,
        q: coord.q,
        r: coord.r,
        biome: "savanna",
        temperature: 0.25,
        humidity: 0.45,
        altitude: 0.52,
        currentResources: 240,
        carryingCapacity: 280,
        carryingCapacityMax: 320,
        seasonalRegenRate: 0.18,
        demeIds: []
      };
    } else if (coord.q === 0) {
      cells[coord.id] = {
        id: coord.id,
        q: coord.q,
        r: coord.r,
        biome: "high_mountain",
        temperature: -0.35,
        humidity: 0.25,
        altitude: 0.88,
        currentResources: 70,
        carryingCapacity: 90,
        carryingCapacityMax: 120,
        seasonalRegenRate: 0.08,
        demeIds: []
      };
    } else if (coord.q < 0) {
      cells[coord.id] = {
        id: coord.id,
        q: coord.q,
        r: coord.r,
        biome: "tropical_forest",
        temperature: 0.45,
        humidity: 0.85,
        altitude: 0.35,
        currentResources: 560,
        carryingCapacity: 600,
        carryingCapacityMax: 650,
        seasonalRegenRate: 0.30,
        demeIds: []
      };
    } else {
      const isSavanna = (coord.q + Math.abs(coord.r)) % 2 === 0;
      cells[coord.id] = {
        id: coord.id,
        q: coord.q,
        r: coord.r,
        biome: isSavanna ? "savanna" : "arid_steppe",
        temperature: 0.60,
        humidity: 0.30,
        altitude: 0.42,
        currentResources: 260,
        carryingCapacity: 320,
        carryingCapacityMax: 380,
        seasonalRegenRate: 0.16,
        demeIds: []
      };
    }
  }

  const westDeme: Deme = {
    id: "deme-rift-west",
    name: "Western Forest Hominids",
    lineageId: "lineage-rift-ancestral",
    color: "#81B29A",
    hexId: "-2,1",
    population: 140,
    energyReserves: 180,
    lastEnergyDelta: 12,
    biologicalTraitIds: ["bio-k-strategy", "bio-social-instinct"],
    culturalTraitIds: [],
    baldwinCounters: {},
    innovationCounter: 0,
    isolationTurns: 0,
    lastDecisionProbabilities: {
      "dec-conservative-forage": 0.52,
      "dec-cooperate-store": 0.14,
      "dec-exchange-symbiosis": 0.10,
      "dec-selective-migration": 0.08,
      "dec-explore-innovate": 0.08,
      "dec-intensive-overexploit": 0.04,
      "dec-territorial-dispute": 0.04
    },
    lastDominantDecisionId: "dec-conservative-forage",
    lastJustification:
      "Dense western rainforest canopy provides predictable biomass favoring conservative foraging."
  };

  const eastDeme: Deme = {
    id: "deme-rift-east",
    name: "Eastern Savanna Hominids",
    lineageId: "lineage-rift-ancestral",
    color: "#E07A5F",
    hexId: "2,-1",
    population: 140,
    energyReserves: 180,
    lastEnergyDelta: 8,
    biologicalTraitIds: ["bio-k-strategy", "bio-social-instinct"],
    culturalTraitIds: [],
    baldwinCounters: {},
    innovationCounter: 0,
    isolationTurns: 0,
    lastDecisionProbabilities: {
      "dec-cooperate-store": 0.42,
      "dec-selective-migration": 0.16,
      "dec-explore-innovate": 0.14,
      "dec-conservative-forage": 0.12,
      "dec-exchange-symbiosis": 0.08,
      "dec-intensive-overexploit": 0.04,
      "dec-territorial-dispute": 0.04
    },
    lastDominantDecisionId: "dec-cooperate-store",
    lastJustification:
      "Seasonal savanna aridity east of the tectonic rift selects for cooperative storage and mobility."
  };

  cells["-2,1"]!.demeIds.push(westDeme.id);
  cells["2,-1"]!.demeIds.push(eastDeme.id);

  const ancestralLineage: LineageNode = {
    id: "lineage-rift-ancestral",
    parentId: null,
    name: "Rift Hominids",
    color: "#E07A5F",
    foundedGeneration: 0,
    extinctGeneration: null,
    founderHexId: "-2,1",
    acquiredTraitIds: ["bio-k-strategy", "bio-social-instinct"],
    divergenceReason: "initial"
  };

  return {
    presetId: "preset-rift-savanna",
    generation: 0,
    season: "wet_warm",
    seaLevel: 0.12,
    selectivePressurePoints: 30,
    selectivePressureRegenPerTurn: 15,
    unlimitedPressureMode: false,
    autoPauseOnMilestone: false,
    quietTurns: 0,
    mapRadius,
    cells,
    demes: {
      [westDeme.id]: westDeme,
      [eastDeme.id]: eastDeme
    },
    traitsCatalog: createBaseTraitsCatalog(),
    decisionsCatalog: createBaseDecisionsCatalog(),
    lineageTree: {
      [ancestralLineage.id]: ancestralLineage
    },
    chronicle: [],
    currentTurnFlows: []
  };
}

function createDarwinArchipelagoWorld(): WorldState {
  const mapRadius = 5;
  const coords = createHexGridCoordinates(mapRadius);
  const cells: Record<string, HexCell> = {};

  const bridgeHexIds = new Set(["0,-1", "0,1", "1,0"]);
  const northIslandHexIds = new Set(["0,-2", "0,-3"]);
  const southIslandHexIds = new Set(["0,2", "0,3"]);
  const eastIslandHexIds = new Set(["2,0", "3,0"]);

  for (const coord of coords) {
    if (coord.id === "0,0") {
      cells[coord.id] = {
        id: coord.id,
        q: coord.q,
        r: coord.r,
        biome: "tropical_forest",
        temperature: 0.20,
        humidity: 0.75,
        altitude: 0.40,
        currentResources: 320,
        carryingCapacity: 380,
        carryingCapacityMax: 450,
        seasonalRegenRate: 0.24,
        demeIds: []
      };
    } else if (bridgeHexIds.has(coord.id)) {
      cells[coord.id] = {
        id: coord.id,
        q: coord.q,
        r: coord.r,
        biome: "coastal_shallows",
        temperature: 0.15,
        humidity: 0.65,
        altitude: 0.18,
        currentResources: 200,
        carryingCapacity: 220,
        carryingCapacityMax: 260,
        seasonalRegenRate: 0.22,
        demeIds: []
      };
    } else if (northIslandHexIds.has(coord.id)) {
      cells[coord.id] = {
        id: coord.id,
        q: coord.q,
        r: coord.r,
        biome: "tundra",
        temperature: -0.55,
        humidity: 0.40,
        altitude: 0.55,
        currentResources: 360,
        carryingCapacity: 380,
        carryingCapacityMax: 420,
        seasonalRegenRate: 0.24,
        demeIds: []
      };
    } else if (southIslandHexIds.has(coord.id)) {
      cells[coord.id] = {
        id: coord.id,
        q: coord.q,
        r: coord.r,
        biome: "tropical_forest",
        temperature: 0.55,
        humidity: 0.85,
        altitude: 0.45,
        currentResources: 420,
        carryingCapacity: 450,
        carryingCapacityMax: 500,
        seasonalRegenRate: 0.28,
        demeIds: []
      };
    } else if (eastIslandHexIds.has(coord.id)) {
      cells[coord.id] = {
        id: coord.id,
        q: coord.q,
        r: coord.r,
        biome: "arid_steppe",
        temperature: 0.65,
        humidity: 0.25,
        altitude: 0.45,
        currentResources: 330,
        carryingCapacity: 360,
        carryingCapacityMax: 400,
        seasonalRegenRate: 0.22,
        demeIds: []
      };
    } else {
      cells[coord.id] = {
        id: coord.id,
        q: coord.q,
        r: coord.r,
        biome: "ocean",
        temperature: 0.10,
        humidity: 0.90,
        altitude: 0.05,
        currentResources: 0,
        carryingCapacity: 20,
        carryingCapacityMax: 60,
        seasonalRegenRate: 0.05,
        demeIds: []
      };
    }
  }

  const founderDeme: Deme = {
    id: "deme-darwin-founder",
    name: "Archipelago Founders",
    lineageId: "lineage-darwin-ancestral",
    color: "#3D85C6",
    hexId: "0,0",
    population: 220,
    energyReserves: 300,
    lastEnergyDelta: 15,
    biologicalTraitIds: ["bio-r-strategy", "bio-thermal-tolerance", "bio-social-instinct"],
    culturalTraitIds: [],
    baldwinCounters: {},
    innovationCounter: 0,
    isolationTurns: 0,
    lastDecisionProbabilities: {
      "dec-selective-migration": 0.52,
      "dec-cooperate-store": 0.20,
      "dec-conservative-forage": 0.10,
      "dec-explore-innovate": 0.08,
      "dec-exchange-symbiosis": 0.04,
      "dec-intensive-overexploit": 0.03,
      "dec-territorial-dispute": 0.03
    },
    lastDominantDecisionId: "dec-selective-migration",
    lastJustification:
      "Glacial low sea level exposes shallow land bridges, favoring rapid island colonization."
  };

  cells["0,0"]!.demeIds.push(founderDeme.id);

  const ancestralLineage: LineageNode = {
    id: "lineage-darwin-ancestral",
    parentId: null,
    name: "Archipelago Ancestors",
    color: "#3D85C6",
    foundedGeneration: 0,
    extinctGeneration: null,
    founderHexId: "0,0",
    acquiredTraitIds: ["bio-r-strategy", "bio-thermal-tolerance", "bio-social-instinct"],
    divergenceReason: "initial"
  };

  return {
    presetId: "preset-darwin-archipelago",
    generation: 0,
    season: "wet_warm",
    seaLevel: 0.12,
    selectivePressurePoints: 30,
    selectivePressureRegenPerTurn: 15,
    unlimitedPressureMode: false,
    autoPauseOnMilestone: false,
    quietTurns: 0,
    mapRadius,
    cells,
    demes: {
      [founderDeme.id]: founderDeme
    },
    traitsCatalog: createBaseTraitsCatalog(),
    decisionsCatalog: createBaseDecisionsCatalog(),
    lineageTree: {
      [ancestralLineage.id]: ancestralLineage
    },
    chronicle: [],
    currentTurnFlows: []
  };
}

function createFiniteIslandWorld(): WorldState {
  const mapRadius = 4;
  const coords = createHexGridCoordinates(mapRadius);
  const cells: Record<string, HexCell> = {};

  for (const coord of coords) {
    const dist = computeHexDistance({ q: 0, r: 0 }, { q: coord.q, r: coord.r });
    if (dist <= 1) {
      cells[coord.id] = {
        id: coord.id,
        q: coord.q,
        r: coord.r,
        biome: "savanna",
        temperature: 0.30,
        humidity: 0.55,
        altitude: 0.42,
        currentResources: 580,
        carryingCapacity: 600,
        carryingCapacityMax: 600,
        seasonalRegenRate: 0.08,
        demeIds: []
      };
    } else if (dist === 2) {
      cells[coord.id] = {
        id: coord.id,
        q: coord.q,
        r: coord.r,
        biome: "arid_steppe",
        temperature: 0.45,
        humidity: 0.30,
        altitude: 0.48,
        currentResources: 200,
        carryingCapacity: 250,
        carryingCapacityMax: 280,
        seasonalRegenRate: 0.08,
        demeIds: []
      };
    } else {
      cells[coord.id] = {
        id: coord.id,
        q: coord.q,
        r: coord.r,
        biome: "ocean",
        temperature: 0.15,
        humidity: 0.90,
        altitude: 0.05,
        currentResources: 0,
        carryingCapacity: 20,
        carryingCapacityMax: 60,
        seasonalRegenRate: 0.05,
        demeIds: []
      };
    }
  }

  const initialProbs = {
    "dec-intensive-overexploit": 0.58,
    "dec-territorial-dispute": 0.14,
    "dec-conservative-forage": 0.10,
    "dec-cooperate-store": 0.06,
    "dec-selective-migration": 0.04,
    "dec-exchange-symbiosis": 0.04,
    "dec-explore-innovate": 0.04
  };

  const deme1: Deme = {
    id: "deme-island-1",
    name: "Northern Quarry Clan",
    lineageId: "lineage-island-1",
    color: "#E07A5F",
    hexId: "0,0",
    population: 320,
    energyReserves: 400,
    lastEnergyDelta: -10,
    biologicalTraitIds: ["bio-encephalization", "bio-k-strategy"],
    culturalTraitIds: ["cul-extraction-tools"],
    baldwinCounters: {},
    innovationCounter: 0,
    isolationTurns: 0,
    lastDecisionProbabilities: { ...initialProbs },
    lastDominantDecisionId: "dec-intensive-overexploit",
    lastJustification:
      "High population density and specialized extraction tools drive competitive overharvesting."
  };

  const deme2: Deme = {
    id: "deme-island-2",
    name: "Southern Timber Clan",
    lineageId: "lineage-island-2",
    color: "#F2CC8F",
    hexId: "0,0",
    population: 320,
    energyReserves: 400,
    lastEnergyDelta: -10,
    biologicalTraitIds: ["bio-encephalization", "bio-k-strategy"],
    culturalTraitIds: ["cul-extraction-tools"],
    baldwinCounters: {},
    innovationCounter: 0,
    isolationTurns: 0,
    lastDecisionProbabilities: { ...initialProbs },
    lastDominantDecisionId: "dec-intensive-overexploit",
    lastJustification:
      "Intensive extraction maximizes short-term yield against rival clans on a bounded island."
  };

  const deme3: Deme = {
    id: "deme-island-3",
    name: "Eastern Ridge Clan",
    lineageId: "lineage-island-3",
    color: "#9B5DE5",
    hexId: "0,0",
    population: 320,
    energyReserves: 400,
    lastEnergyDelta: -10,
    biologicalTraitIds: ["bio-encephalization", "bio-k-strategy"],
    culturalTraitIds: ["cul-extraction-tools"],
    baldwinCounters: {},
    innovationCounter: 0,
    isolationTurns: 0,
    lastDecisionProbabilities: { ...initialProbs },
    lastDominantDecisionId: "dec-intensive-overexploit",
    lastJustification:
      "Unregulated tool-assisted harvesting accelerates local carrying capacity exhaustion."
  };

  cells["0,0"]!.demeIds.push(deme1.id, deme2.id, deme3.id);

  const lineage1: LineageNode = {
    id: "lineage-island-1",
    parentId: null,
    name: "Northern Quarry Lineage",
    color: "#E07A5F",
    foundedGeneration: 0,
    extinctGeneration: null,
    founderHexId: "0,0",
    acquiredTraitIds: ["bio-encephalization", "bio-k-strategy", "cul-extraction-tools"],
    divergenceReason: "initial"
  };

  const lineage2: LineageNode = {
    id: "lineage-island-2",
    parentId: null,
    name: "Southern Timber Lineage",
    color: "#F2CC8F",
    foundedGeneration: 0,
    extinctGeneration: null,
    founderHexId: "0,0",
    acquiredTraitIds: ["bio-encephalization", "bio-k-strategy", "cul-extraction-tools"],
    divergenceReason: "initial"
  };

  const lineage3: LineageNode = {
    id: "lineage-island-3",
    parentId: null,
    name: "Eastern Ridge Lineage",
    color: "#9B5DE5",
    foundedGeneration: 0,
    extinctGeneration: null,
    founderHexId: "0,0",
    acquiredTraitIds: ["bio-encephalization", "bio-k-strategy", "cul-extraction-tools"],
    divergenceReason: "initial"
  };

  return {
    presetId: "preset-finite-island",
    generation: 0,
    season: "wet_warm",
    seaLevel: 0.20,
    selectivePressurePoints: 30,
    selectivePressureRegenPerTurn: 15,
    unlimitedPressureMode: false,
    autoPauseOnMilestone: false,
    quietTurns: 0,
    mapRadius,
    cells,
    demes: {
      [deme1.id]: deme1,
      [deme2.id]: deme2,
      [deme3.id]: deme3
    },
    traitsCatalog: createBaseTraitsCatalog(),
    decisionsCatalog: createBaseDecisionsCatalog(),
    lineageTree: {
      [lineage1.id]: lineage1,
      [lineage2.id]: lineage2,
      [lineage3.id]: lineage3
    },
    chronicle: [],
    currentTurnFlows: []
  };
}

export const SCIENTIFIC_PRESETS: PresetScenario[] = [
  {
    id: "preset-rift-savanna",
    name: "The Rift and the Savanna",
    description:
      "A tectonic ridge divides a stable western tropical forest from a drying eastern savanna mosaic.",
    scientificHypothesis:
      "Eastern demes under seasonal aridification increase cooperation and migration, triggering Baldwin assimilation or cultural innovation while western forest demes maintain conservative foraging.",
    glacialSeaLevelCycle: false,
    createInitialWorld: createRiftSavannaWorld
  },
  {
    id: "preset-darwin-archipelago",
    name: "Darwin's Archipelago",
    description:
      "Volcanic islands linked by shallow coastal land bridges that periodically flood and emerge with glacial sea-level cycles.",
    scientificHypothesis:
      "Demes disperse across temporary land bridges during low sea levels and subsequently undergo allopatric speciation when rising seas isolate island populations.",
    glacialSeaLevelCycle: true,
    createInitialWorld: createDarwinArchipelagoWorld
  },
  {
    id: "preset-finite-island",
    name: "The Finite Island",
    description:
      "A resource-rich but geographically bounded island surrounded by impassable deep ocean.",
    scientificHypothesis:
      "Without communal conservation norms, inter-deme competition and intensive overexploitation degrade carrying capacity K below 60% of Kmax, causing a Tragedy of the Commons.",
    glacialSeaLevelCycle: false,
    createInitialWorld: createFiniteIslandWorld
  }
];

export function getPresetById(presetId: string): PresetScenario {
  const preset = SCIENTIFIC_PRESETS.find((item) => item.id === presetId);
  if (preset === undefined) {
    throw new Error(`Unknown scientific preset id: ${presetId}`);
  }
  return preset;
}
