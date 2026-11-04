import { describe, expect, it } from "vitest";
import { createBaseDecisionsCatalog } from "../../src/catalog/baseDecisions";
import { createBaseTraitsCatalog } from "../../src/catalog/baseTraits";
import {
  computeDemeDivergence,
  computeEffectiveBiophysicalVector,
  resolveBiophysicalAndDemographicPhase
} from "../../src/engine/biophysicalPhase";
import { runEnvironmentalPhase } from "../../src/engine/environmentalPhase";
import { createHexGridCoordinates } from "../../src/engine/hexGrid";
import {
  applySynthesizedMilestone,
  detectEvolutionaryMilestones,
  evaluateMacroEvolutionaryOutcome
} from "../../src/engine/milestonePhase";
import type {
  Deme,
  DemeDecisionEvaluationOutput,
  HexCell,
  WorldState
} from "../../src/types/simulation";

function createTestWorldState(): WorldState {
  const coords = createHexGridCoordinates(4);
  const cells: Record<string, HexCell> = {};

  for (const coord of coords) {
    cells[coord.id] = {
      id: coord.id,
      q: coord.q,
      r: coord.r,
      biome: "savanna",
      temperature: 0.2,
      humidity: 0.5,
      altitude: 0.3,
      currentResources: 300,
      carryingCapacity: 400,
      carryingCapacityMax: 500,
      seasonalRegenRate: 0.12,
      demeIds: []
    };
  }

  const founderDeme: Deme = {
    id: "deme-1",
    name: "Rift Foragers",
    lineageId: "lineage-root",
    color: "#E07A5F",
    hexId: "0,0",
    population: 120,
    energyReserves: 80,
    lastEnergyDelta: 10,
    biologicalTraitIds: ["bio-k-strategy", "bio-social-instinct"],
    culturalTraitIds: [],
    baldwinCounters: {},
    innovationCounter: 0,
    isolationTurns: 0,
    lastDecisionProbabilities: {
      "dec-conservative-forage": 1.0
    },
    lastDominantDecisionId: "dec-conservative-forage",
    lastJustification: "Baseline foraging."
  };

  cells["0,0"]!.demeIds.push(founderDeme.id);

  return {
    presetId: "preset-rift-savanna",
    generation: 0,
    season: "wet_warm",
    seaLevel: 0.12,
    selectivePressurePoints: 20,
    selectivePressureRegenPerTurn: 5,
    unlimitedPressureMode: false,
    autoPauseOnMilestone: true,
    mapRadius: 4,
    cells,
    demes: {
      [founderDeme.id]: founderDeme
    },
    traitsCatalog: createBaseTraitsCatalog(),
    decisionsCatalog: createBaseDecisionsCatalog(),
    lineageTree: {
      "lineage-root": {
        id: "lineage-root",
        parentId: null,
        name: "Ancestral Hominids",
        color: "#E07A5F",
        foundedGeneration: 0,
        extinctGeneration: null,
        founderHexId: "0,0",
        acquiredTraitIds: ["bio-k-strategy", "bio-social-instinct"],
        divergenceReason: "initial"
      }
    },
    chronicle: [],
    currentTurnFlows: []
  };
}

function makeDecisionEval(
  dominantDecisionId: string,
  probabilities: Record<string, number>
): DemeDecisionEvaluationOutput {
  return {
    probabilities,
    dominantDecisionId,
    confidence: 0.85,
    justification: `Selected ${dominantDecisionId}`
  };
}

