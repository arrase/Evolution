import { describe, expect, it } from "vitest";
import { MockCognitiveProvider } from "../../src/ai/cognitiveProvider";
import { getPresetById, SCIENTIFIC_PRESETS } from "../../src/catalog/presets";
import { resolveBiophysicalAndDemographicPhase } from "../../src/engine/biophysicalPhase";
import { parseHexId } from "../../src/engine/hexGrid";
import { executeGenerationalTurn } from "../../src/engine/turnEngine";
import {
  setSimulationCognitiveProvider,
  useSimulationStore
} from "../../src/store/useSimulationStore";
import { WorldStateSchema, type DemeDecisionEvaluationOutput } from "../../src/types/simulation";

describe("Scientific Presets 30-Generation Integration Benchmarks (FR-014, SC-001, SC-002)", () => {
  it("validates all 3 initial preset worlds against WorldStateSchema", () => {
    expect(SCIENTIFIC_PRESETS).toHaveLength(3);
    for (const preset of SCIENTIFIC_PRESETS) {
      const initialWorld = preset.createInitialWorld();
      const parsed = WorldStateSchema.parse(initialWorld);
      expect(parsed.presetId).toBe(preset.id);
      expect(parsed.generation).toBe(0);
      expect(parsed.autoPauseOnMilestone).toBe(false);
    }
  });

  it("Test 1 (preset-rift-savanna): eastern savanna demes favor cooperation + migration (> 0.50) and trigger Baldwin or Cultural Innovation milestones while western forest demes maintain conservative foraging", async () => {
    const provider = new MockCognitiveProvider();
    let world = getPresetById("preset-rift-savanna").createInitialWorld();

    for (let gen = 1; gen <= 30; gen += 1) {
      world = await executeGenerationalTurn(world, provider, "en");
    }

    expect(world.generation).toBe(30);

    const activeDemes = Object.values(world.demes);
    const easternDemes = activeDemes.filter((deme) => parseHexId(deme.hexId).q > 0);
    const westernDemes = activeDemes.filter((deme) => parseHexId(deme.hexId).q < 0);

    expect(easternDemes.length).toBeGreaterThan(0);
    expect(westernDemes.length).toBeGreaterThan(0);

    for (const eastDeme of easternDemes) {
      const pCoop = eastDeme.lastDecisionProbabilities["dec-cooperate-store"]!;
      const pMigrate = eastDeme.lastDecisionProbabilities["dec-selective-migration"]!;
      expect(pCoop + pMigrate).toBeGreaterThan(0.50);
    }

    for (const westDeme of westernDemes) {
      expect(westDeme.lastDominantDecisionId).toBe("dec-conservative-forage");
    }

    const hasBaldwinOrInnovationMilestone = world.chronicle.some(
      (entry) => entry.type === "baldwin_trait" || entry.type === "cultural_innovation"
    );
    expect(hasBaldwinOrInnovationMilestone).toBe(true);
  });

  it("Test 2 (preset-darwin-archipelago): demes colonize islands across low-sea-level land bridges, become isolated during high sea level, and record allopatric speciation in lineageTree", async () => {
    const provider = new MockCognitiveProvider();
    let world = getPresetById("preset-darwin-archipelago").createInitialWorld();

    let colonizedOuterIslandsDuringLowSea = false;
    let bridgesSubmergedDuringHighSea = false;

    for (let gen = 1; gen <= 30; gen += 1) {
      world = await executeGenerationalTurn(world, provider, "en");

      if (gen === 7) {
        expect(world.seaLevel).toBe(0.12);
        const occupiedOuterIslands = Object.values(world.demes).some(
          (deme) => deme.hexId !== "0,0" && world.cells[deme.hexId]!.biome !== "coastal_shallows"
        );
        colonizedOuterIslandsDuringLowSea = occupiedOuterIslands;
      }

      if (gen === 10) {
        expect(world.seaLevel).toBe(0.25);
        bridgesSubmergedDuringHighSea =
          world.cells["0,-1"]!.biome === "ocean" &&
          world.cells["0,1"]!.biome === "ocean" &&
          world.cells["1,0"]!.biome === "ocean";
      }
    }

    expect(colonizedOuterIslandsDuringLowSea).toBe(true);
    expect(bridgesSubmergedDuringHighSea).toBe(true);

    const hasAllopatricSpeciation = Object.values(world.lineageTree).some(
      (node) => node.divergenceReason === "allopatric_speciation"
    );
    expect(hasAllopatricSpeciation).toBe(true);
  });

  it("Test 3 (preset-finite-island): without communal conservation norms, competition and intensive overexploitation degrade central carryingCapacity below 60% of Kmax (< 360) before generation 30", async () => {
    const provider = new MockCognitiveProvider();
    let world = getPresetById("preset-finite-island").createInitialWorld();

    let minCentralCarryingCapacity = world.cells["0,0"]!.carryingCapacity;

    for (let gen = 1; gen <= 30; gen += 1) {
      world = await executeGenerationalTurn(world, provider, "en");
      const currentCentralK = world.cells["0,0"]!.carryingCapacity;
      if (currentCentralK < minCentralCarryingCapacity) {
        minCentralCarryingCapacity = currentCentralK;
      }
    }

    const centralCell = world.cells["0,0"]!;
    expect(minCentralCarryingCapacity).toBeLessThan(0.60 * centralCell.carryingCapacityMax);
    expect(centralCell.carryingCapacity).toBeLessThan(360);
    expect(world.chronicle.some((entry) => entry.type === "tragedy_of_commons")).toBe(true);
  });

  it("Test 4 (SC-002): completes single-turn deterministic biophysical resolution in < 100 ms", () => {
    const world = getPresetById("preset-rift-savanna").createInitialWorld();
    const decisionsByDemeId: Record<string, DemeDecisionEvaluationOutput> = {};

    for (const deme of Object.values(world.demes)) {
      decisionsByDemeId[deme.id] = {
        probabilities: { ...deme.lastDecisionProbabilities },
        dominantDecisionId: deme.lastDominantDecisionId,
        confidence: 0.90,
        justification: deme.lastJustification
      };
    }

    const startMs = performance.now();
    const nextWorld = resolveBiophysicalAndDemographicPhase(world, decisionsByDemeId);
    const elapsedMs = performance.now() - startMs;

    expect(nextWorld.demes).toBeDefined();
    expect(elapsedMs).toBeLessThan(100);
  });

  it("verifies useSimulationStore actions (preset loading, stepping, brushes, catalog upsert, trait injection, JSON roundtrip)", async () => {
    setSimulationCognitiveProvider(new MockCognitiveProvider());
    const store = useSimulationStore.getState();

    store.loadPreset("preset-rift-savanna");
    expect(useSimulationStore.getState().world.presetId).toBe("preset-rift-savanna");

    await useSimulationStore.getState().stepGeneration();
    expect(useSimulationStore.getState().world.generation).toBe(1);

    useSimulationStore.getState().setActiveBrush({
      kind: "set_biome",
      biome: "savanna",
      radius: 1,
      cost: 10
    });
    const pointsBefore = useSimulationStore.getState().world.selectivePressurePoints;
    useSimulationStore.getState().applyBrushToHex("-2,1");
    expect(useSimulationStore.getState().world.cells["-2,1"]!.biome).toBe("savanna");
    expect(useSimulationStore.getState().world.selectivePressurePoints).toBe(pointsBefore - 10);

    useSimulationStore.getState().upsertTrait({
      id: "user-endurance-run",
      name: "Endurance Running",
      category: "biological",
      semanticDescriptor:
        "Thermoregulatory sweating and nuchal ligament adaptations for long-distance pursuit.",
      affinityCondition: "Open savannas and arid steppes.",
      mutuallyExclusiveWith: [],
      enablesCulturalTransmission: false,
      biophysicalVector: {
        metabolicCost: 0.05,
        extractionEfficiency: 0.60,
        ecologicalImpact: 0.0,
        spatialMobility: 0.60,
        socialCohesion: 0.10,
        transmissionThreshold: 0.10
      },
      origin: "user",
      freeSandboxMode: false
    });
    const savedTrait = useSimulationStore.getState().world.traitsCatalog["user-endurance-run"]!;
    expect(savedTrait.biophysicalVector.metabolicCost).toBeGreaterThanOrEqual(0.35);

    useSimulationStore.getState().injectTraitIntoDeme("deme-rift-west", "bio-r-strategy");
    const updatedWestDeme = useSimulationStore.getState().world.demes["deme-rift-west"]!;
    expect(updatedWestDeme.biologicalTraitIds).toContain("bio-r-strategy");
    expect(updatedWestDeme.biologicalTraitIds).not.toContain("bio-k-strategy");

    const exportedJson = useSimulationStore.getState().exportWorldJson();
    useSimulationStore.getState().loadPreset("preset-finite-island");
    expect(useSimulationStore.getState().world.presetId).toBe("preset-finite-island");

    useSimulationStore.getState().importWorldJson(exportedJson);
    expect(useSimulationStore.getState().world.presetId).toBe("preset-rift-savanna");
    expect(useSimulationStore.getState().world.generation).toBe(1);
  });

  it("runs auto-play continuously across milestones by default (autoPauseOnMilestone=false) and stops automatically on macro-evolutionary outcomes", async () => {
    setSimulationCognitiveProvider(new MockCognitiveProvider());
    const store = useSimulationStore.getState();

    expect(store.locale).toBe("en");
    store.loadPreset("preset-rift-savanna");
    expect(useSimulationStore.getState().world.autoPauseOnMilestone).toBe(false);

    useSimulationStore.getState().setPlaybackMode("playing_fast");
    for (let gen = 1; gen <= 10; gen += 1) {
      await useSimulationStore.getState().stepGeneration();
    }

    const stateAtGen10 = useSimulationStore.getState();
    expect(stateAtGen10.world.chronicle.some((e) => e.type === "baldwin_trait")).toBe(true);
    expect(stateAtGen10.playbackMode).toBe("playing_fast");

    useSimulationStore.getState().setPlaybackMode("paused");

    store.loadPreset("preset-finite-island");
    useSimulationStore.getState().setPlaybackMode("playing_fast");
    for (let step = 1; step <= 60; step += 1) {
      if (useSimulationStore.getState().playbackMode !== "playing_fast") {
        break;
      }
      await useSimulationStore.getState().stepGeneration();
    }

    const terminalIslandState = useSimulationStore.getState();
    expect(terminalIslandState.playbackMode).toBe("paused");
    const reachedTerminalOutcome =
      Object.keys(terminalIslandState.world.demes).length <= 1 ||
      terminalIslandState.world.chronicle.some(
        (e) => e.type === "single_survivor" || e.type === "ecological_equilibrium"
      );
    expect(reachedTerminalOutcome).toBe(true);
    useSimulationStore.getState().setPlaybackMode("paused");
  });

  it("deduplicates equivalent System 1 evaluations within the same turn while formatting deme-specific justifications and caps System 2 synthesis to at most 1 per turn (T007, T008, FR-003, FR-006)", async () => {
    const baseProvider = new MockCognitiveProvider();
    let evalCallCount = 0;
    let milestoneCallCount = 0;

    const instrumentedProvider: MockCognitiveProvider = {
      checkStatus: () => baseProvider.checkStatus(),
      evaluateDemeDecisions: async (input) => {
        evalCallCount += 1;
        return baseProvider.evaluateDemeDecisions(input);
      },
      synthesizeMilestone: async (input) => {
        milestoneCallCount += 1;
        return baseProvider.synthesizeMilestone(input);
      },
      coDesignCatalogItem: (input) => baseProvider.coDesignCatalogItem(input)
    };

    const world = getPresetById("preset-finite-island").createInitialWorld();
    const demeIds = Object.keys(world.demes);
    expect(demeIds.length).toBe(3);

    for (const id of demeIds) {
      const deme = world.demes[id]!;
      deme.population = 320;
      deme.energyReserves = 75;
      deme.lastEnergyDelta = 0;
      deme.biologicalTraitIds = ["bio-r-strategy", "bio-encephalization"];
      deme.culturalTraitIds = ["cul-extraction-tools"];
      deme.baldwinCounters = { "dec-intensive-overexploit": 7 };
      deme.innovationCounter = 1.2;
    }

    const nextWorld = await executeGenerationalTurn(world, instrumentedProvider, "en");
    expect(evalCallCount).toBe(1);
    expect(milestoneCallCount).toBe(1);
    expect(Object.keys(nextWorld.demes).length).toBeGreaterThanOrEqual(2);
  });
});