describe("Phase 1: Environmental Phase (runEnvironmentalPhase)", () => {
  it("alternates season wet_warm <-> dry_cold, regenerates K and currentResources, and adds pressure budget", () => {
    const state = createTestWorldState();
    state.cells["0,0"]!.carryingCapacity = 300;
    state.cells["0,0"]!.carryingCapacityMax = 500;
    state.cells["0,0"]!.currentResources = 100;
    state.cells["0,0"]!.seasonalRegenRate = 0.10;

    const afterTurn1 = runEnvironmentalPhase(state);
    expect(afterTurn1.generation).toBe(1);
    expect(afterTurn1.season).toBe("dry_cold");
    expect(afterTurn1.selectivePressurePoints).toBe(25);

    expect(afterTurn1.cells["0,0"]!.carryingCapacity).toBeCloseTo(310, 2);
    expect(afterTurn1.cells["0,0"]!.currentResources).toBeCloseTo(123.25, 2);

    const afterTurn2 = runEnvironmentalPhase(afterTurn1);
    expect(afterTurn2.generation).toBe(2);
    expect(afterTurn2.season).toBe("wet_warm");
    expect(afterTurn2.cells["0,0"]!.carryingCapacity).toBeCloseTo(319.5, 2);
    expect(afterTurn2.cells["0,0"]!.currentResources).toBeCloseTo(161.59, 2);
  });

  it("cycles glacial sea level (0.12 <-> 0.25) every 8 generations in preset-darwin-archipelago and displaces submerged demes with -20% energy reserves", () => {
    const state = createTestWorldState();
    state.presetId = "preset-darwin-archipelago";
    state.generation = 7;
    state.seaLevel = 0.12;
    state.cells["0,0"]!.altitude = 0.18;
    state.cells["0,0"]!.biome = "coastal_shallows";
    state.cells["1,0"]!.altitude = 0.45;
    state.cells["1,0"]!.biome = "savanna";
    state.cells["1,0"]!.currentResources = 480;
    state.demes["deme-1"]!.energyReserves = 100;

    const interglacialState = runEnvironmentalPhase(state);
    expect(interglacialState.generation).toBe(8);
    expect(interglacialState.seaLevel).toBe(0.25);
    expect(interglacialState.cells["0,0"]!.biome).toBe("ocean");
    expect(interglacialState.cells["0,0"]!.demeIds).toHaveLength(0);

    const displacedDeme = interglacialState.demes["deme-1"]!;
    expect(displacedDeme.hexId).toBe("1,0");
    expect(displacedDeme.energyReserves).toBeCloseTo(80, 2);
    expect(interglacialState.currentTurnFlows).toHaveLength(1);
    expect(interglacialState.currentTurnFlows[0]!.type).toBe("migration");

    interglacialState.generation = 15;
    const glacialState = runEnvironmentalPhase(interglacialState);
    expect(glacialState.generation).toBe(16);
    expect(glacialState.seaLevel).toBe(0.12);
    expect(glacialState.cells["0,0"]!.biome).toBe("coastal_shallows");
  });

  it("drives a submerged deme extinct when no terrestrial neighbor has capacity < 3", () => {
    const state = createTestWorldState();
    state.presetId = "preset-darwin-archipelago";
    state.generation = 7;
    state.cells["0,0"]!.altitude = 0.18;
    state.cells["0,0"]!.biome = "coastal_shallows";

    for (const cell of Object.values(state.cells)) {
      if (cell.id !== "0,0") {
        cell.biome = "ocean";
        cell.altitude = 0.05;
      }
    }

    const nextState = runEnvironmentalPhase(state);
    expect(nextState.demes["deme-1"]).toBeUndefined();
    expect(nextState.lineageTree["lineage-root"]!.extinctGeneration).toBe(8);
    expect(nextState.chronicle.some((entry) => entry.type === "extinction")).toBe(true);
  });
});

describe("Phase 3: Biophysical & Demographic Resolution", () => {
  it("computes Jaccard trait divergence and clamped effective biophysical vectors", () => {
    const state = createTestWorldState();
    const demeA = state.demes["deme-1"]!;
    const demeB: Deme = {
      ...demeA,
      id: "deme-2",
      biologicalTraitIds: ["bio-k-strategy", "bio-encephalization"],
      culturalTraitIds: ["cul-fire-processing"]
    };

    expect(computeDemeDivergence(demeA, demeB)).toBeCloseTo(0.75, 4);

    const vEff = computeEffectiveBiophysicalVector(demeA, state, {
      "dec-cooperate-store": 1.0
    });
    expect(vEff.socialCohesion).toBeLessThanOrEqual(1.5);
    expect(vEff.socialCohesion).toBeGreaterThan(1.0);
  });

  it("applies Hawk-Hawk mutual penalty (-15% pop and +25% metabolic cost)", () => {
    const state = createTestWorldState();
    const demeA = state.demes["deme-1"]!;
    demeA.population = 100;
    demeA.energyReserves = 0;

    const demeB: Deme = {
      ...demeA,
      id: "deme-2",
      name: "Rival Clan",
      lineageId: "lineage-rival",
      population: 100,
      energyReserves: 0
    };
    state.demes["deme-2"] = demeB;
    state.cells["0,0"]!.demeIds.push("deme-2");
    state.cells["0,0"]!.currentResources = 50;

    const nextState = resolveBiophysicalAndDemographicPhase(state, {
      "deme-1": makeDecisionEval("dec-territorial-dispute", {
        "dec-territorial-dispute": 0.6,
        "dec-conservative-forage": 0.4
      }),
      "deme-2": makeDecisionEval("dec-territorial-dispute", {
        "dec-territorial-dispute": 0.6,
        "dec-conservative-forage": 0.4
      })
    });

    expect(nextState.demes["deme-1"]!.population).toBeLessThan(85);
    expect(nextState.demes["deme-2"]!.population).toBeLessThan(85);
    expect(nextState.demes["deme-1"]!.lastEnergyDelta).toBeLessThan(0);
    expect(nextState.currentTurnFlows.some((flow) => flow.type === "dispute")).toBe(true);
  });

  it("applies Hawk-Dove resource capture weighted by socialCohesion", () => {
    const state = createTestWorldState();
    const hawk = state.demes["deme-1"]!;
    hawk.population = 100;
    hawk.energyReserves = 50;
    hawk.biologicalTraitIds = ["bio-social-instinct"];

    const dove: Deme = {
      ...hawk,
      id: "deme-2",
      name: "Peaceful Foragers",
      population: 100,
      energyReserves: 50,
      biologicalTraitIds: []
    };
    state.demes["deme-2"] = dove;
    state.cells["0,0"]!.demeIds.push("deme-2");
    state.cells["0,0"]!.currentResources = 120;

    const nextState = resolveBiophysicalAndDemographicPhase(state, {
      "deme-1": makeDecisionEval("dec-territorial-dispute", {
        "dec-territorial-dispute": 0.5,
        "dec-conservative-forage": 0.5
      }),
      "deme-2": makeDecisionEval("dec-conservative-forage", {
        "dec-conservative-forage": 1.0
      })
    });

    expect(nextState.demes["deme-1"]!.lastEnergyDelta).toBeGreaterThan(
      nextState.demes["deme-2"]!.lastEnergyDelta
    );
  });

  it("applies Symbiosis +20% energy bonus and horizontal cultural diffusion when transmissionThreshold is met", () => {
    const state = createTestWorldState();
    const demeA = state.demes["deme-1"]!;
    demeA.biologicalTraitIds = ["bio-encephalization", "bio-social-instinct"];
    demeA.culturalTraitIds = ["cul-fire-processing"];

    const demeB: Deme = {
      ...demeA,
      id: "deme-2",
      name: "Neighboring Symbionts",
      lineageId: "lineage-symbiont",
      culturalTraitIds: []
    };
    state.demes["deme-2"] = demeB;
    state.cells["0,0"]!.demeIds.push("deme-2");
    state.cells["0,0"]!.currentResources = 400;

    const exchangeProbs = {
      "dec-exchange-symbiosis": 0.5,
      "dec-conservative-forage": 0.5
    };
    const receiverEffective = computeEffectiveBiophysicalVector(demeB, state, exchangeProbs);
    const fireThreshold =
      state.traitsCatalog["cul-fire-processing"]!.biophysicalVector.transmissionThreshold;
    expect(receiverEffective.socialCohesion).toBeGreaterThanOrEqual(fireThreshold);

    const baselineState = createTestWorldState();
    baselineState.demes["deme-1"] = { ...demeB, id: "deme-1", culturalTraitIds: [] };
    baselineState.cells["0,0"]!.currentResources = 400;
    const withoutSymbiosis = resolveBiophysicalAndDemographicPhase(baselineState, {
      "deme-1": makeDecisionEval("dec-exchange-symbiosis", exchangeProbs)
    });

    const nextState = resolveBiophysicalAndDemographicPhase(state, {
      "deme-1": makeDecisionEval("dec-exchange-symbiosis", exchangeProbs),
      "deme-2": makeDecisionEval("dec-exchange-symbiosis", exchangeProbs)
    });

    expect(nextState.demes["deme-2"]!.culturalTraitIds).toContain("cul-fire-processing");
    expect(nextState.demes["deme-2"]!.lastEnergyDelta).toBeGreaterThan(
      withoutSymbiosis.demes["deme-1"]!.lastEnergyDelta
    );
    expect(nextState.chronicle.some((entry) => entry.type === "symbiosis")).toBe(true);
    expect(nextState.currentTurnFlows.some((flow) => flow.type === "exchange")).toBe(true);
  });

  it("blocks horizontal cultural diffusion during Symbiosis when receiver socialCohesion is below transmissionThreshold", () => {
    const state = createTestWorldState();
    const demeA = state.demes["deme-1"]!;
    demeA.biologicalTraitIds = ["bio-encephalization", "bio-social-instinct"];
    demeA.culturalTraitIds = ["cul-fire-processing"];

    const demeB: Deme = {
      ...demeA,
      id: "deme-2",
      name: "Low Cohesion Receivers",
      lineageId: "lineage-low-cohesion",
      biologicalTraitIds: ["bio-encephalization", "bio-r-strategy"],
      culturalTraitIds: []
    };
    state.demes["deme-2"] = demeB;
    state.cells["0,0"]!.demeIds.push("deme-2");
    state.cells["0,0"]!.currentResources = 400;

    const receiverProbs = {
      "dec-exchange-symbiosis": 0.25,
      "dec-intensive-overexploit": 0.75
    };
    const receiverEffective = computeEffectiveBiophysicalVector(demeB, state, receiverProbs);
    const fireThreshold =
      state.traitsCatalog["cul-fire-processing"]!.biophysicalVector.transmissionThreshold;
    expect(receiverEffective.socialCohesion).toBeLessThan(fireThreshold);

    const nextState = resolveBiophysicalAndDemographicPhase(state, {
      "deme-1": makeDecisionEval("dec-exchange-symbiosis", {
        "dec-exchange-symbiosis": 0.5,
        "dec-conservative-forage": 0.5
      }),
      "deme-2": makeDecisionEval("dec-intensive-overexploit", receiverProbs)
    });

    expect(nextState.demes["deme-2"]!.culturalTraitIds).toEqual([]);
    expect(nextState.chronicle.some((entry) => entry.type === "symbiosis")).toBe(false);
    expect(nextState.currentTurnFlows.some((flow) => flow.type === "exchange")).toBe(true);
  });

  it("degrades carryingCapacity (Tragedy of the Commons) under intensive overexploitation and logs chronicle when K < 0.60 * K_max", () => {
    const state = createTestWorldState();
    const cell = state.cells["0,0"]!;
    cell.carryingCapacity = 310;
    cell.carryingCapacityMax = 500;
    cell.currentResources = 310;
    cell.seasonalRegenRate = 0.05;

    const deme = state.demes["deme-1"]!;
    deme.population = 350;
    deme.biologicalTraitIds = ["bio-r-strategy"];
    deme.culturalTraitIds = ["cul-extraction-tools"];

    const nextState = resolveBiophysicalAndDemographicPhase(state, {
      "deme-1": makeDecisionEval("dec-intensive-overexploit", {
        "dec-intensive-overexploit": 0.9,
        "dec-conservative-forage": 0.1
      })
    });

    expect(nextState.cells["0,0"]!.carryingCapacity).toBeLessThan(300);
    expect(nextState.chronicle.some((entry) => entry.type === "tragedy_of_commons")).toBe(true);
  });

  it("triggers migrant fission (M >= 10), inherits traits, resets daughter counters, and fuses same-lineage demes with Jaccard < 0.10", () => {
    const state = createTestWorldState();
    state.traitsCatalog["cul-lithic-knapping"] = {
      id: "cul-lithic-knapping",
      name: "Lithic Knapping Tradition",
      category: "cultural",
      semanticDescriptor: "Percussive stone flaking tradition transmitted across generations.",
      affinityCondition: "Favors foraging and cooperative resource extraction.",
      mutuallyExclusiveWith: [],
      enablesCulturalTransmission: false,
      biophysicalVector: {
        metabolicCost: 0.10,
        extractionEfficiency: 0.30,
        ecologicalImpact: -0.05,
        spatialMobility: 0.05,
        socialCohesion: 0.15,
        transmissionThreshold: 0.45
      },
      origin: "base",
      freeSandboxMode: false
    };

    const deme = state.demes["deme-1"]!;
    deme.population = 100;
    deme.energyReserves = 100;
    deme.biologicalTraitIds = ["bio-k-strategy", "bio-social-instinct", "bio-encephalization"];
    deme.culturalTraitIds = ["cul-lithic-knapping"];
    deme.baldwinCounters = { "dec-selective-migration": 4 };
    deme.innovationCounter = 0.5;
    state.cells["1,0"]!.currentResources = 500;

    const afterFission = resolveBiophysicalAndDemographicPhase(state, {
      "deme-1": makeDecisionEval("dec-selective-migration", {
        "dec-selective-migration": 0.8,
        "dec-conservative-forage": 0.2
      })
    });

    const allDemes = Object.values(afterFission.demes);
    expect(allDemes.length).toBe(2);
    const daughter = allDemes.find((d) => d.id !== "deme-1")!;
    expect(daughter.hexId).toBe("1,0");
    expect(daughter.population).toBeGreaterThanOrEqual(10);
    expect(daughter.population).toBeLessThan(50);
    expect(daughter.biologicalTraitIds).toEqual(deme.biologicalTraitIds);
    expect(daughter.culturalTraitIds).toEqual(["cul-lithic-knapping"]);
    expect(afterFission.chronicle.some((e) => e.type === "cultural_loss")).toBe(false);
    expect(daughter.baldwinCounters).toEqual({});
    expect(daughter.innovationCounter).toBe(0);
    expect(afterFission.currentTurnFlows.some((f) => f.type === "migration")).toBe(true);

    afterFission.cells["1,0"]!.demeIds = [];
    afterFission.cells["0,0"]!.demeIds.push(daughter.id);
    daughter.hexId = "0,0";
    daughter.population = 60;

    const afterFusion = resolveBiophysicalAndDemographicPhase(afterFission, {
      "deme-1": makeDecisionEval("dec-conservative-forage", {
        "dec-conservative-forage": 1.0
      }),
      [daughter.id]: makeDecisionEval("dec-conservative-forage", {
        "dec-conservative-forage": 1.0
      })
    });

    expect(Object.keys(afterFusion.demes)).toHaveLength(1);
    expect(afterFusion.cells["0,0"]!.demeIds).toHaveLength(1);
  });

  it("triggers migrant fission for a user-created custom decision with archetype 'migrate'", () => {
    const state = createTestWorldState();
    state.decisionsCatalog["user-dec-custom-migrate"] = {
      id: "user-dec-custom-migrate",
      name: "Seasonal Corridor Dispersal",
      archetype: "migrate",
      semanticDescriptor: "User-designed migratory strategy across adjacent savanna corridors.",
      requiredTraitIds: [],
      biophysicalVector: {
        metabolicCost: 0.25,
        extractionEfficiency: 0.15,
        ecologicalImpact: 0.10,
        spatialMobility: 0.70,
        socialCohesion: 0.05,
        transmissionThreshold: 0.10
      },
      origin: "user",
      freeSandboxMode: false
    };

    const deme = state.demes["deme-1"]!;
    deme.population = 100;
    deme.energyReserves = 100;
    state.cells["1,0"]!.currentResources = 500;

    const afterFission = resolveBiophysicalAndDemographicPhase(state, {
      "deme-1": makeDecisionEval("user-dec-custom-migrate", {
        "user-dec-custom-migrate": 0.8,
        "dec-conservative-forage": 0.2
      })
    });

    const allDemes = Object.values(afterFission.demes);
    expect(allDemes).toHaveLength(2);
    const daughter = allDemes.find((d) => d.id !== "deme-1")!;
    expect(daughter.hexId).toBe("1,0");
    expect(daughter.population).toBeGreaterThanOrEqual(10);
    expect(afterFission.currentTurnFlows.some((f) => f.type === "migration")).toBe(true);
  });

  it("removes the highest-transmissionThreshold cultural tradition on demographic bottleneck (< 50 pop) and extinguishes demes < 10 pop", () => {
    const state = createTestWorldState();
    const deme = state.demes["deme-1"]!;
    deme.population = 42;
    deme.culturalTraitIds = ["cul-fire-processing", "cul-interdeme-barter"];

    const afterBottleneck = resolveBiophysicalAndDemographicPhase(state, {
      "deme-1": makeDecisionEval("dec-conservative-forage", {
        "dec-conservative-forage": 1.0
      })
    });

    expect(afterBottleneck.demes["deme-1"]!.culturalTraitIds).toEqual(["cul-fire-processing"]);
    expect(afterBottleneck.chronicle.some((e) => e.type === "cultural_loss")).toBe(true);

    afterBottleneck.demes["deme-1"]!.population = 10;
    afterBottleneck.demes["deme-1"]!.energyReserves = 0;
    afterBottleneck.cells["0,0"]!.currentResources = 0;

    const afterExtinction = resolveBiophysicalAndDemographicPhase(afterBottleneck, {
      "deme-1": makeDecisionEval("dec-territorial-dispute", {
        "dec-territorial-dispute": 1.0
      })
    });

    expect(afterExtinction.demes["deme-1"]).toBeUndefined();
    expect(afterExtinction.lineageTree["lineage-root"]!.extinctGeneration).toBe(0);
    expect(afterExtinction.chronicle.some((e) => e.type === "extinction")).toBe(true);
  });
});

describe("Phase 4: Evolutionary & Cultural Milestones", () => {
  it("detects Baldwin (N=8), Cultural Innovation (>=1.0), and Allopatric Speciation (M=10) milestones and applies synthesized proposals", () => {
    const state = createTestWorldState();
    const deme = state.demes["deme-1"]!;
    deme.biologicalTraitIds = ["bio-k-strategy", "bio-encephalization", "bio-thermal-tolerance"];
    deme.baldwinCounters = { "dec-selective-migration": 8 };
    deme.innovationCounter = 1.15;
    deme.isolationTurns = 10;
    deme.lastDecisionProbabilities = {
      "dec-selective-migration": 0.6,
      "dec-explore-innovate": 0.4
    };
    deme.lastDominantDecisionId = "dec-selective-migration";

    const milestones = detectEvolutionaryMilestones(state, "en");
    const triggerTypes = milestones.map((m) => m.triggerType);
    expect(triggerTypes).toContain("baldwin_assimilation");
    expect(triggerTypes).toContain("cultural_innovation");
    expect(triggerTypes).toContain("allopatric_speciation");

    const speciationInput = milestones.find((m) => m.triggerType === "allopatric_speciation")!;
    const afterSpeciation = applySynthesizedMilestone(state, speciationInput, {
      name: "Highland Endurance Stride",
      category: "biological",
      semanticDescriptor:
        "Cardiopulmonary and musculoskeletal adaptation to thin air and steep rocky gradients.",
      affinityCondition: "Favors Selective Migration across mountain passes.",
      biophysicalVector: {
        metabolicCost: 0.25,
        extractionEfficiency: 0.20,
        ecologicalImpact: 0.0,
        spatialMobility: 0.45,
        socialCohesion: 0.10,
        transmissionThreshold: 0.15
      },
      chronicleTitle: "Speciation in the Highlands",
      chronicleBody: "After ten generations of isolation, a new highland species emerged."
    });

    const updatedDeme = afterSpeciation.demes["deme-1"]!;
    expect(updatedDeme.isolationTurns).toBe(0);
    expect(updatedDeme.lineageId).not.toBe("lineage-root");
    expect(afterSpeciation.lineageTree[updatedDeme.lineageId]!.parentId).toBe("lineage-root");
    expect(afterSpeciation.chronicle.some((e) => e.type === "allopatric_speciation")).toBe(true);
  });

  it("evaluates macro-evolutionary outcomes (single_survivor after rival extinction and ecological_equilibrium after 8 quiet turns at gen >= 30)", () => {
    const prevState = createTestWorldState();
    prevState.generation = 29;
    prevState.quietTurns = 7;

    const nextState: WorldState = {
      ...prevState,
      generation: 30,
      currentTurnFlows: []
    };

    const afterEquilibrium = evaluateMacroEvolutionaryOutcome(prevState, nextState, "es");
    expect(afterEquilibrium.quietTurns).toBe(8);
    expect(
      afterEquilibrium.chronicle.some((entry) => entry.type === "ecological_equilibrium")
    ).toBe(true);

    const survivorState: WorldState = {
      ...prevState,
      generation: 18,
      chronicle: [
        {
          id: "chronicle-extinct-18-deme-2",
          generation: 18,
          type: "extinction",
          title: "Rival Clan Extinct",
          body: "Rival Clan fell below minimum viable population.",
          demeId: "deme-2",
          lineageId: "lineage-rival",
          hexId: "1,0"
        }
      ]
    };

    const afterSingleSurvivor = evaluateMacroEvolutionaryOutcome(prevState, survivorState, "es");
    expect(
      afterSingleSurvivor.chronicle.some((entry) => entry.type === "single_survivor")
    ).toBe(true);
  });
});
